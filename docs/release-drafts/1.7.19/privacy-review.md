# Build 51 privacy review — approval draft

Status: **initial proposal only; not approved or published**. Reviewed October 29, 2026.

**Superseded for deployed behavior, final proposed selections, and retention wording by [the deployed-service audit](privacy-deployed-audit.md).** That follow-up confirms active purchase/account linkage and adds User ID/App Functionality selections; the conditional service findings below are preserved as the initial investigation, not the final questionnaire.

## Decision

**Do not submit build 51 with “Data Not Collected.”** Its Release configuration enables first-party analytics by default, sends persistent install-linked events off-device, and the pinned worker implementation stores them in D1. A random identifier and absence of an analytics SDK do not make this anonymous or exempt collection under Apple's definitions. [A1, S1–S4]

Recommended route: **A — retain build 51 and correct the disclosures**, after confirming deployed service behavior and the purchase-claim flow below. Route B is an analytics-disabled replacement build, but **disabling analytics alone does not justify keeping “Data Not Collected.”** Scheduled-export metadata is separately collected, and purchase verification needs a server-side review.

No code, remote privacy answers, public policy, worker deployment, live prices, review submission, or release was changed in this investigation. No replacement build was created. Build 51 remains the candidate pinned to `d120326`; this proposal does not incorporate later local UI changes.

## Evidence and scope

Source paths below are relative to the pinned source checkout at `.asc/artifacts/stage-1.7.19-51/source/`, not the mutable working tree.

### Analytics: enabled in Release, install-linked, stored

- `OnboardingAnalyticsClient.isEnabledByDefault` returns `true` outside DEBUG. `ONBOARDING_ANALYTICS_ENABLED` only controls the DEBUG branch; setting it to `0` is **not** a Release disable mechanism. Both tracking and queue flushing check the enabled flag. The queue persists up to 50 events locally and retries failed sends. [S1]
- The transport sends `installId` plus event payloads to `https://iso-me-onboarding-analytics.costream.workers.dev/v1/events`. The UUID persists in UserDefaults under `onboarding.analytics.install_id.v1`; each queued event also gets an event UUID. It is pseudonymous, not aggregated before collection. [S1, S2]
- Events cover onboarding start/steps/completion, permission requests/results, location-tracking intent, paywall display, purchase start/result, and restore start/result. Allowed properties include app version/build/platform, step, authorization status/request kind, tracking intent, paywall context, product ID, purchase outcome, and coarse technical error category. [S3]
- The worker implementation stores `install_id`, server receipt time, event name, allowed properties, and serialized payload in `onboarding_events`. The checked-in code/schema contains no automatic analytics retention/deletion job. This is **not** proof that deployed retention is unlimited; deployment and operational controls remain unverified. [S4]
- This payload does **not** contain coordinates, visits, routes, addresses, place names, photos, export contents, webhook URLs, user text, payment-card details, or purchase transaction JWS. Permission status is not location data. A successful purchase/product event nevertheless reveals purchase history/tendencies. [S2–S4]

### Separate collection: scheduled exports

- When scheduled exports are enabled, `DailyExportScheduler` syncs the schedule and registers for remote notifications. A never-enabled installation does not send a disabled schedule unless a prior sync marker exists. Denying visible notification permission does not necessarily prevent silent-push registration. [S5, S6]
- Requests send a separate Keychain-backed UUID (`pushRegistrationUserId`), APNs token, platform/bundle ID, time zone, and schedule settings to `https://isome-scheduled-notifications.costream.workers.dev`. The server computes next fire time and stores device/schedule rows in D1. These are not location records or export contents, but they are still retained off-device data for App Functionality. [S5–S7]
- Disabling the schedule deletes its schedule row in the worker implementation. It does not, by itself, delete the device row. A device-delete route and invalid-token cleanup exist; no general device-record TTL is established by this review. Keychain identity can survive app deletion, so do not promise uninstall deletes every identifier or server record. [S5, S7]

### Separate collection requiring a follow-up check: purchase claim

Settings exposes an optional `MyselfClaimView(app: "iso.me")`. An explicit verification action sends a verified StoreKit purchase JWS to `https://myself.md/api/migration/proof` and opens a returned claim URL. This flow differs from Apple processing payment-card details. The proof contains transaction information; the receiving service's persistence, identity/account association, and logs were not established here. Do not assume it is exempt merely because it is optional. [S8, A1]

