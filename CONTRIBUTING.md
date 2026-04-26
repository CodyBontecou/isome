# Contributing to iso.me

Thanks for your interest in contributing! iso.me is open source under the [AGPL-3.0](LICENSE), and we welcome bug reports, feature ideas, design feedback, and pull requests.

## Ways to contribute

- **Pick up a [good first issue](https://github.com/CodyBontecou/isome/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)** — these are scoped and labelled to be approachable.
- **File a bug** — open an issue with reproduction steps, iOS version, and device.
- **Propose a feature** — start a thread in [GitHub Discussions](https://github.com/CodyBontecou/isome/discussions) before opening a large PR, so we can align on scope.
- **Improve docs** — typo fixes and clearer explanations are always appreciated.

## Development setup

### Prerequisites

- macOS with **Xcode 15 or later**
- Apple Developer account (free tier is fine for local builds; paid for device installs)
- A physical iPhone for location features (the simulator can fake fixed coordinates but does not produce realistic visit detection or motion activity)

### Clone and open

```bash
git clone https://github.com/CodyBontecou/isome.git iso.me
cd iso.me
open IsoMe.xcodeproj
```

### Configure signing

There are four targets — set the Team and Bundle Identifier on each:

| Target | Default Bundle ID | Notes |
|---|---|---|
| `IsoMe` | `com.bontecou.isome` | Main iOS app |
| `IsoMeWidgetExtension` | `com.bontecou.isome.Widget` | Live Activities + widgets |
| `IsoMeWatch` | `com.bontecou.isome.watchkitapp` | watchOS companion |
| `IsoMeWatchWidgetExtension` | `com.bontecou.isome.watchkitapp.Widget` | watchOS complications |

For local development, change the bundle ID prefix to your own (e.g. `com.yourname.isome`) on all four targets so signing doesn't conflict with the published build.

### App Group entitlement

The app, widget, and watch app share data via an App Group. Update the App Group identifier on each target's **Signing & Capabilities** tab to match your team prefix (e.g. `group.com.yourname.isome`). The corresponding string is read from `Shared/AppGroup.swift` — search for `group.com.bontecou.isome` and replace as needed.

### Optional: Gripe analytics key

The repo uses [Gripe](https://gripe.dev) for anonymous crash reporting. The real key is gitignored. To build without it:

```bash
cp Config/Gripe.xcconfig.example Config/Gripe.xcconfig
# Leave GRIPE_API_KEY = REPLACE_WITH_GRIPE_API_KEY
```

The build will succeed and crash reports will be no-ops.

### Build & run

1. Select the **IsoMe** scheme.
2. Choose your physical device.
3. ⌘R to build and run.
4. On first launch the app requests **Location (Always)** and **Motion & Fitness** permissions — both are required to exercise visit detection and auto-start.

## Testing on TestFlight

If you have a paid Apple Developer account and want to dogfood your fork via TestFlight:

```bash
# Archive
xcodebuild -project IsoMe.xcodeproj \
  -scheme IsoMe \
  -configuration Release \
  -archivePath build/IsoMe.xcarchive \
  archive

# Export signed IPA
xcodebuild -exportArchive \
  -archivePath build/IsoMe.xcarchive \
  -exportPath build/ipa \
  -exportOptionsPlist exportOptions.plist
```

Then upload the IPA to App Store Connect via Transporter.app or `xcrun altool`.

## Code style

- **SwiftUI-first** — prefer SwiftUI over UIKit unless a feature genuinely requires it.
- **No external dependencies** — the project deliberately uses only Apple frameworks. Adding a Swift Package needs a strong justification and discussion first.
- **Privacy by default** — no analytics, no telemetry, no network calls that ship user data off-device. Crash reporting is the single exception (Gripe), and it is anonymous and opt-in.
- **Match existing patterns** — read the surrounding files before adding a new model, service, or view.

## Pull request workflow

1. Fork the repo and create a feature branch off `main`.
2. Keep PRs focused — one logical change per PR.
3. Include before/after screenshots for any UI change.
4. Run the app on a physical device and confirm tracking still works end-to-end.
5. Open the PR with a description that explains *why*, not just *what*.

## Code of conduct

Be kind. Assume good faith. Disagree with ideas, not people. If something feels off, email codybontecou@gmail.com.

## License

By contributing to iso.me you agree that your contribution will be licensed under the [AGPL-3.0](LICENSE).
