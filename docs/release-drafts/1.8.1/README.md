# Whereday 1.8.1 / build 57

The owner approved the phone-tested onboarding changes and explicitly requested a push and App Review submission on October 30, 2026. Version 1.8 is already distributed, so this update uses 1.8.1 and build 57. Manual developer release is retained.

The source combines the illustrated onboarding and interactive export previews with current main's privacy cleanup, StoreKit regression fixes, and SDK compatibility guards. All app/Watch/widget version numbers are aligned. The Debug-only onboarding launch override is consumed once, allowing Get Started to finish with immediate tracking off.

Two onboarding launch unit tests passed. Simulator walkthroughs covered export format selection, Photos layout, and completion with tracking off, including Always location permission. The owner tested Debug build 56 on their iPhone 17 Pro and approved the changes. The distribution candidate is compiled in Release.

Release metadata is in `metadata/whereday/version/1.8.1/`. The nine existing listing localizations were copied from distributed 1.8; only What's New and reviewer notes were updated. App Store screenshots and contact details were inherited. No purchase products, prices, availability, or regional overrides were changed by this task.

Private archive, IPA, validation, and App Store receipts are under `.asc/artifacts/release-1.8.1-57/`. Submitted October 30, 2026 at 08:40:56 America/Puerto_Rico (12:40:56 UTC). App Store Connect readback confirms **WAITING_FOR_REVIEW**, with **MANUAL** release.

## Candidate qualification

Source pushed to main through `839ba8cd`. The Release archive and exported IPA succeeded. All four shipped bundles (phone, phone widget, Watch, Watch widget) were inspected and have version 1.8.1/build 57.

The final SDK-matched test run executed 355 XCTest cases: 354 passed and one StoreKit cancellation case failed; all 11 Swift Testing cases passed. The failing cancellation case also failed in isolation: Apple's local test service returned an unmapped `ASDServerErrorDomain` 907 instead of the injected user-cancel result. Tracking stayed locked and the failed-restore access assertion passed. Both the production StoreManager and this test are unchanged from integrated remote main; the failure was retained rather than skipped or weakened. The separate onboarding launch regression tests passed within the full run.

The first full-run attempt hit a full-disk SQLite I/O failure; that environment failure is not counted as a credential or app regression. Rebuildable project caches were cleared before the final run. The analytics-removal checks (2), release-copy checks (6), retired-worker tests (3), and worker typecheck passed.

Apple processed build 57 successfully. Final IPA-aware App Store readiness validation returned **0 errors, 0 blocking findings**, four optional subscription promotional-image warnings, and two informational notices. The prepared listing inherited its screenshots and previously published App Privacy settings.

## Review submission

- App version: `5f65a38c-ee53-4b8e-8824-1e273236cad2` / **1.8.1**.
- Build: `cc2bf600-ac6c-42b1-b74f-daa03c8ed934` / **57**, processed VALID.
- Submission: `c9406336-22cb-4007-8939-396c17d79b73`.
- Submitted: **October 30, 2026, 08:40:56 America/Puerto_Rico**.
- Version state: **WAITING_FOR_REVIEW**.
- Release type: **MANUAL**. This task submitted for review; it did not release the update.

The submission tool created the correct app-version submission and left two unrelated stale draft submissions intact. Exact upload, build-attachment, validation, and submission/readback receipts are retained in the private artifact directory.

After reporting the complete test results, Xcode stalled during result finalization and was stopped; console logs are retained. The unchanged StoreKit cancellation test failure remains a known qualification limitation, not an all-green suite claim.
