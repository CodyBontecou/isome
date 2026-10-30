# 1.7.19/build 51 staging record

> **Historical.** The version record was subsequently renamed to **1.8** and submitted with **build 52** and all four subscriptions, retaining MANUAL release. Build 51 itself was not submitted or overwritten. See the [current submission record](subscription-staging-1.8.md).

Prepared and uploaded on October 29, 2026, at the user's request. **Not submitted for App Review and not released.** The live pricing hold remains in effect.

## Verified staged state

| Item | Value |
|---|---|
| App | Whereday, `6761960794`, bundle `com.bontecou.isome` |
| Source | Pinned commit `d120326` (Field Notes redesign and Duo layouts, including the subscription/migration work) |
| Version / build | `1.7.19` / `51` |
| Build ID | `69cf281a-4cfb-4720-8386-dc5b9768f038` |
| Build processing | `VALID`, App Store eligible, exempt encryption |
| App version ID | `676e5d10-dd42-4eb8-b860-bba89da97b20` |
| Release policy | **MANUAL**, read back after staging |
| App version state | `READY_FOR_REVIEW`, not `WAITING_FOR_REVIEW` |
| Review draft ID | `7f40896b-88c1-46da-8d92-794a6ec54589` |
| Review draft state | `READY_FOR_REVIEW`, unsubmitted |
| Live app | 1.7.18 remains the distributed version; 1.7.19 was not released |

The review draft contains exactly six items, confirmed through API readback and the authenticated App Store Connect UI's **Items Ready to Submit (6)** panel:

1. App version 1.7.19, ID above.
2. Whereday Tracking group version `03de59bf-5d9d-4eb8-a02e-7eee133e85a7`.
3. Individual Weekly version `d7e61259-4999-4ecb-a433-4ec321e86b68`.
4. Individual Yearly version `a4e3d574-b2c6-4b09-b928-84175d7f89ea`.
5. Family Weekly version `80745c7f-b1b5-4bc2-bad9-2811b25b9eb8`.
6. Family Yearly version `19e9789a-b682-4400-85e7-8acd5d634d4a`.

The public API accepted the app, subscription-group, and subscription-version review items together. The UI confirms their presence in this app's draft. The **Submit for Review** button was not clicked, and no review-submit or app-release command was run. Two older empty review drafts were left untouched.

## Build provenance and checks

A detached source worktree was created under `.asc/artifacts/stage-1.7.19-51/source` to prevent ongoing working-tree edits from entering this candidate. The exact pinned source passed:

- Full signed iOS suite: **352 XCTest cases plus 11 Swift Testing tests**.
- Six offline release-copy tests.
- Release archive and App Store export.
- Exported IPA checks: all four app/extension bundles are 1.7.19/build 51, and the distribution binary contains the four subscription IDs and migration cohort key.
- ASC upload with checksum verification; upload wait and build readback confirmed processing `VALID`.

IPA: `.asc/artifacts/stage-1.7.19-51/IsoMe-1.7.19-51.ipa`.
Archive: `.asc/artifacts/stage-1.7.19-51/IsoMe-1.7.19-51.xcarchive`.
Tests: `.asc/artifacts/stage-1.7.19-51/tests.xcresult`.
The full source hash, logs, plans, and readback JSON are in the same gitignored staging directory.

**Later local UI/contrast edits are not included in this uploaded build.** Do not describe build 51 as containing those edits. If they are intended for this release, finish/retest them and upload a new, unused build number; do not overwrite/reuse build 51. The tested archived worktree was not modified to incorporate ongoing work.

## Metadata and review instructions

- The nine canonical 1.7.19 descriptions, promotional texts, release notes, keywords, and URLs were staged from the pinned draft. API readback matched every field.
- Reviewer notes were staged and verified against the pinned text, allowing for Apple's removal of the final newline.
- The metadata-only staging directory contains no app-info scope, so staging did not update shared live app-info fields.
- No website terms, custom EULA, App Privacy answers, subscription prices, or lifetime prices were changed.
- The proposed additional subscription product translations (36 localizations) remain local. Existing remote subscription localizations were not replaced as part of app-version staging.

Owner/native-language approval is still needed for the staged draft copy before submission. Staging does not establish legal or translation approval.

## API validation versus release approval

The staging validator passed with **0 errors, 8 warnings, and 2 advisories**. Full read-only validation against this exact version and IPA, including iPad requirements, URL checks, and deep checks, reported **0 errors / 0 API blocking findings**, with 18 warnings and one informational finding:

- Four subscriptions remain ready to submit, not approved.
- Four optional subscription promotional images are absent. These are not App Review screenshots and are not catalog blockers unless the relevant promotional/redemption/win-back features are planned.
- Nine URL warnings concern the existing marketing URL resolving to the website root. These are advisories, not missing Terms/EULA links. All nine staged descriptions now include the legal links.
- CLI deep validation cannot use an authenticated cached Apple web session. Its privacy/agreements/first-review checks are therefore incomplete. A separate existing Pi browser session was successfully used for read-only privacy and review-draft inspection; no cookies were exported or session configuration changed.