The relevant server implementation was not found in the inspected app/worker paths. We need its deployed retention/account-linkage behavior before finalizing the app-wide label. Account/email data collected by a subsequent website also needs a scope determination; this review does not silently treat all website data as app collection.

### Published policy

A read-only fetch of `https://whereday.com/privacy` during this review confirms the **published** policy already describes default-on onboarding analytics, random install ID, and optional scheduled-export metadata (updated October 26, 2026). Thus the mismatch is not merely between an unpublished policy draft and the label. The prior staging audit recorded the published App Privacy answer as “Data Not Collected”; no privacy answers were changed or independently re-published here. [P1]

The published policy does not describe the purchase-claim proof flow. Its deletion section also fails to distinguish local deletion, retained analytics, and Keychain-backed scheduling identity precisely enough.

## A — retain build 51; proposed App Store Connect answers

These are the **exact proposed selections for the verified analytics/scheduling flows**, not permission to publish and not a claim that the unresolved claim-service/logging checks have passed.

Top-level collection question: **Yes, we collect data from this app.**

For each row: **Linked to the user's identity: Yes. Used for tracking: No.** A persistent installation/device identifier links the records to a device even without a name or login. “Tracking” here is Apple's cross-company advertising/data-broker definition, not Whereday's location-tracking feature. No such advertising use was found in the inspected code. [A1]

| ASC category → data type | Select these purposes | Evidence / scope |
| --- | --- | --- |
| Identifiers → **Device ID** | **Analytics; App Functionality** | Analytics install UUID; separate scheduling UUID and APNs token. Scheduling UUID is an installation identity despite the wire field being named `userId`. |
| Usage Data → **Product Interaction** | **Analytics** | Onboarding steps, permission interactions/status, tracking choices, paywall and purchase/restore interactions. |
| Purchases → **Purchase History** | **Analytics** | Product IDs and successful purchase/restore outcomes associated with the analytics install ID. Not payment information. |
| Diagnostics → **Other Diagnostic Data** | **Analytics** | Coarse technical errors such as network/store unavailable, with app/build/platform context. No crash logs or measured performance traces were found in this flow. |
| Other Data → **Other Data Types** | **App Functionality** | Retained scheduling configuration/time zone and routing context not covered by the identifier category. Time zone is not used here to infer geographic location. |

Do **not** select Third-Party Advertising, Developer's Advertising or Marketing, Product Personalization, or Other Purposes based on these flows. Do not select Payment Info, Precise Location, or Coarse Location merely because the app uses StoreKit or location services on-device. Do not add Crash Data or Performance Data for a coarse error enum. Do not label this data “Not Linked” solely because UUIDs are random. [A1]

**Before these become final app-wide answers:**

1. **Purchase claim:** if the receiver retains the proof or extracted purchase information beyond the real-time request, add **App Functionality** to Purchase History. If a retained transaction/customer/account identifier identifies the purchaser, add **Identifiers → User ID**, purpose **App Functionality**, linked **Yes**, tracking **No**. The raw Swift field name `userId` in the unrelated scheduling flow is not itself a reason to select User ID. If the claim receiver discards all relevant data immediately, document that evidence and evaluate Apple's real-time-service exception instead. [A1, S8]
2. **Cloudflare deployment/logs:** verify deployed analytics allowlist and both workers' logging, request tracing, IP/UA handling, retention, backups, access, and use. The checked-in analytics code does not intentionally save raw IP/UA in its D1 event table, but that does not establish infrastructure behavior. Classify any additional retained data by its actual use; Apple specifically requires use-based classification for retained IPs. [A1]
3. **Other destinations:** confirm user-directed webhooks do not send copies to developer-controlled processors or logs, and review the actual in-app destination configuration before claiming all such processing is outside the developer's collection. Apple-only Maps/App Store processing is not automatically collection by us. [A1]
4. Owner confirms no advertising/data-broker use by processors. Confirm purpose assignments reflect actual operations, not just the intended code.

