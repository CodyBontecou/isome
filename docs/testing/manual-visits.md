# Manual visit completion — issue #57

Implemented against main `6ae78e6` on October 25, 2026. These changes are local and have not been merged or released.

## Behavior

- Open manual visits offer Check Out in the map quick sheet and Visit Details. Check-out records the current time, preserves source/confirmation/correction metadata, and refreshes the visit lists, map, and watch summary.
- Creation and time editing of manual visits detect overlapping stored visits, including automatic detections. The warning names the conflicting place; Cancel preserves the form and existing records, while Save Anyway explicitly keeps both visits.
- Adjacent visits can share a departure/arrival boundary. Open visits overlap later intervals until closed. Editing excludes the visit itself.
- Automatic arrival/departure matching, stale-open-visit cleanup, and duplicate merging leave manual records intact.
- Persistence failures return an error without reporting a successful save. Invalid or repeated check-out leaves the stored departure unchanged.
- New controls, hints, and error messages are present in all 11 supported catalog locales.

## Verification

Focused suite: 31 tests passed. Full suite: XCTest reported 306 tests passed, zero failures. The full-run xcodebuild process lingered after the suite completed and was interrupted during runner teardown; no successful command exit is claimed.

```sh
xcodebuild test -project IsoMe.xcodeproj -scheme IsoMe \
  -destination 'platform=iOS Simulator,id=BF9F9B4E-43B7-4888-BC70-31CA40ADA914' \
  -derivedDataPath /private/tmp/isome-manual-visit-derived
```

Use normal simulator signing for Keychain tests. Deny location permission for the test host so real simulated location updates do not contaminate deterministic point-count tests. An initial unsigned run with location granted failed for those environment reasons; the corrected full run passed.

Simulator walkthrough on iOS 26.5:

1. Open Map, Add place, Add place manually; enter a name and save an open visit.
2. Confirm an overlapping seeded automatic visit produces the warning and Save Anyway preserves both records.
3. Open the manual visit from Timeline and choose Check Out in Visit Details.
4. Confirm Still here turns off, Departed shows the current time, and Check Out disappears.

The live walkthrough passed by accessibility inspection and screenshots. The attempted Argent recording captured incorrect selectors/typing and was retained only as a temporary diagnostic; it is not a passing automated UI regression test. Automated coverage for mutation, persistence, overlap boundaries, overrides, and reconciliation is in `LocationViewModelPointScalingTests.swift`.

## Remaining epic scope

Watch commands and Check In / Check Out App Intents/deep links are separate follow-ups. Migration smoke testing, comprehensive place-search/offline policy validation, and metadata coverage across every export format still need explicit verification before closing the entire epic. No schema changes are introduced by this patch.
