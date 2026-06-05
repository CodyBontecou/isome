/** Cron handler that dispatches silent APNs pushes for due export schedules. */

import { isDeadTokenResult, sendSilentPush, type ApnsCredentials } from "./apns";
import { computeNextFire, type Frequency } from "./scheduling";
import type { Env } from "./index";

interface DueRow {
  user_id: string;
  is_enabled: number;
  frequency: Frequency;
  hour: number;
  minute: number;
  weekday: number | null;
  timezone: string;
  next_fire_at: number;
  platform: "ios" | "macos";
  apns_token: string;
  bundle_id: string;
}

export async function handleScheduled(
  event: ScheduledController,
  env: Env,
  ctx: ExecutionContext,
): Promise<void> {
  if (!env.APNS_AUTH_KEY || !env.APNS_KEY_ID || !env.APNS_TEAM_ID) {
    console.error("APNs credentials not configured; skipping scheduled tick");
    return;
  }
  if (!env.DB) {
    console.error("D1 binding not configured; skipping scheduled tick");
    return;
  }

  const creds: ApnsCredentials = {
    authKey: env.APNS_AUTH_KEY,
    keyId: env.APNS_KEY_ID,
    teamId: env.APNS_TEAM_ID,
  };
  const host = env.APNS_HOST ?? "api.push.apple.com";
  const nowSec = Math.floor(event.scheduledTime / 1000);

  const due = await env.DB.prepare(
    `SELECT s.user_id, s.is_enabled, s.frequency, s.hour, s.minute, s.weekday,
            s.timezone, s.next_fire_at,
            d.platform, d.apns_token, d.bundle_id
       FROM schedules s
       JOIN devices d ON d.user_id = s.user_id
      WHERE s.is_enabled = 1 AND s.next_fire_at <= ?`,
  ).bind(nowSec).all<DueRow>();

  if (!due.results || due.results.length === 0) return;

  const advanced = new Set<string>();

  for (const row of due.results) {
    const fireAtIso = new Date(row.next_fire_at * 1000).toISOString();
    ctx.waitUntil((async () => {
      const result = await sendSilentPush(creds, {
        apnsToken: row.apns_token,
        bundleId: row.bundle_id,
        customPayload: {
          type: "scheduled-export",
          fireAt: fireAtIso,
          scheduleVersion: 1,
        },
        expirationSec: row.next_fire_at + 600,
        host,
      });

      console.log(JSON.stringify({
        route: "scheduled",
        userId: row.user_id,
        platform: row.platform,
        status: result.status,
        reason: result.reason ?? null,
        apnsId: result.apnsId ?? null,
        fireAt: fireAtIso,
      }));

      if (isDeadTokenResult(result)) {
        await env.DB!.prepare(`DELETE FROM devices WHERE user_id = ? AND platform = ?`)
          .bind(row.user_id, row.platform)
          .run();
      }
    })());

    if (!advanced.has(row.user_id)) {
      advanced.add(row.user_id);
      const next = computeNextFire(
        {
          frequency: row.frequency,
          hour: row.hour,
          minute: row.minute,
          ...(row.weekday !== null ? { weekday: row.weekday } : {}),
        },
        row.timezone,
        nowSec,
      );
      ctx.waitUntil(env.DB.prepare(
        `UPDATE schedules SET next_fire_at = ?, updated_at = ? WHERE user_id = ?`,
      ).bind(next, nowSec, row.user_id).run());
    }
  }
}
