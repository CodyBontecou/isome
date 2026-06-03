# Epic: Google Timeline / Google Takeout import

**Source:** Reddit feedback asking whether Google Timeline history can be imported  
**Difficulty:** Medium-Hard  
**Primary user need:** “I want to migrate my old Google Timeline history into iso.me.”

## Goal

Add an offline, local-only import pipeline for Google Timeline / Google Takeout location history.

The feature should support:

- Google raw Location History points.
- Google Semantic Location History visits.
- Newer Google Maps on-device Timeline exports where feasible.
- Preview before saving.
- Duplicate detection.
- Optional conservative visit inference from raw points.
- Unzipped Takeout folder/multi-file imports before considering ZIP support.

## Non-goals

- No Google OAuth.
- No Google APIs.
- No server upload.
- No automatic network geocoding during import.
- No direct Takeout ZIP support in MVP unless dependency/implementation trade-off is explicitly approved.

## Current touchpoints

- `IsoMe/Views/SettingsView.swift` — current file importer immediately imports one selected file.
- `IsoMe/ViewModels/LocationViewModel.swift` — `importData(from:)` reads entire file, parses, inserts everything, no preview/dedupe/progress.
- `IsoMe/Utilities/ImportService.swift` — supports iso.me JSON/CSV/Markdown; JSON detection is binary and currently ignores `points` if root contains `visits`.
- `IsoMe/Models/Visit.swift` and `IsoMe/Models/LocationPoint.swift` — no import source/external IDs; avoid schema migration for MVP if possible.

## Google formats to support

### Phase 1

1. Classic raw Location History:
   - Root: `{ "locations": [...] }`
   - Fields: `latitudeE7`, `longitudeE7`, `timestampMs` or `timestamp`, `accuracy`, optional altitude/velocity/activity.
   - Import as `LocationPoint`; optionally infer visits.

2. Semantic Location History:
   - Root: `{ "timelineObjects": [...] }`
   - Objects: `placeVisit`, `activitySegment`.
   - Import `placeVisit` as `Visit`; import path points where timestamps are available.

3. Newer device Timeline exports:
   - Root often includes `semanticSegments`.
   - Parse `visit`, `activity`, and `timelinePath` entries with `geo:lat,lng`.

### Later

- Multiple JSON files.
- Unzipped Takeout folder recursion.
- ZIP import decision.
- Legacy KML only if real demand appears.

## Proposed architecture

Add import-specific types instead of overloading `ExportFormat`:

- `ImportSourceFormat`
- `ImportOptions`
- `ImportPreview`
- `ImportCommitResult`

Recommended files:

- `IsoMe/Utilities/GoogleTimelineImportService.swift`
- `IsoMe/Utilities/ImportNormalizer.swift`
- `IsoMe/Utilities/VisitInferenceService.swift`

Keep existing iso.me import behavior but refactor detection to support combined outputs and Google formats.

## Parsing strategy

Normalize into existing imported structs:

- `ImportedVisit`
- `ImportedLocationPoint`

Support:

- E7 coordinate conversion.
- `geo:lat,lng` parsing.
- ISO timestamps.
- millisecond epoch timestamps.
- semantic start/end durations.
- timeline path offsets.

Accuracy/outlier handling:

- Preserve `accuracy` as `horizontalAccuracy`.
- Use existing implied-speed heuristic around 40 m/s for teleport outliers.
- Let users set maximum accepted accuracy.
- Use poor-accuracy points for route import only if user opts in; avoid them for visit inference.

## Visit inference from raw points

Make inference optional, default-on for raw-only imports.

Conservative algorithm:

1. Sort valid points by timestamp.
2. Split sessions by long timestamp gaps or impossible jumps.
3. Find dwell clusters with radius ~100–150m and minimum dwell ~10–20 minutes.
4. Weight centroid by inverse accuracy where available.
5. Merge adjacent clusters within radius and short gap.
6. Discard movement-only or low-confidence clusters.
7. If semantic visits exist for the same date range, do not infer duplicates by default.

## Duplicate handling

MVP should avoid schema migration and use heuristics:

- Point duplicates: timestamp rounded to 1s + coordinate rounded/distance <= ~10m.
- Visit duplicates: arrival within ~60s, departure within ~5m, coordinate distance <= ~100m.
- Existing database duplicate check should fetch only relevant import date ranges.
- Show skipped duplicate counts in completion summary.

Future stronger option:

- Add `importSource`, `externalIdentifier`, `importBatchID` to models.
- Support undo import batch.

## UX flow

Replace immediate import with preview/confirm:

