# Whereday 1.8.1 / build 57

The owner approved the phone-tested onboarding changes and explicitly requested a push and App Review submission on October 30, 2026. Version 1.8 is already distributed, so this update uses 1.8.1 and build 57. Manual developer release is retained.

The source combines the illustrated onboarding and interactive export previews with current main's privacy cleanup, StoreKit regression fixes, and SDK compatibility guards. All app/Watch/widget version numbers are aligned. The Debug-only onboarding launch override is consumed once, allowing Get Started to finish with immediate tracking off.

Two onboarding launch unit tests passed. Simulator walkthroughs covered export format selection, Photos layout, and completion with tracking off, including Always location permission. The owner tested Debug build 56 on their iPhone 17 Pro and approved the changes. The distribution candidate is compiled in Release.

Release metadata is in `metadata/whereday/version/1.8.1/`. The nine existing listing localizations were copied from distributed 1.8; only What's New and reviewer notes were updated. App Store screenshots and contact details were inherited. No purchase products, prices, availability, or regional overrides were changed by this task.

Private archive, IPA, validation, and App Store receipts are under `.asc/artifacts/release-1.8.1-57/`. Submission status will be recorded after readback.
