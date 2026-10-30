# Onboarding scrawl follow-up

Feedback: scrawl-1793361805184-1db1-10, moments #1–#5.

- Progress dots: 7 to 5 points, 28-point horizontal cells instead of 44; footer spacing reduced.
- Removed the visible “An example day” caption from all illustrated pages. VoiceOver still identifies the fictional map illustrations.
- Replaced the export map illustration with JSON, CSV, and Markdown segments that show the same three fictional visits as short field excerpts. The file name and content both change with selection. Wide text scrolls horizontally and the page scrolls vertically for larger text sizes.
- The Photos card, including “Optional,” is fully above the footer at 402×874 points with default text size, without scrolling.

## Verification

`scripts/test-ios.sh --destination 'platform=iOS Simulator,id=9A45202D-BD45-4AF2-8B8E-CA0BE5F2F07A' -only-testing:IsoMeTests/ExportServiceRoundTripTests`

Passed: 12 tests, 0 failures. Result bundle: `artifacts/test-results/IsoMe-20261030-080541-67999.xcresult`.

Visual checks used the dedicated Whereday Ink Onboarding simulator (iPhone 18 Pro geometry, iOS 27.0). Checked each format's filename and content, compact indicators, and the full Photos card. The supplied scrawl provides the before images; these are annotated and have a different image scale, so they are for visual review rather than a pixel diff.

Recorded replay passed: `.argent/e2e/onboarding-scrawl-formats.yaml` (12 executed steps, 0 failures).

Replay command:

```sh
argent e2e run onboarding-scrawl-formats --platform ios --device F514640E-1994-48D1-ADD2-B778CB9F83D4
```

The preview filename and photo title checks retain raw accessibility waits because these SwiftUI texts are absent from Argent's native runner tree. The Next button uses a documented coordinate at (0.5975, 0.912), specific to 402×874 portrait geometry: both `onboarding-next` and `Next` failed against the native runner tree, while accessibility discovery exposed the button. The following photo title check proves navigation. Apple account and notification prompts were dismissed during initial simulator setup. No tracking or photo permissions were granted.
