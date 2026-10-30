# Whereday 1.8 — submitted for App Review

## Verified current state

**Fresh October 30 UTC API readback: the app version is now `IN_REVIEW`, still attached to VALID build 52 with MANUAL release. The submission/receipt states below describe the original submission snapshot. New working-checkout analytics removal and QA changes are not in that frozen binary.**

Submitted **October 30, 2026 at 00:04:38 UTC** (October 29 local time).

- App: `6761960794` / `com.bontecou.isome`.
- App Store version: **1.8**, ID `676e5d10-dd42-4eb8-b860-bba89da97b20`.
- Build: **52**, ID `82ecbf53-4b82-4d07-80f0-62799f50d009`, processed **VALID**.
- Review submission: `7f40896b-88c1-46da-8d92-794a6ec54589`, **WAITING_FOR_REVIEW**.
- App version state: **WAITING_FOR_REVIEW**.
- Release type: **MANUAL**, independently read back after submission.
- Six submitted items: app version, subscription-group version, and four subscription versions. Each subscription version independently reads **WAITING_FOR_REVIEW**.
- **Not released.** No developer-release command was run. Apple approval will not automatically release this app version.

This is the authoritative current record. [The 1.7.19/build 51 record](subscription-staging-1.7.19.md) is historical: its unsubmitted version record was renamed to 1.8 and attached to a new binary. Uploaded build 51 itself was not overwritten or reused.

## Pricing hold remains mandatory

Post-submission U.S. readback:

| Product | Current price |
| --- | --- |
| Individual Lifetime | **$19.99** |
| Family Lifetime | **$39.99** |
| Family Upgrade | **$19.99** |

No App Store pricing mutation or future price schedule was performed. Regional overrides were left untouched. The potential future lifetime targets remain **unauthorized**: do not apply them merely because subscriptions are submitted or approved. Follow [the pricing hold](paid-tracking-rollout.md), including the requirement that the subscription-enabled app is live and the owner separately authorizes any lifetime change.

Subscription prices/trials/group configuration were not changed by this release operation: Individual Weekly $0.99, Individual Yearly $29.99, Family Weekly $1.99, Family Yearly $49.99 (U.S.); seven-day eligible trials, one group, Family Sharing on Family products only.

## Candidate and source provenance

Private artifacts: `.asc/artifacts/stage-1.8-52/`.

The uploaded candidate was built from a detached checkout at base **`f774ee6`**, with the exact release changes retained in `candidate.patch` and `OnboardingAnalyticsPrivacyTests.swift`. `source-manifest.json` hashes the frozen source; it was checked again after the local QA and concurrent development work. Main-checkout changes do not silently alter this uploaded candidate.

All four distributed bundles were inspected inside the exported IPA and have version **1.8/build 52**: iPhone app, phone widget, Watch app, and Watch widget. `ipa-verification.json` includes the IPA SHA-256 and bundle readbacks.

### Privacy simplification

At the user's request to choose the least complicated handling without a need for analytics retention:

- Production analytics defaults to **disabled**.
- Production transport factory returns **no-op**, even if the enable environment value is supplied.
- Disabled clients discard persisted unsent analytics queues; they do not replay them.
- The existing `MyselfClaimFeature.isEnabled = false` remains off, with UI/deep-link/action guards.
- Scheduled-export routing functionality remains intact. No new retention job or backend schema was introduced by this release task.
- Historical analytics records were not deleted. Older app versions may still send analytics or expose purchase claims, which the published policy/disclosures describe separately.

The ingestion allowlist patch was not deployed: collecting subscription analytics is unnecessary for 1.8. Concurrent local analytics-worker/privacy changes were observed and deliberately left outside this candidate/deployment. Last read-only production check still showed the September 1 analytics deployment `b6b4af68-21d4-4593-95fe-449501e2a8e3`.

### Access compatibility

Grandfather cutoff remains **51**, preserving verified original builds through 50 as legacy free tracking. Do not move this eligibility boundary just because the new uploaded binary is 52. Existing free users retain their export gate, all prior lifetime purchases remain valid, and expired new-cohort users retain viewing/export of existing records.

## Verification completed

- Frozen candidate: **355 XCTest tests + 11 Swift Testing tests passed**, using `scripts/test-ios.sh` with normal simulator signing.
- Separate actual non-DEBUG compilation/smoke: disabled analytics default, no-op transport, no sends/installation-ID creation, discarded persisted queue.
- Release archive/export/upload succeeded; Apple processing **VALID**.
- Nine-locale release-copy checks: **6 passed**. Remote listing fields exactly match the canonical local 1.8 metadata, including a direct Apple Standard EULA URL.
- Isolated local StoreKit QA using held-price fixtures passed catalog/trial/purchase, **restore**, expiry, and lifetime behavior. The view capture harness used the actual candidate PaywallView, not a recreated paywall image.
- Final `asc validate` with exact IPA and public URL checks: **0 errors / 0 blocking findings**.
- Eighteen nonblocking warnings: four optional subscription promotional images, four subscription review-readiness advisories before first submission, nine homepage/marketing URL root advisories, and CLI deep-validation web-session unavailability. The authenticated browser independently verified privacy publication, active agreements, and the review preparation context.

