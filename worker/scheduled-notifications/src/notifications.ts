/**
 * Server-side scheduled-export notification routes.
 *
 * POST /devices/register   — upsert APNs token for (userId, platform)
 * POST /schedules/upsert   — upsert export schedule and compute next_fire_at
 * DELETE /devices/:userId/:platform — drop a device row
 */

import { BUNDLE_ID } from "./index";
import { computeNextFire, type Frequency, type Schedule } from "./scheduling";

export interface NotificationsEnv {
  DB: D1Database;
}

const USER_ID_RE = /^[A-Za-z0-9_-]{16,64}$/;
const APNS_TOKEN_RE = /^[A-Fa-f0-9]{32,200}$/;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function isValidTimezone(tz: string): boolean {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}

function isInt(n: unknown, lo: number, hi: number): n is number {
  return typeof n === "number" && Number.isInteger(n) && n >= lo && n <= hi;
}

interface RegisterDeviceBody {
  userId?: string;
  platform?: string;
  apnsToken?: string;
  bundleId?: string;
}

export async function handleRegisterDevice(
  request: Request,
  env: NotificationsEnv,
): Promise<Response> {
  let body: RegisterDeviceBody;
  try {
    body = await request.json() as RegisterDeviceBody;
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const { userId, platform, apnsToken, bundleId } = body;

  if (!userId || typeof userId !== "string" || !USER_ID_RE.test(userId)) {
    return jsonResponse({ error: "Invalid userId" }, 400);
  }
  if (platform !== "ios" && platform !== "macos") {
    return jsonResponse({ error: "Invalid platform" }, 400);
  }
  if (!apnsToken || typeof apnsToken !== "string" || !APNS_TOKEN_RE.test(apnsToken)) {
    return jsonResponse({ error: "Invalid apnsToken" }, 400);
  }
  if (bundleId !== BUNDLE_ID) {
    return jsonResponse({ error: "Bundle ID mismatch" }, 400);
  }

  const nowSec = Math.floor(Date.now() / 1000);
  await env.DB.prepare(
    `INSERT INTO devices (user_id, platform, apns_token, bundle_id, last_seen)
     VALUES (?, ?, ?, ?, ?)
     ON CONFLICT(user_id, platform) DO UPDATE SET
       apns_token = excluded.apns_token,
       bundle_id = excluded.bundle_id,
       last_seen = excluded.last_seen`,
  ).bind(userId, platform, apnsToken.toLowerCase(), bundleId, nowSec).run();

  return jsonResponse({ ok: true });
}

interface UpsertScheduleBody {
  userId?: string;
  timezone?: string;
  schedule?: {
    isEnabled?: boolean;
    frequency?: string;
    hour?: number;
    minute?: number;
    weekday?: number | null;
  };
  platform?: string;
  bundleId?: string;
}

export async function handleUpsertSchedule(
  request: Request,
  env: NotificationsEnv,
): Promise<Response> {
  let body: UpsertScheduleBody;
  try {
    body = await request.json() as UpsertScheduleBody;
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const userId = body.userId;
  const timezone = body.timezone;
  const sched = body.schedule;

  if (!userId || typeof userId !== "string" || !USER_ID_RE.test(userId)) {
    return jsonResponse({ error: "Invalid userId" }, 400);
  }
  if (!timezone || typeof timezone !== "string" || !isValidTimezone(timezone)) {
    return jsonResponse({ error: "Invalid timezone" }, 400);
  }
  if (!sched || typeof sched !== "object") {
    return jsonResponse({ error: "Missing schedule" }, 400);
  }

  if (sched.isEnabled === false) {
    await env.DB.prepare(`DELETE FROM schedules WHERE user_id = ?`).bind(userId).run();
    return jsonResponse({ ok: true, isEnabled: false });
  }

  if (sched.frequency !== "daily" && sched.frequency !== "weekly") {
    return jsonResponse({ error: "Invalid frequency" }, 400);
  }
  if (!isInt(sched.hour, 0, 23)) {
    return jsonResponse({ error: "Invalid hour" }, 400);
  }
  if (!isInt(sched.minute, 0, 59)) {
    return jsonResponse({ error: "Invalid minute" }, 400);
  }

  let weekday: number | null = null;
  if (sched.frequency === "weekly") {
    if (!isInt(sched.weekday, 1, 7)) {
      return jsonResponse({ error: "Weekly schedule requires weekday in [1,7]" }, 400);
    }
    weekday = sched.weekday;
  }

  const schedule: Schedule = {
    frequency: sched.frequency as Frequency,
    hour: sched.hour,
    minute: sched.minute,
    ...(weekday !== null ? { weekday } : {}),
  };

  const nowSec = Math.floor(Date.now() / 1000);
  const nextFireAt = computeNextFire(schedule, timezone, nowSec);

  await env.DB.prepare(
    `INSERT INTO schedules
        (user_id, is_enabled, frequency, hour, minute, weekday, timezone, next_fire_at, updated_at)
     VALUES (?, 1, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(user_id) DO UPDATE SET
       is_enabled = 1,
       frequency = excluded.frequency,
       hour = excluded.hour,
       minute = excluded.minute,
       weekday = excluded.weekday,
       timezone = excluded.timezone,
       next_fire_at = excluded.next_fire_at,
       updated_at = excluded.updated_at`,
  ).bind(
    userId,
    schedule.frequency,
    schedule.hour,
    schedule.minute,
    weekday,
    timezone,
    nextFireAt,
    nowSec,
  ).run();

  return jsonResponse({ ok: true, nextFireAt });
}

export async function handleDeleteDevice(
  userId: string,
  platform: string,
  env: NotificationsEnv,
): Promise<Response> {
  if (!USER_ID_RE.test(userId)) {
    return jsonResponse({ error: "Invalid userId" }, 400);
  }
  if (platform !== "ios" && platform !== "macos") {
    return jsonResponse({ error: "Invalid platform" }, 400);
  }
  await env.DB.prepare(`DELETE FROM devices WHERE user_id = ? AND platform = ?`)
    .bind(userId, platform)
    .run();
  return jsonResponse({ ok: true });
}
