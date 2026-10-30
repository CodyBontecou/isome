# Build 51 — deployed privacy audit and final proposed disclosures

**Approval draft only. No publication authorized.** Audited October 29, 2026. This supersedes the unresolved analytics/scheduling/claim-service portions of [the initial proposal](privacy-review.md). Build 51, pinned to `d120326`, remains unchanged.

## Conclusion

“Data Not Collected” is not accurate for this candidate. Keep build 51 and propose the six data types below, all **linked to the user**, with **no advertising tracking**. The deployed myself.md claim service retains purchase references and can associate them with an account; it is not a transient-only verification exception.

The investigation establishes application behavior and exposed deployment configuration. It does **not** establish an organization-wide maximum retention period: the services have records without automatic expiry, and the current credential cannot list account-level Logpush jobs (HTTP 403). Do not publish promises of anonymous collection, no IP processing, universal deletion on uninstall, or a fixed expiry for all records. Owner/processor confirmation and legal approval remain publication gates, not reasons to invent missing facts.

## Read-only audit scope and provenance

Used authenticated Wrangler/API reads for deployments, deployed version metadata, script settings, deployed JavaScript, schedules, custom-domain routing, and D1 metadata. The only database SQL was `SELECT type, name, tbl_name, sql FROM sqlite_master ...` to inspect table/trigger definitions. No customer rows, purchase proofs, APNs tokens, account records, or log contents were retrieved. Secret **names/types only**, never secret values, were inspected. No request was sent to the purchase-proof endpoint and no fabricated analytics event was posted.

Private, gitignored evidence directory:

`.asc/artifacts/paid-tracking/privacy-review/deployed/`

| Service | Active version (100% traffic) | Deployment date | Verified bindings/configuration |
| --- | --- | --- | --- |
| `iso-me-onboarding-analytics` | `b6b4af68-21d4-4593-95fe-449501e2a8e3` | 2026-09-01 | D1 `20e95c7d-0939-4ead-8066-f2207505d273`; batch cap 50; no ingest-token binding; fetch handler only; no cron |
| `isome-scheduled-notifications` | `d2c2759a-5f6f-4e1c-95a8-51f050618b75` | 2026-08-19 | D1 `12500647-7f6e-4f1c-bec6-5e1c7e8633cf`; production APNs host and credential bindings; every-minute cron |
| `myself-md` | `efe34431-a741-4703-aabc-872b69cfb7ce` | 2026-10-25 | `myself.md` production custom domain; `MyselfPurchase`/`MyselfAccount` SQLite Durable Objects; `DIRECTORY` D1; daily `03:17 UTC` cleanup |

Downloaded module SHA-256 values, useful for reproducing the source review:

- Analytics: `3888e75dd1a30e60ebe71e67872562450a393c582c5ca1c7306d887797d45ebd`
- Scheduling: `c301689dc858ce4054368c27062f5a4e2bd47ae7a6a5c0d7be228e0f5737e87c`
- myself.md: `a56c8f2b98d7dad00c404173b328cdd7d1d01ee2c940387b761d3fcfe09b7a7e`

These are downloaded production modules, not assumptions based on the current local myself.md checkout.

## Verified findings

### 1. Analytics

The Release client is enabled by default and transmits a persistent random installation ID, event ID, and allowlisted onboarding/purchase properties. The production worker stores these in D1, whose remote schema confirms the `received_at`, `install_id`, event, property, and payload columns. Its deployed code contains no deletion routine, its exposed schedule list is empty, and no database trigger was returned. **There is no timed expiry configured in this audited service.** Other manual/operator jobs or exports are not ruled out by those facts. [E1, E2]

The payload does not include coordinates, visits, routes, user-entered text, payment-card information, or signed StoreKit proofs. Random installation IDs are persistent linkage, not anonymous aggregate measurement.

**Separate operational mismatch:** the deployed product allowlist contains only the three lifetime IDs. It rejects all four new weekly/yearly subscription IDs with `unknown_property_value:productId`. Other valid events, including lifetime purchase events, remain collectable. Consequently this mismatch does not support “Data Not Collected.” The pinned client retries failed sends and leaves an unsent event at the head of its queue; a rejected subscription event can therefore stall later analytics. No worker/client correction was made; a deployment would need separate authorization. [E1; initial proposal S1–S3]