Passing structural API checks does not resolve the following content/privacy/QA approvals.

## Required before submitting

### 1. Resolve the published privacy-label mismatch

Follow-up: [deployed-service audit and final proposed disclosures](release-drafts/1.7.19/privacy-deployed-audit.md), superseding the [initial privacy options](release-drafts/1.7.19/privacy-review.md). Read-only production inspection confirms retained analytics, scheduling metadata, and active purchase/account linkage. The proposal contains six linked data types, actual retention/deletion behavior, and remaining processor/access-policy limits. It also identifies the deployed analytics worker's missing subscription-product allowlist. Build 51 and all remote settings remain unchanged; no publication, deployment, or replacement build is authorized.

The authenticated App Store Connect App Privacy page is published and currently says **Data Not Collected** / “The developer does not collect any data from this app.”

The pinned Release source enables onboarding analytics by default (`OnboardingAnalyticsClient.isEnabledByDefault`). Its default Cloudflare transport sends a persistent install ID and onboarding/purchase events. The worker source retains install IDs/events in D1. Relevant source files:

- `IsoMe/Services/Analytics/OnboardingAnalyticsClient.swift`
- `IsoMe/Services/Analytics/CloudflareOnboardingAnalyticsTransport.swift`
- `IsoMe/Services/Analytics/OnboardingAnalyticsTransport.swift`
- `worker/onboarding-analytics/src/index.ts`

The owner must review the actual deployed collection/retention and Apple's disclosure requirements, then authorize appropriate privacy answers/publication, or choose a collection-disabled code change and a new build. Published status alone is not evidence that the label accurately describes this candidate. No privacy answers were changed during staging. No precise location data is required to explain this concern; a persistent installation identifier and activity events themselves need review.

### 2. Approve the terms/EULA treatment and authorize publication

A fresh read of the live `/terms` page still describes one-time export purchases and says tracking remains free. The proposed subscription terms remain local in `docs/release-drafts/1.7.19/terms-proposed.md`. Review the trial/renewal/cancellation wording, grandfathering, existing purchase rights, and the license/AGPL issue flagged there.

The API returned no configured custom EULA resource. Do not assume the website terms are an Apple-selected custom EULA; confirm the intended standard-EULA/supplemental-terms treatment. Approve and separately authorize the correct legal-page publication before the subscription submission relies on the existing link. No website publication or EULA selection was performed.

### 3. Refresh and approve screenshots for the actual candidate and held prices

The app version inherited its storefront screenshots from the live version, including iPhone, Apple Watch, and iPad sets. The English sets currently contain five `APP_IPHONE_67`, one `APP_WATCH_SERIES_10`, and five `APP_IPAD_PRO_3GEN_129` images, so the IPA-specific required-iPad check passes.

Presence/size checks do not certify that those screenshots match the new Field Notes/Duo UI or accurately explain new-user paid access. Review/refresh them before submission. Earlier subscription-review screenshots also came from local target-price fixtures, while live lifetime prices are held lower. Refresh those assets against the candidate and actual held prices. **Do not change live prices to make old screenshots appear correct.** No screenshot replacement was performed in this staging task.

### 4. Confirm final device QA and candidate scope

Confirm fresh-user trials/ineligible accounts, canceled/pending/failed purchases, restore, renewals/expiration/refunds, preserved history/export, pre-subscription build-50 reinstalls/another device, existing lifetime owners, Family Sharing, Siri/Shortcuts, physical Watch offline/reconnect, and accessible layouts. Automated local tests do not certify these physical-device flows.

Decide whether later local contrast/UI fixes must be included; if so, a new tested archive/build is needed. The candidate in ASC is the pinned `d120326` build, not the subsequently modified working tree.

### 5. Confirm agreements and separately authorize submission

Paid-agreement/account status remains unverified in this staging task; confirm required agreements are current in App Store Connect Business before submitting. No agreements were accepted or modified.

The six review items are now staged, not awaiting association. Once the privacy/legal/copy/assets/QA decisions above are resolved, request explicit approval to submit **this draft** (or its replacement build). Keep manual release. Approval by Apple is separate from developer release, and neither grants permission to change held lifetime prices.

The analytics worker's subscription product allowlist is updated in source but its deployed state was not verified/deployed here; handle that separately before relying on subscription funnel events.

## Live pricing hold: verified unchanged

Before/after U.S. readbacks matched:

| Product | Still live | Held future target |
|---|---:|---:|
| Individual Lifetime | $19.99 | $49.99 |
| Family Lifetime | $39.99 | $89.99 |
| Family Lifetime Upgrade | $19.99 | $40.00 |

No pricing write or scheduled increase was made. Custom regional overrides were not edited. Do not apply targets until all four subscriptions are approved, the subscription-enabled app is actually live, and the user separately authorizes applying the new prices. No service, website, or app release was performed during staging.
