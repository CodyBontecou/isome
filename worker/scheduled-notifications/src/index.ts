export interface Env {
  DB?: D1Database;
  APNS_AUTH_KEY?: string;
  APNS_KEY_ID?: string;
  APNS_TEAM_ID?: string;
  APNS_HOST?: "api.push.apple.com" | "api.sandbox.push.apple.com";
}

export const BUNDLE_ID = "com.bontecou.isome";

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { method } = request;
    const { pathname } = new URL(request.url);

    if (pathname === "/health" && method === "GET") {
      return jsonResponse({ ok: true, service: "isome-scheduled-notifications" });
    }

    const isNotificationsRoute =
      (pathname === "/devices/register" && method === "POST")
      || (pathname === "/schedules/upsert" && method === "POST")
      || (method === "DELETE" && /^\/devices\/[^/]+\/[^/]+$/.test(pathname));

    if (!isNotificationsRoute) {
      return jsonResponse({ error: "Not found" }, 404);
    }

    if (!env.DB) {
      return jsonResponse({ error: "D1 binding not configured" }, 503);
    }

    const notifEnv = { DB: env.DB };
    if (pathname === "/devices/register" && method === "POST") {
      const { handleRegisterDevice } = await import("./notifications");
      return handleRegisterDevice(request, notifEnv);
    }

    if (pathname === "/schedules/upsert" && method === "POST") {
      const { handleUpsertSchedule } = await import("./notifications");
      return handleUpsertSchedule(request, notifEnv);
    }

    const match = pathname.match(/^\/devices\/([^/]+)\/([^/]+)$/);
    if (method === "DELETE" && match) {
      const { handleDeleteDevice } = await import("./notifications");
      return handleDeleteDevice(
        decodeURIComponent(match[1]),
        decodeURIComponent(match[2]),
        notifEnv,
      );
    }

    return jsonResponse({ error: "Not found" }, 404);
  },

  async scheduled(event: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    const { handleScheduled } = await import("./scheduled");
    return handleScheduled(event, env, ctx);
  },
};
