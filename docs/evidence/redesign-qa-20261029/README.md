# Field Notes redesign QA — October 29, 2026

**Duo hardware remains unverified.** The redesign is already on `main` in `d120326` (Bring Field Notes redesign and Duo layouts to Whereday). UI checks and captures below are against that commit. The QA branch also includes the subsequent `25ba0c2` button-contrast update from main, and the full signed suite was rerun after that merge. This follow-up also adds compile-time guards around Duo arrangements: older compiler/SDK toolchains use the existing single-pane layout. Runtime availability checks remain in place for supported SDK builds. This does not certify a release candidate.

## Verification scope

| Check | Result | Evidence |
| --- | --- | --- |
| Signed regression suite, standard iPhone simulator, iOS 27.0 | 353 XCTest + 11 Swift Testing tests passed, zero failures after merging `25ba0c2` and adding older-toolchain guards | Local result bundle `/private/tmp/whereday-sdk-guard-qa.xcresult` |
| Signed Duo simulator build, iOS 27.1 | Passed | Build product `/private/tmp/whereday-redesign-qa-sim/Build/Products/Debug-iphonesimulator/IsoMe.app` |
| Open → half-open → cover → open | 10/10 replay steps passed | `duo-journal-folding` |
| Paywall CTA and onboarding controls | 6/6 replay steps passed | `duo-flow-layouts` |
| Selected visit survives cover/inner transition | 6/6 replay steps passed | `duo-visit-continuity` |
| Inspector controls remain available after rotation requests | 4/4 replay steps passed | New `duo-inspector-rotation` fragment |
| Name field focus and keyboard dismissal | Manual smoke check: field focused, keyboard and Done displayed; Done dismissed keyboard and retained Valencia Street Stop without typing | [Keyboard capture](inspector-keyboard.png), [landscape inspector](inspector-landscape.png) |
| Regular physical iPhone, iPhone 13 Pro Max / iOS 27.0.1 | Signed Debug builds installed and launched; isolated QA app navigated welcome → features → permission setup | [Incomplete diagnostic trace](physical-onboarding-incomplete.yaml) |

The original `d120326` suite also passed (352 XCTest + 11 Swift Testing tests). Duo UI replays, manual checks, physical builds, and screenshots in this report were collected against `d120326`; they were not rerun after the contrast update. The final signed regression suite covers the updated QA branch. Duo tests use synthetic screenshot fixtures and tracking off. The keyboard capture is sideways because the screenshot orientation override did not match the new UI orientation; it records the visible keyboard state, not a polished product screenshot. The narrow portrait inspector wraps date labels heavily while the keyboard is visible; polish/recheck that state before release.

The existing [Duo screenshots and earlier checks](../duo-interface-20261029/verification.json) cover dark mode and XXX-Large text. Those are historical evidence from the earlier redesign pass, not additional checks rerun here. Their old local/uncommitted status describes that earlier pass; the redesign has since landed on main.

## Physical iPhone limits

The canonical app found retained tracking state. Its records were preserved. Tests that could create or modify data were moved to a separately identified QA app (`com.bontecou.isome.redesignqa`) with separate local storage. The temporary QA copy disabled App Groups and push entitlements to use the available signing profile; production repository signing and entitlements were not changed. Debug entitlement behavior is not proof of StoreKit purchase behavior.

The permission-dialog wait did not pass. The phone later showed Settings, so interaction was paused. This is an incomplete observation, not a confirmed permission-flow defect or a passing onboarding test. The diagnostic trace intentionally retains the failed wait and is outside `.argent/e2e` so it is not mistaken for a passing regression.

Tracking start/stop and background behavior, photo matching, visit editing/persistence, export sharing, real sandbox-account purchases, App Groups, Apple Watch, and push behavior remain **unverified on hardware** in this pass. No existing tracking records were seeded, deleted, or edited.

## Replay

Use a dedicated Duo simulator; fixture seeding replaces that simulator app's local records. Replay `.argent/e2e/duo-journal-folding.yaml`, then select the synthetic Valencia Street Stop map marker to show its inline inspector. Run `duo-visit-continuity` and `duo-inspector-rotation` with their execution prerequisites acknowledged. Run `duo-flow-layouts` separately because it changes the active screen.

The new rotation fragment checks inspector control availability, not exact pane dimensions, frame rate, or hinge geometry. Its raw AX-service waits are deliberate: the Duo native hierarchy sees multiple foreground services and cannot reliably resolve the same controls. Absence checks in the existing fold tests are paired with the same selector being present in the preceding posture.

## Remaining release checks

- Recheck keyboard layout in both orientations, Reduce Motion, dark mode, and larger text on the final candidate.
- Complete the physical iPhone flows above when the device is available for uninterrupted testing.
- Keep Duo support marked simulator-tested; physical Duo hinge, touch, display handoff, thermal, and performance behavior remain unverified.
- Follow [subscription release readiness](../../subscription-release-readiness.md) before staging: confirm the first-paid build cutoff and unused build number, finish subscription/grandfathering QA, and prepare the legal/metadata/reviewer package.

No TestFlight upload, App Review submission, release, or pricing change was performed. The existing explicit authorization requirements and live pricing hold remain in effect.

## CI compatibility correction

GitHub CI initially failed to compile `ArrangementView` using Xcode 26.6 / iOS 26.5 SDK. Runtime `#available` checks do not hide unknown SDK types from the compiler. Swift compiler guards now exclude the Duo-specific declarations and references on pre-6.4 toolchains and use the shared single-pane fallback. The local signed suite passed again after this correction (353 XCTest + 11 Swift Testing). GitHub CI exercises the older-toolchain branch; local Xcode exercises the Duo-capable branch.