### 2. Scheduling

Production stores installation identity, APNs token, bundle/platform, last-seen time, time zone, schedule configuration, and next-fire/update times in D1. The remote schema and downloaded worker match this description. Records are used for functionality, not audience measurement. [E3]

- A successful disable request deletes the schedule row. Merely toggling offline does not prove remote deletion succeeded.
- Device registrations have **no configured age-based expiry**. The worker deletes a device when APNs reports an invalid/dead token, or through its explicit device-delete route. Turning off a schedule does not call that route.
- The every-minute cron sends pushes and advances schedules; it is not a stale-registration retention job.
- The cron code emits console messages with installation `userId`, platform, APNs status/reason/request identifier, and scheduled fire time. Do not describe the code as incapable of logging identifiers. Persisted logging configuration is discussed separately below.

### 3. myself.md purchase verification is active and retains data

**Important distinction:** `MIGRATION_ENABLED="0"` does **not** disable `/api/migration/proof`. In this deployed code, `1` freezes ordinary service while a separate internal import migration runs. The proof endpoint is reachable through the ordinary `0` branch. Do not interpret the variable name as an off switch for the customer claim flow. [E4]

For Whereday's eligible lifetime purchases:

1. The phone sends the signed StoreKit transaction proof after an explicit user action.
2. The service verifies it and obtains current transaction information from Apple. Its verified eligibility result is `{source: "iso.me:ios:iap", reference: originalTransactionId}`.
3. A purchase-specific Durable Object, addressed using a hash of source/reference, stores a hashed random claim ticket **plus the source and purchase reference** in `billing_claims`, with a 15-minute validity deadline. The source/reference columns are not themselves anonymized by hashing the object address.
4. A D1 directory stores the hashed routing ticket and expiry. Redeeming while signed in stores a grant mapping source/reference to the account subject in purchase/account storage, preventing duplicate claims. That is retained account-linked purchase information.
5. The successful proof path does **not** store the original signed JWS in its claim rows. Do not conflate it with a different purchase path's `billing_purchases.proof` column. The derived purchase reference is nevertheless retained. [E4]

Retention details:

- **Ticket validity:** 15 minutes. An expired ticket is rejected, not necessarily erased immediately.
- **Directory cleanup:** daily cron deletes expired D1 ticket rows. Normally this is the next daily run after expiry, subject to job success.
- **Purchase-object claim rows:** expired rows are deleted when another claim is created in that same object. No periodic/alarm purge of these rows was found. An unredeemed expired row can therefore remain without a defined storage deadline.
- **Redeemed grants:** no timed expiry. On successful account deletion, the purchase object replaces the account subject with `deleted` and removes claim rows associated with that subject; account-side rows are removed. Purchase references remain as duplicate-claim protection, without a timed expiry. This is a deletion **workflow**, not a live deletion test or a guarantee against failed cleanup. [E4]

The later browser sign-in uses myself.md's identity service. This audit includes the purchase/account linkage needed to complete Whereday's claim, not every health, location, identity, or analytics feature of the separate myself.md app/site. No email address is sent by the inspected Whereday proof request. Do not add all myself.md data types to Whereday's label merely because it opens an external browser.

### 4. Logging, processor metadata, and backups

- All three returned script settings show `logpush: false` and an empty `tail_consumers` list.
- Analytics and scheduling settings return **no observability block**. No persistent Workers Logs configuration is exposed for them. Cloudflare documents that an observability setting is required to write to Workers Logs; this is configuration evidence, not inspection of log contents or proof that Cloudflare retains no operational metadata.
- myself.md has persistent Workers Logs enabled, sampling 1, query-string redaction enabled, invocation logs disabled, and traces disabled. The relevant handler logs a generic unexpected-error message with path and error type; production development-mode raw error logging is off. No explicit proof-body/IP/UA logging was found on that path. Platform exceptions and bundled dependencies mean “we never log any request-related data” would still be too broad.
- Cloudflare's current documented Workers Logs retention is **3 days on Free / 7 days on Paid**, maximum 7 days. The account's effective billing/log-retention entitlement was not established by these responses; use **up to 7 days for this Workers Logs store**, not an asserted exact 7-day setting and not a maximum for all provider logs.
- Account-level `/logpush/jobs` returned **403**. Worker-level Logpush is off, but this does not establish the absence of zone/account security logs or other operational processing. No new credentials were created and no logging configuration was changed.
- D1 Time Travel is backup/recovery history, **not deletion of current rows**. Cloudflare documents a 7-day Free / 30-day Paid recovery window. SQLite Durable Objects also support recovery history up to 30 days. These facts do not prove absence of manual exports or other backups. Do not promise immediate erasure of backup copies or universal 30-day deletion. [E5, C1–C3]

