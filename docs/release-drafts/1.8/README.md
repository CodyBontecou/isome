# Whereday 1.8 subscription release

**Submitted:** app 1.8/build 52 and all four subscription versions are **IN_REVIEW**, with **MANUAL** release. See [the verified current record](../../subscription-staging-1.8.md). The uploaded frozen binary disables analytics; newer concurrent source-only removal work is not included and requires another unused build number if selected for a replacement.

> Later unpublished source revision: custom app analytics are now removed in all build configurations, including Debug. The source/build freeze and prior disable-only behavior recorded below are historical evidence and do not qualify the current edited source. No new archive, upload, submission, policy publication or release was performed for the removal. Use privacy-review.md for the current proposal; build and requalify a fresh candidate after review.

This candidate supersedes the unsubmitted 1.7.19/build 51 draft. The existing ASC app-version record was renamed to **1.8**, preserving **MANUAL** developer release. New distribution build: **52**; old build 51 remains unchanged.

## User decisions

- Skip optional additional worker regression tests.
- Prefer the least complicated privacy handling; no need to retain analytics for product purposes.
- Authorize necessary privacy/terms publication and prepare the app plus four subscriptions for App Review.
- Keep lifetime prices and all regional overrides unchanged. Apple approval is not permission to raise prices or release the app.

## Candidate behavior

Production 1.8 disables onboarding/purchase analytics in both the default client and transport factory. A disabled client discards persisted queued events rather than sending them later. Debug explicitly opted-in analytics remains available for development. The current default-off myself.md claim rollout switch stays off. Scheduled exports retain their existing functional push-routing service; no backend retention system was added for this release.

Existing installs on older versions can still send analytics or use older claim functionality. Published privacy disclosures therefore cover these version-dependent flows, and the policy explains that 1.8 disables them. Historical records were not deleted. The existing worker allowlist patch is not needed to collect analytics from 1.8 and was **not deployed by this release task**.

The grandfather eligibility boundary remains **51**: verified original app builds through 50 retain free tracking and their prior export gate. A new binary number does not move the boundary. Existing lifetime purchases remain valid. Expired new-cohort users retain record viewing/export.

## Artifacts and verification

Private build artifacts and remote readbacks: `.asc/artifacts/stage-1.8-52/`.

- Frozen source: detached base `f774ee6`, plus `candidate.patch` and the new `OnboardingAnalyticsPrivacyTests.swift`; content hashes in `source-manifest.json`.
- Exact candidate suite: **355 XCTest + 11 Swift Testing tests passed**.
- Separate non-DEBUG smoke: disabled default, no-op transport even with enable environment override, zero sends/ID creation, persisted queue discarded.
- Release archive/export uploaded and processed **VALID**: build `82ecbf53-4b82-4d07-80f0-62799f50d009`, version 1.8/build 52 in phone, Watch, and both widgets.
- Later local StoreKit fixture corrections mirror the held lifetime prices ($19.99/$39.99/$19.99). These are test fixtures, not App Store price changes. Candidate production prices come from StoreKit. The uploaded frozen source is not silently changed by those fixture edits.
- An isolated QA checkout uses the same runtime app code with corrected fixtures and a test-only presentation harness. It captured the four real PaywallView states and passed purchase/trial, **restore**, expiry, and lifetime integration checks. This is local StoreKit testing, not physical-device or multi-account Family Sharing certification.
- Nine-locale listing integrity tests pass. Native-language human review was not independently performed; tests cover key coverage, interpolation, limits, and price preservation.

## Public/legal decisions

The authorized privacy/terms update was deployed to `whereday.com`; public readbacks confirm it. The website uses Apple's **standard EULA** with supplemental service/purchase terms, not a new custom EULA. Conflicting blanket reverse-engineering/redistribution restrictions were removed in favor of preserving applicable open-source-license and mandatory legal rights. This is not a claim of independent legal counsel review.

App Privacy was published with six linked data types and no tracking: Device ID (Analytics/App Functionality), User ID (App Functionality), Purchase History (Analytics/App Functionality), Product Interaction (Analytics), Other Diagnostic Data (Analytics/App Functionality), Other Data Types (App Functionality). This includes earlier-version behavior still in use; do not describe 1.8 as collecting all those optional flows.

Apple Business page readback: Free Apps and Paid Apps agreements **Active**, through November 3, 2026. No agreements, tax forms, banking, or compliance records were changed.

## Review materials

- `metadata/whereday/version/1.8/*.json`: nine staged app-version locales, copied from the approved subscription drafts.
- `subscription-localizations.json`: the four existing subscriptions and their nine localized names/descriptions; product IDs, prices, trials, and Family Sharing settings are unchanged.
- `reviewer-notes.txt`: 1.8/build 52 notes, legacy access, paid tracking, expired-user behavior, held lifetime prices, analytics/claim disabled, and manual release.
- `terms-proposed.md`: retained local drafting input; published authoritative text is in `marketing/public/terms.html`, not this file's proposal preamble.
- Screenshots: nine-locale iPhone/iPad refresh and held-price subscription review captures under the private artifacts. Watch screenshots are inherited; the Watch UI did not change in this candidate.

Read the [current submission record](../../subscription-staging-1.8.md) for the actual parent submission state; individual review-item flags can remain READY_FOR_REVIEW even while the parent is WAITING_FOR_REVIEW. Eighty refreshed storefront images were delivered; one optional Hindi iPad permissions image was withheld after stalling in Apple processing, leaving three complete images for that locale/device. Physical multi-account Family Sharing and real-device release acceptance should be checked before manual developer release, even if App Review approves first.
