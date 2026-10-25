# Google Timeline import MVP QA

Validated on 2026-10-25 with the iOS 26.5 simulator (`iso-me-crash-repro-20261025`).

## Automated coverage

`TimelineImportTests` covers classic raw Location History, legacy Semantic Timeline, device Timeline (object and iOS array), E7/geo/degree coordinates, ISO/millisecond/offset timestamps, invalid records, unsupported files, file size limits, combined iso.me backups, cancellation, selection, read-only preview, duplicate tolerances, stale previews, and repeated imports. Existing visits retain their names and confirmation state. Imports do not request geocoding.

Run the full suite with `xcodebuild test -project IsoMe.xcodeproj -scheme IsoMe -destination 'platform=iOS Simulator,id=<simulator-id>' -parallel-testing-enabled NO`. Use a signed simulator build and deny location permission to keep live tracking out of persistence tests.

## Manual UI acceptance

Fixture: `IsoMeTests/Fixtures/google-timeline-preview.json` (synthetic coordinates and dates).

1. Save the fixture in Files. Open Settings > Data Import > Import File and select it.
2. Preview identifies Google Device Timeline and shows 1 new visit, 2 new points, 1 duplicate visit, 2 duplicate points, and 1 invalid entry. Nothing is saved yet.
3. Confirm. Completion reports 1 visit and 2 points imported. Settings totals increase by exactly those amounts (6/111 to 7/113 during this run).
4. Select the same file again. Preview shows 0 new visits/points and 2/4 duplicates. Confirmation is disabled.

Observed all expected results. The system file picker did not expose a reliable accessibility tree through Argent; it was checked visually. A draft recorder was discarded instead of keeping brittle selectors. Automated UI replay is not claimed.

## MVP boundaries

Single JSON files only for Google exports; unzip Takeout manually. No folder/ZIP import or inferred visits from raw points. The parser accepts up to 50 MiB and 250,000 visits plus points. Duplicate thresholds and privacy behavior are documented in the README. New interface copy currently uses English fallback in other locales.