Test-only fixture corrections made later in the main/QA checkout mirror held lifetime prices ($19.99/$39.99/$19.99). They are not production price changes and do not modify the frozen archive. Production prices are supplied by StoreKit.

## Screenshots and review material

- Four subscription review screenshots replaced with the correct selected weekly/yearly plans, trial copy, and held Lifetime prices. All four are **COMPLETE** with verified source checksums.
- **80 refreshed storefront images** across nine locales and eighteen iPhone/iPad sets are **COMPLETE**, checksum-matched to approved local files, and in the intended order. Watch images were inherited; no new Watch UI screenshot claim is made.
- One optional Hindi iPad permissions screenshot stalled in Apple's `UPLOAD_COMPLETE` state. Its owned uploader was stopped, the pending image was removed, and that locale retains three verified iPad screenshots. The withheld local image is in `screenshots/withheld-hi/`. No subscription review evidence was omitted.
- Screenshot-set editing temporarily required removing the app review item. Subscription screenshot replacement similarly required temporarily unlocking the corresponding review item. All six items were restored and checked before submission.
- `reviewer-notes.txt` now identifies **1.8/build 52**, disabled analytics/claims, existing access, trial/expiry behavior, Family Sharing, the held prices, and manual release.
- All nine version localizations were staged without changing keywords/support/marketing URLs, other than adding the direct standard EULA destination in descriptions.

## Authorized public updates

The user authorized privacy/terms publication and preparation/submission for App Review.

- App Privacy was published with six linked/no-tracking data types covering the older-version collection still in use: Device ID, User ID, Purchase History, Product Interaction, Other Diagnostic Data, Other Data Types, with the purpose selections in the [deployed audit](release-drafts/1.7.19/privacy-deployed-audit.md).
- This is not a claim that 1.8 collects all six: 1.8 disables the optional analytics/claim paths. The policy explains version differences, indefinite portions of existing retention, functional scheduling metadata, deletion limitations, and recovery copies without inventing a universal expiry guarantee.
- Public `/privacy`, `/terms`, and the privacy guide were updated and verified by HTTP readback. The homepage no longer advertises unconditional free tracking/no subscriptions: it explains the 1.8 new-user plans, protected existing access, and held Lifetime prices.
- Terms retain Apple's **standard EULA** and supplemental service/purchase terms, rather than selecting a new custom EULA. Conflicting blanket reverse-engineering/redistribution restrictions were removed in favor of applicable open-source-license and mandatory legal rights. No independent legal-counsel certification is claimed.
- Apple Business readback: Free and Paid Apps agreements **Active**, through November 3, 2026. No agreement, tax, banking, or compliance record was changed.

## Evidence files

Under the private artifact directory:

- `review-submit.json`, `review-submit.log` — submission operation.
- `review-submitted-readback.json` — target app, six items, submission date/state.
- `version-submitted-readback.json` — 1.8, build 52, WAITING_FOR_REVIEW, MANUAL.
- `submitted-{individual,family}-{weekly,yearly}.json` — each subscription version WAITING_FOR_REVIEW.
- `lifetime-prices-after-submit.json` — held U.S. prices.
- `validation-final.json`, `subscription-validation-final.json` — readiness results.
- `screenshots/delivery-verification.json` — all eighteen refreshed sets and eighty delivered images.
- `subscription-review/` — four correct paywall captures, replacement/readback receipts, checksums.
- `pinned-tests.log`, `held-price-storekit-qa.log`, `release-analytics-smoke.log` — tests and privacy checks.
- `published-{privacy,terms,homepage}.html`, `website-*-deploy.log` — public publication evidence.

## Still required before manual developer release

- Respond to any Apple review questions/rejections and verify the app and all four subscriptions are approved.
- Real-device acceptance, including genuine multi-account Family Sharing and paired Watch behavior, remains a before-release check; local StoreKit and simulator tests do not certify those paths.
- Native-language human review was not independently performed. Automated locale/key/interpolation/length checks passed; review any copy concerns before release.
- Renew required agreements/membership if needed after the currently shown November 3 expiry.
- Obtain a **separate explicit instruction to release the app**. Approval for App Review was not release authorization.
- Lifetime price increases still require their own later authorization and the conditions in the pricing hold. Do not combine them with release by assumption.

## Current working-checkout qualification — October 30 UTC

The owner confirmed weekly/yearly subscriptions and deferred Vox Android. These checks qualify the local candidate, including its uncommitted changes; they do not certify committed main, an uploaded binary, Apple sandbox accounts, cross-account Family Sharing, or a physically paired Watch.

- Health.md: 24 purchase-policy/local StoreKit tests, five mandatory-root-wall UI tests and four onboarding/import/first-preview UI journeys passed. Twenty focused Android billing/offer/admission tests passed; queued Apple and Android compilation passed.
- Whereday: 17 purchase/StoreKit tests and eight Watch queue/reconnect regressions passed. Restore uses the actual restore path; separate fresh-user cases prove cancellation and network-failed restore cannot grant tracking. These are local StoreKit and synthetic Watch tests.
- Current-source and submitted-build provenance must be reconciled before release. Keep the first-paid Whereday cutoff at 51 and existing Lifetime price schedules unchanged.