Expected label for the verified flows: **Data Linked to You**, with identifiers, usage data, purchases, diagnostics, and other data; **no Data Used to Track You**. Final preview must be checked after the outstanding service audit. This proposal does not establish a legal basis for default-on telemetry in every jurisdiction; owner/legal review remains required.

## Proposed public-policy edits for approval

Keep existing accurate location-locality, Apple-services, export, and webhook explanations. Proposed replacements/addition below are **draft wording**, not published changes. Do not invent a retention duration or promise a deletion process that has not been implemented and verified.

### Replace the first-party onboarding analytics bullet

> First-party onboarding analytics (on by default): Whereday sends onboarding and purchase-flow events to our service hosted on Cloudflare. These include onboarding steps, location-permission status and tracking choices, paywall interactions, product identifiers, purchase and restore outcomes, coarse technical error categories, app version/build, and platform. Events are stored with a random identifier for this app installation, an event identifier, and the time our service receives them. We use these records to understand onboarding and purchase flows and diagnose failures. They are linked to the installation identifier, not anonymous aggregate counts. These reports do not include your coordinates, visits, routes, addresses, place names, photos, export contents, or text you enter. We do not use these events for cross-company targeted advertising or share them with data brokers.

### Replace the scheduled-export wake-ups bullet

> Scheduled export wake-ups (only if enabled): Whereday sends a separate installation identifier, Apple push token, platform/bundle identifier, time zone, and schedule settings to our scheduling service hosted on Cloudflare. The service stores routing and timing metadata so it can send scheduled wake-up pushes. It does not receive location records, export contents, destination folders, or file names. Turning scheduled exports off removes the active server schedule; it does not by itself delete every retained device registration. The scheduling identifier is stored in Keychain and may survive app deletion.

### Add after purchase-claim server audit, if its described behavior is confirmed

> Optional myself.md purchase verification: if you choose to verify an eligible lifetime purchase for complimentary myself.md access, Whereday sends signed App Store purchase proof to myself.md to verify eligibility and opens the resulting claim page. The proof contains purchase and transaction information, not your location history or payment-card details.

Before publishing that paragraph, add the **verified** retention period, any account linkage, and applicable deletion/request process. Do not publish it as a complete description before those facts are known. Likewise, add verified analytics/device-registration retention and a usable deletion contact/process to the policy. The existing contact address is `cody.bontecou@gmail.com`; do not imply an identifier-based deletion workflow already exists.

### Replace the misleading deletion assurance

> Deleting local records does not delete records already sent to our analytics or scheduling services. Removing the app removes its local app data, subject to backups and restoration; it does not itself request deletion of server records. The separate scheduling identifier stored in Keychain may remain on the device after uninstalling the app.

Owner/legal approval is required for the policy text and actual retention/deletion commitments. Reconcile the existing “only telemetry” wording with the fuller inventory rather than adding contradictory paragraphs.

## B — analytics-disabled replacement build, for approval only

This route removes default-on telemetry but still requires truthful disclosures for retained scheduling/claim data.

Proposed implementation boundary:

1. Disable Release analytics explicitly in source/build configuration; do not rely on the DEBUG-only environment flag. Use a no-op transport, prevent ID creation/network attempts, and clear rather than replay any persisted analytics queue on upgrade. Review all callers so onboarding, purchases, and restores continue normally.
2. Keep tracking entitlements, grandfather cutoff **51**, subscription products/trials, existing lifetime access, and existing-user export behavior unchanged. Removing analytics must not reset the cohort marker or StoreKit state.
3. Preserve scheduling functionality unless the owner separately approves disabling its remote service. For this analytics-disabled variant, proposed known collection would still include **Device ID** and **Other Data Types**, linked **Yes**, purpose **App Functionality**, tracking **No**. Add purchase-claim disclosures as determined above. Analytics-derived Product Interaction, Purchase History, and Diagnostics selections can only be removed after confirming no other remaining flow collects them.
4. Update draft policy/reviewer material to describe the actual replacement, not default-on analytics. Do not change the published policy until separately approved and aligned with the release transition.
5. Verify with regression tests for disabled tracking/flush/transport and pre-existing queues; exercise fresh install and upgrade, onboarding, purchase/restore/error flows, and scheduling/claim paths. Use a Release-equivalent configuration and network evidence: ordinary Debug behavior is insufficient. Run the repo's `scripts/test-ios.sh`, retaining Keychain test signing.
6. With approval to build/upload, reserve a verified unused build number **greater than 51** (do not assume 52 is available), pin the source commit, archive/export/test/upload, and attach the processed replacement to the existing unsubmitted draft. Recheck all six items and manual release. Do not reuse 51 or alter migration eligibility to match the binary build number.

