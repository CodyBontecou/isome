# iso.me Scheduled Notifications Worker

Cloudflare Worker that stores routing-only schedule metadata and sends silent APNs pushes for due daily exports.

## Endpoints

- `POST /devices/register` — `{ userId, platform, apnsToken, bundleId }`
- `POST /schedules/upsert` — `{ userId, timezone, schedule: { isEnabled, frequency, hour, minute, weekday? } }`
- `DELETE /devices/:userId/:platform`
- `GET /health`

The worker must not store location records, export files, destination folder paths, filename templates, or any user location data. It stores only APNs routing and schedule timing metadata.

## APNs payload

Due schedules send background-only APNs:

```json
{
  "aps": { "content-available": 1 },
  "type": "scheduled-export",
  "fireAt": "2026-06-04T21:00:00.000Z",
  "scheduleVersion": 1
}
```

Headers: `apns-push-type: background`, `apns-priority: 5`, `apns-topic: com.bontecou.isome`.

## Setup

```bash
npm install
wrangler d1 create isome-notifications
# paste database_id into wrangler.toml
wrangler d1 migrations apply isome-notifications --remote
wrangler secret put APNS_AUTH_KEY
wrangler secret put APNS_KEY_ID
wrangler secret put APNS_TEAM_ID
npm run deploy
```