## Final proposed App Store Connect selections

For **build 51 against the deployed services audited above**:

- “Do you or your third-party partners collect data from this app?” → **Yes**.
- For **every row below**: linked to the user's identity → **Yes**; used for tracking → **No**.
- “Tracking” means Apple's cross-company advertising/data-broker definition. Whereday's location recording and first-party funnel measurement are not, by themselves, that kind of tracking. Owner/processor confirmation of no repurposing is still required. [A1]

| Category → data type | Select purposes | Reason |
| --- | --- | --- |
| Identifiers → **Device ID** | **Analytics; App Functionality** | Analytics installation UUID; separate scheduling installation UUID/APNs token. |
| Identifiers → **User ID** | **App Functionality** | Claim purchase/customer identity and retained association with the myself.md account. This is not selected merely because a scheduling field happens to be named `userId`. |
| Purchases → **Purchase History** | **Analytics; App Functionality** | Lifetime purchase/restore analytics; retained verified purchase references and complimentary-access grants. |
| Usage Data → **Product Interaction** | **Analytics** | Onboarding, permission/tracking choices, paywall and purchase/restore interactions. |
| Diagnostics → **Other Diagnostic Data** | **Analytics; App Functionality** | Analytics technical-error categories and operational error diagnostics for claim-service reliability. |
| Other Data → **Other Data Types** | **App Functionality** | Retained scheduling/time-zone configuration and related service context. |

Do **not** select advertising/marketing, product personalization, or Other Purposes for these uses. No evidence here supports adding Payment Info, Precise/Coarse Location, Crash Data, Performance Data, Contacts, Health, or Email Address. The on-device location database and Apple-only service processing are not automatically collection by us. If processor review establishes additional retained IP-derived location, device identification, performance, or crash data, classify by actual use rather than silently assuming it is absent. [A1]

Expected label: **Data Linked to You** with these six data types and no **Data Used to Track You** section. The privacy manifest is separate from the store questionnaire; this review changes neither.

## Final proposed retention and claim wording

The following text is ready for owner/legal review **as a description of audited service behavior**, not approval to publish. It replaces speculative fixed-duration wording in the initial proposal. Retain its explicit distinction between ordinary app records and backups.

### Analytics retention

> We store first-party onboarding and purchase-flow events with a random installation identifier. These records do not have an automatic expiry in our analytics service. Deleting local records or uninstalling Whereday does not delete events already received by that service. The reports do not contain your location history, but the installation identifier links events from the same installation.

### Scheduled exports

> If you enable scheduled exports, our scheduling service stores a separate installation identifier, Apple push token, time zone, and schedule settings. After the service successfully receives a request to disable scheduling, it removes the active schedule. Device registrations have no age-based expiry; the service removes them when Apple reports an invalid push token or when a device-deletion request is processed. Turning scheduling off or uninstalling the app does not itself delete every retained registration. The scheduling identifier is stored in Keychain and may survive uninstalling the app.

### Optional purchase verification

> If you choose to verify an eligible lifetime purchase for complimentary myself.md access, Whereday sends signed App Store purchase proof to myself.md. The service verifies eligibility with Apple and retains the purchase source and transaction reference. A claim link is valid for 15 minutes. Expiry stops the link from being used; it does not immediately erase every stored claim record. Directory routing records are removed by a daily cleanup, while expired purchase-claim rows are removed when a later claim is created for that purchase. There is no guaranteed storage deadline for an unused expired purchase-claim row.
>
> If you redeem the claim while signed in, the service links the purchase reference to your myself.md account to grant access and prevent duplicate claims. These grants do not expire automatically. When account deletion completes successfully, the service removes the account link but retains the purchase reference to prevent duplicate claims. Those limited purchase-protection records do not have a timed expiry. Deleting Whereday is not a request to delete your myself.md account. Whereday does not send your location history or payment-card details in this verification request.