**If the desired outcome is truly “Data Not Collected,” a broader variant needs separate approval:** remove/replace retained remote scheduling and resolve/remove the claim-service collection, then verify every remaining network path and processor retention. This can change features and reliability, so it is not included in an analytics-only rebuild. Turning off ingestion server-side is not sufficient proof of no collection and does not remove the client's attempts/queued payloads or other services.

## Approval requested / stop conditions

Choose one:

- **A:** approve preparing disclosure/policy corrections while retaining build 51. Complete the deployed-service, claim-service, retention, and legal checks first; then present the final label preview and policy text for publication approval.
- **B:** approve implementing an analytics-disabled replacement candidate, retaining scheduled-export functionality and its necessary disclosures. Build/upload authorization and policy-publication authorization remain separate decisions.
- **Broader no-collection variant:** explicitly approve investigating feature changes needed to remove all retained server collection; do not promise a no-collection label in advance.

**Stop before publication, submission, or release.** Live U.S. lifetime prices remain Individual **$19.99**, Family **$39.99**, Upgrade **$19.99**; preserve all regional overrides and the existing price hold. Other legal, screenshot, translation, agreements, and physical-device QA blockers remain unchanged. This privacy review does not clear them.

## Primary sources and verification artifacts

- **[A1] Apple, App privacy details:** https://developer.apple.com/app-store/app-privacy-details/ — collection, optional disclosure (including Product Improvement Programs), taxonomy, purposes, linked data, tracking, Apple services, and real-time-service exception. Local captured text: `.asc/artifacts/paid-tracking/privacy-review/apple-app-privacy-details.txt`.
- **[A2] Apple, Manage app privacy:** https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/ — privacy-answer management. Local captured text: `.asc/artifacts/paid-tracking/privacy-review/apple-manage-app-privacy.txt`. Apple allows answers to change without an app update; that is not authorization to publish them here.
- **[P1] Published Whereday policy:** https://whereday.com/privacy — fetched read-only during this review. Snapshot: `.asc/artifacts/paid-tracking/privacy-review/published-privacy.{html,txt}`. Staging/label context: `docs/subscription-staging-1.7.19.md`.
- **[S1]** `IsoMe/Services/Analytics/OnboardingAnalyticsClient.swift` — enablement, queue, retry/flush guards.
- **[S2]** `IsoMe/Services/Analytics/CloudflareOnboardingAnalyticsTransport.swift` — request envelope, endpoint, persisted install identifier.
- **[S3]** `IsoMe/Services/Analytics/OnboardingAnalyticsEvent.swift` and `OnboardingAnalyticsFunnel.swift` — event/property allowlists and emitted purchase/restore outcomes.
- **[S4]** `worker/onboarding-analytics/src/index.ts`, `migrations/0001_onboarding_events.sql`, `wrangler.toml` — ingestion, D1 storage/schema, checked-in configuration; not a deployed-service audit.
- **[S5]** `IsoMe/Services/PushRegistrationManager.swift` — Keychain identity, APNs registration, transmitted schedule metadata.
- **[S6]** `IsoMe/Services/DailyExportScheduler.swift` — enabled/prior-sync gates and scheduled-export setup.
- **[S7]** `worker/scheduled-notifications/src/{notifications,scheduled}.ts`, `migrations/0001_init.sql`, `migrations/0002_interval_schedules.sql` — retained device/schedule records and deletion behavior.
- **[S8]** `IsoMe/Views/{SettingsView,MyselfClaimView}.swift` — reachable claim UI, purchase-proof submission and returned URL checks. Receiving service persistence remains unknown.

Verification here was read-only source review, Apple primary-source review, and a public policy fetch. No runtime packet capture, deployed database inspection, processor-console audit, new binary validation, or iOS test run was performed; no production requests with fabricated events or purchase proofs were sent.
