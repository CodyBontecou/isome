# Get Started with tracking off

The scrawl `scrawl-1793362574186-1db1-19` showed Get Started leaving the final onboarding screen unchanged unless immediate tracking was enabled.

## Cause and fix

The QA installation was launched with `-hasCompletedOnboarding NO`. Foundation's argument domain masked the completion write throughout the process. The action persisted completion, but the screen still read false. Restarting without the override opened the map with tracking off, confirming that completion itself did not require tracking.

Debug startup now consumes only that preference from the argument domain and persists it as the initial value. Completion and Settings can subsequently update it. Other launch preferences remain intact. Production onboarding behavior is unchanged.

## Verification

Before the fix, `onboarding-finish-without-tracking` deterministically failed at the check that onboarding should disappear after Get Started. The same replay passed after the fix. It was tested with no location permission requested.

`onboarding-authorized-without-tracking` then passed with Always location access pre-granted on the dedicated simulator, the immediate tracking toggle off (accessibility value 0), and the map's Start tracking button visible after completion. The final screenshot shows the play button with tracking off. The idle step warned about a small animated region on the map; the positive map control check passed.

Both walkthroughs use an accessibility-discovered Get Started point at (0.5975, 0.912), specific to 402×874 portrait geometry. The native runner omits the SwiftUI footer button (both id and text selectors failed during the earlier export walkthrough), so outcome checks retain raw accessibility waits. The authorized replay requires location-always permission before launch; it does not change permissions itself.

Unit regression command:

```sh
scripts/test-ios.sh --destination 'platform=iOS Simulator,id=F514640E-1994-48D1-ADD2-B778CB9F83D4' -only-testing:IsoMeTests/OnboardingLaunchConfigurationTests
```

Passed: 2 tests, 0 failures. Result bundle: `artifacts/test-results/IsoMe-20261030-081907-83000.xcresult`.

Build 56 was signed, installed on Cody's iPhone 17 Pro, and launched at the final onboarding page for manual verification.
