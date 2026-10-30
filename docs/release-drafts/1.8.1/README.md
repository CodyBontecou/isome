# Whereday 1.8.1 / build 57

The owner approved the phone-tested onboarding changes and explicitly requested a push and App Review submission on October 30, 2026. Version 1.8 is already distributed, so this update uses 1.8.1 and build 57. Manual developer release is retained.

The source combines the illustrated onboarding and interactive export previews with current main's privacy cleanup, StoreKit regression fixes, and SDK compatibility guards. All app/Watch/widget version numbers are aligned. The Debug-only onboarding launch override is consumed once, allowing Get Started to finish with immediate tracking off.

Two onboarding launch unit tests passed. Simulator walkthroughs covered export format selection, Photos layout, and completion with tracking off, including Always location permission. The owner tested Debug build 56 on their iPhone 17 Pro and approved the changes. The distribution candidate is compiled in Release.

Release metadata is in `metadata/whereday/version/1.8.1/`. The nine existing listing localizations were copied from distributed 1.8; only What's New and reviewer notes were updated. App Store screenshots and contact details were inherited. No purchase products, prices, availability, or regional overrides were changed by this task.

Private archive, IPA, validation, and App Store receipts are under `.asc/artifacts/release-1.8.1-57/`. Submission status will be recorded after readback.

## Candidate qualification

Source pushed to main through `839ba8cd`. The Release archive and exported IPA succeeded. All four shipped bundles (phone, phone widget, Watch, Watch widget) were inspected and have version 1.8.1/build 57.

The final SDK-matched test run executed 355 XCTest cases: 354 passed and one StoreKit cancellation case failed; all 11 Swift Testing cases passed. The failing cancellation case also failed in isolation: Apple's local test service returned an unmapped `ASDServerErrorDomain` 907 instead of the injected user-cancel result. Tracking stayed locked and the failed-restore access assertion passed. Both the production StoreManager and this test are unchanged from integrated remote main; the failure was retained rather than skipped or weakened. The separate onboarding launch regression tests passed within the full run.

The first full-run attempt hit a full-disk SQLite I/O failure; that environment failure is not counted as a credential or app regression. Rebuildable project caches were cleared before the final run. The analytics-removal checks (2), release-copy checks (6), retired-worker tests (3), and worker typecheck passed.

App Store processing and readiness validation are being checked before review submission.