### Operational logs and recovery copies

> Cloudflare hosts these services and processes network requests to provide and secure them. The myself.md service also retains operational error logs. Cloudflare's Workers Logs store retains logs for up to seven days; this is not a maximum for every provider security record or backup. Cloudflare database recovery history may retain earlier copies after a live record changes or is deleted. Removing a live record does not necessarily erase recovery copies immediately.

### Privacy requests

> For questions about retained analytics or scheduling metadata, contact cody.bontecou@gmail.com. For myself.md account deletion, use its account-deletion controls and check that the deletion workflow completes. An uninstall does not initiate these server-side deletion processes.

Do not promise automatic deletion from an email request, an identifier-discovery mechanism, or a fixed response time without verifying the operational workflow. The lack of bounded expiry for several records is a substantive retention decision for the owner/legal reviewer. If a shorter retention policy is desired, it requires a separately authorized implementation/deployment, not a documentation-only promise.

## Remaining approvals and limits

1. Owner/legal acceptance of default-on telemetry, retained identifiers/purchase linkage, unbounded portions of retention, and the proposed wording/selections.
2. Confirm processor contractual/security-log retention and any account/zone Logpush or external backups through an authorized operator; current account-level list permission is insufficient. Do not assert a comprehensive maximum retention period until resolved.
3. Confirm actual human access roles, manual exports, and deletion-request operations; script metadata does not expose an organization-wide access audit.
4. Review user-directed webhook destinations separately if developer-controlled processing is used. Nothing here expands the source-only conclusion into a claim about every possible destination.
5. The subscription analytics allowlist mismatch is documented, not fixed. Decide separately whether to authorize a worker-only correction, deferral, or another approach. Do not deploy it as part of this read-only request.
6. After approvals, separately authorize any App Privacy/policy publication. **Do not submit or release** until the other staged-release blockers are cleared and explicit authorization is given.

No iOS tests were necessary or run: this task changed documentation only and did not rebuild the app. All lifetime prices/regional overrides and manual release settings were untouched.

## Evidence index / primary references

- **[E1]** `analytics-{deployments,version,settings,schedules}.json`, `analytics-source/module-0.js` (allowlist lines 7–69; ingestion/normalization lines 87–249).
- **[E2]** `analytics-{schema,d1-info}.json`; schema query returned tables and no retention trigger. Database metadata shows ongoing writes, not a dormant service.
- **[E3]** `scheduling-{deployments,version,settings,schedules,schema,d1-info}.json`, `scheduling-source/module-0.js` (registration/upsert/delete around lines 147–283; cron/logging lines 403–475).
- **[E4]** `myself-{deployments,version,settings,schedules}.json`, `custom-domains.json`, `myself-source/module-0.js`: `verifyMigrationPurchase` around 126632; billing claim creation/redeem around 151929; account cleanup around 161075; purchase-object `forgetAccount` around 161408; proof route around 161634; handler exception logging around 161696.
- **[E5]** All `*-settings.json`; `account-logpush-jobs.error.json` records the 403. No logs/customer records were downloaded.
- **[A1] Apple App privacy details:** https://developer.apple.com/app-store/app-privacy-details/ — taxonomy, purposes, linked data, tracking and collection exceptions. Captured in the parent privacy-review artifact directory.
- **[C1] Cloudflare Workers Logs:** https://developers.cloudflare.com/workers/observability/logs/workers-logs/ — opt-in configuration, invocation logs and plan-based retention. Snapshot `cloudflare-workers-logs.{html,txt}`.
- **[C2] D1 Time Travel:** https://developers.cloudflare.com/d1/reference/time-travel/ — recovery history, not a live-row TTL. Snapshot `cloudflare-d1-time-travel.{html,txt}`.
- **[C3] SQLite Durable Object storage:** https://developers.cloudflare.com/durable-objects/api/sqlite-storage-api/ — point-in-time recovery. Snapshot `cloudflare-do-sqlite.html`.

For original pinned-client findings and the read-only published-policy fetch, see [the initial review](privacy-review.md). For unchanged staging and pricing boundaries, see [the staging record](../../subscription-staging-1.7.19.md).
