# Backup guide: native disk import and re-export

October 26, 2026. This advances the earlier parser-only evidence and corrects
its expected two-saved-visit result. The complete file-picker/physical transfer
and app-process restart gates remain open.

## Setup and execution

Used the existing isolated Debug rebuild of released 1.7.16 (46), source
`6ae78e622c72ee051e6f14113082556c398d926a`, with separate bundle/app-group
identity in `/private/tmp/isome-seo-restore-release-08_3e_ws`.
Argent list-devices confirmed the already booted `iso-me-country-days-QA`
(`5AC67EDC-DE2E-4EE7-AD57-DCBA324C8C6B`, iOS 26.5). No physical device was
selected. The existing environment/release mapping was reused.

[Evidence test](BackupDiskImportEvidence.swift) was appended only to the
existing SavedPlaceManagementTests file in the temporary release-source copy.
No native production repository code or submitted binary changed. The test
uses the documentation JSON records (same content, without the final newline),
actual LocationViewModel.importData, actual ImportService/models, a new on-disk
SwiftData container, and actual ExportService.render. No parser, persistence,
URL-security access, reconciliation, or serializer stubs were introduced.

Tracking is disabled; network geocoding is disabled and its preference restored.
The unique test directory/store/files are deleted at the end. No personal
journal files or routes are read. Model containers are scoped in autorelease
pools and the store is opened again through a new ModelContainer. This is not
a separate-process restart or a file-picker test.

```sh
xcodebuild test -project /private/tmp/isome-seo-restore-release-08_3e_ws/IsoMe.xcodeproj \
  -scheme IsoMe -configuration Debug \
  -destination 'platform=iOS Simulator,id=5AC67EDC-DE2E-4EE7-AD57-DCBA324C8C6B' \
  -derivedDataPath /private/tmp/isome-seo-restore-derived \
  -parallel-testing-enabled NO \
  -only-testing:IsoMeTests/SavedPlaceManagementTests \
  -only-testing:IsoMeTests/ExportRoundTripTests \
  -only-testing:IsoMeTests/ExportServiceRoundTripTests
```

**22 tests passed, zero failures.** The initial single-test attempt expected two
saved visits and failed five assertions. Investigating that mismatch established
the actual reconciliation behavior; no production code was changed to make the
test pass. The confirmation asserts the observed behavior and re-export result.
Logs: `/private/tmp/isome-seo-backup-disk.log` (initial expectation) and
`/private/tmp/isome-seo-backup-disk-confirmed.log` (confirmed suite).

## Findings

- Original fixtures parse two visits and three points. The import method
  reports two visits and three points added.
- After opening the disk store in a fresh container, one visit remains:
  Synthetic stop A, coordinates 0/0, arrival January 1, 2000 11:45 UTC,
  departure 12:17 UTC, and the fixture note. All three points remain with
  checked timestamps, coordinates, accuracy, and outlier flag.
- Native JSON re-export and reparsing contains one visit and three points.
- Importing the original files again reports two visits and three points,
  but the reopened store contains one visit and six points.

The released import method saves inserted records, then invokes
LocationManager.reconcileOpenVisits. That method merges nearby visits, including
closed imported visits. The fixture stops are within 100 m and only two minutes
apart, satisfying its 30-minute gap rule. The earlier visit retains its name
and coordinates; the departure is extended. This is not the newer preview and
archive duplicate detection available in development source. Point import
still appends repeated records.

## Website correction

The backup guide now presents original/imported/saved/re-exported/repeated counts
in a stage table and preserves the unchanged synthetic files. Removed the
incorrect expectation that the empty journal will retain two separate visits.
The export and troubleshooting references describe reconciliation separately
from duplicate-safe import and link to the checked result. Visit export advice
now identifies its actual arrival/completion/duration filters; accuracy and
outlier checks are described under Points.

Static build passes 31 HTML pages, 30 Markdown pages, 1,063 local targets,
metadata, JSON-LD, IDs, sitemap coverage, and `git diff --check`.

No search results, new indexation, file-picker success, complete phone restore,
app-process restart, purchase flow, or cloud handoff is claimed.