1. User taps Import.
2. Select iso.me backup or Google Timeline/Takeout, or auto-detect.
3. Pick one JSON, multiple JSON files, or unzipped folder.
4. App scans/parses preview locally.
5. Show detected format, date range, visit count, point count, inferred visits, duplicate estimate, warnings.
6. Options: import visits, import points, infer visits, skip duplicates, accuracy threshold.
7. Confirm.
8. Show progress: scanning, parsing, deduping, saving.
9. Show completion summary.

Privacy copy:

> Google Timeline files are processed locally on this device. iso.me does not sign into Google, upload your history, or use a server. Location names are only imported when they already exist in your export.

## Implementation checklist

### Phase 0 — Import architecture cleanup

- [ ] Refactor `ImportService` around import-specific format detection.
- [ ] Fix combined iso.me JSON import so files with both `visits` and `points` import both.
- [ ] Preserve existing JSON/CSV/Markdown behavior.
- [ ] Improve unsupported-format copy for KML/GPX/GeoJSON.
- [ ] Add regression tests for combined JSON.
- [ ] Acceptance: existing export/import tests pass and combined JSON imports visits + points.

### Phase 1 — Google parser MVP

- [ ] Add `GoogleTimelineImportService`.
- [ ] Detect raw `locations` root.
- [ ] Detect semantic `timelineObjects` root.
- [ ] Detect device `semanticSegments` root.
- [ ] Parse E7 coordinates.
- [ ] Parse `geo:` coordinates.
- [ ] Parse Google timestamp variants.
- [ ] Normalize raw points to `ImportedLocationPoint`.
- [ ] Normalize semantic/device visits to `ImportedVisit`.
- [ ] Add inline fixture tests.
- [ ] Acceptance: standalone Google JSON files produce expected normalized visits/points without persistence.

### Phase 2 — Visit inference

- [ ] Add `VisitInferenceService`.
- [ ] Implement dwell clustering with configurable radius/min dwell/accuracy threshold.
- [ ] Avoid inference when semantic visits cover the same date range by default.
- [ ] Add tests for stationary, moving, sparse, merged, and teleport/outlier cases.
- [ ] Acceptance: raw Google points can produce conservative deterministic visits.

### Phase 3 — Duplicate handling and persistence

- [ ] Add import preview and commit methods to `LocationViewModel`.
- [ ] Deduplicate within imported payload.
- [ ] Deduplicate against existing SwiftData rows by date range.
- [ ] Insert in batches.
- [ ] Refresh caches and sync watch/widget state after import.
- [ ] Add repeated-import tests using in-memory SwiftData.
- [ ] Acceptance: importing the same Google file twice skips duplicates and reports skipped counts.

### Phase 4 — Import review UX

- [ ] Replace immediate import in `SettingsView` with async preview/confirm flow.
- [ ] Add `ImportPreviewView`.
- [ ] Add toggles for visits, points, inferred visits, duplicate skipping, and accuracy threshold.
- [ ] Add progress state and completion summary.
- [ ] Update file/folder picker types.
- [ ] Remove or clarify KML from picker until KML import is supported.
- [ ] Acceptance: user sees Google import counts before saving anything.

### Phase 5 — Folder and multi-file support

- [ ] Allow multiple JSON selection.
- [ ] Allow folder selection for unzipped Takeout.
- [ ] Recursively discover supported Google Timeline JSON paths.
- [ ] Ignore unrelated Takeout files.
- [ ] Combine semantic visits and raw points intelligently.
- [ ] Avoid duplicating points between raw and semantic path sources.
- [ ] Add multi-file aggregation tests.
- [ ] Acceptance: unzipped Takeout folder imports with one user confirmation.

### Phase 6 — ZIP decision

- [ ] Open a dedicated decision issue for ZIP support.
- [ ] Option A: document unzip-in-Files workflow.
- [ ] Option B: add a vetted ZIP dependency.
- [ ] Option C: implement minimal local ZIP JSON reader.
- [ ] Acceptance: either direct ZIP import works offline or UI clearly instructs users to unzip first.

### Phase 7 — Docs and polish

- [ ] Update README with Google import instructions.
- [ ] Document supported/unsupported Google formats.
- [ ] Add troubleshooting for huge files, unknown formats, no inferred visits, duplicates.
- [ ] Add privacy/offline statement.

## Risks

- Google schemas change frequently.
- Raw history files can be huge.
- ZIP support conflicts with no-dependency posture.
- Visit inference quality will not perfectly match Google.
- Duplicate handling is heuristic without external IDs.
- Current import UI is synchronous and must be made async/progressive.
