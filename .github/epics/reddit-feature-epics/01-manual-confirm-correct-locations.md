# Epic: Manual confirm/correct locations

**Source:** Reddit feedback from r/iOS launch thread  
**Difficulty:** Medium for iOS MVP; Hard if expanded to watch check-in + full place search workflows  
**Primary user need:** “I visited a spot downtown, but I want to confirm I ate at the restaurant and did not spend two hours at the bookstore next door.”

## Goal

Let users fix ambiguous automatic visits and manually log places while preserving iso.me’s privacy-first, on-device model.

This includes:

- Confirming an automatically detected visit is correct.
- Correcting a visit to a nearby place candidate.
- Editing arrival/departure times.
- Manually checking in now.
- Logging a past visit.
- Preserving original automatic detection metadata for audit/undo/export.

## Non-goals

- No social/check-in feed.
- No accounts or cloud place database.
- No background POI lookup for every visit.
- No third-party place SDK.
- Watch check-in is a later phase, not the iOS MVP.

## Current touchpoints

- `IsoMe/Models/Visit.swift` — effective visit coordinate/name/address/notes only; no source/status/original-place metadata.
- `IsoMe/Services/LocationManager.swift` — creates/updates `Visit` from `CLVisit`; currently matches departure updates by exact latitude/longitude, which can break if a user corrects an open visit.
- `IsoMe/ViewModels/LocationViewModel.swift` — has delete/update-notes, but no confirm/correct/manual-create APIs.
- `IsoMe/Views/MapView.swift` — visit markers and quick sheet; best check-in/log entry point.
- `IsoMe/Views/VisitDetailView.swift` — current read-only place/time UI plus notes/delete.
- `IsoMe/Utilities/ExportService.swift` and `IsoMe/Utilities/ImportService.swift` — need lossless metadata round-trips if corrected/manual visits are exportable.
- `IsoMe/Views/SettingsView.swift` — existing `allowNetworkGeocoding` setting must gate Apple Maps/CLGeocoder lookups.

## Data model scope

Keep existing `Visit.latitude`, `Visit.longitude`, `Visit.locationName`, and `Visit.address` as the user-facing effective values.

Add optional/defaulted metadata fields to `Visit`:

- `sourceRaw`: `automatic`, `manual`, `imported`
- `confirmationStatusRaw`: `unconfirmed`, `confirmed`, `corrected`
- `confirmedAt`, `updatedAt`
- `originalLatitude`, `originalLongitude`, `originalLocationName`, `originalAddress`
- `detectedLatitude`, `detectedLongitude`, `detectedLocationName`, `detectedAddress`
- `placeSourceRaw`: `coreLocationGeocode`, `appleMaps`, `userEntered`, `import`
- `placeCategoryRaw`, `placeDistanceMeters`, `placeConfidence`
- Optional accuracy metadata if useful for ranking/debugging

Default behavior:

- Existing rows: `source = automatic`, `confirmationStatus = unconfirmed`.
- New automatic visits: set `detected*` fields from Core Location.
- Confirm: keep effective fields, set status + timestamp.
- Correct: copy current effective fields to original fields once, update effective fields, mark corrected, prevent geocode overwrite.
- Manual: create confirmed manual visit with user-selected place/time.

## Place search and privacy

Add a MapKit-backed `PlaceSearchService`:

- Nearby POIs around the visit/current coordinate.
- Text search for “restaurant”, “bookstore”, etc.
- Candidate ranking by distance, name match, category, and query.
- In-memory cache only.

Privacy rules:

- If `allowNetworkGeocoding == false`, do not call `CLGeocoder`, `MKLocalSearch`, or nearby POI APIs.
- Offline/manual fallback: “Use custom name at this coordinate.”
- Do not store unused candidate lists.
- Explain that Apple Maps search may send approximate coordinates/query to Apple.

## Implementation checklist

### Phase 1 — Visit metadata and migration foundation

- [ ] Add optional source/status/original/detected/place metadata fields to `Visit`.
- [ ] Add computed enums/properties for source and confirmation status.
- [ ] Update previews/test fixtures.
- [ ] Add migration smoke tests for existing stores.
- [ ] Acceptance: existing visits load as automatic/unconfirmed; current tests still pass.

### Phase 2 — Mutation APIs

- [ ] Add `confirmVisit(_:)` to `LocationViewModel`.
- [ ] Add `correctVisit(_:with:)` preserving original fields.
- [ ] Add `undoVisitCorrection(_:)`.
- [ ] Add `createManualVisit(from:)`.
- [ ] Add `updateVisitTimes(_:arrivedAt:departedAt:)`.
- [ ] Add `checkoutVisit(_:at:)` for open manual visits.
- [ ] Add duplicate detection for overlapping manual logs.
- [ ] Acceptance: unit tests cover confirm/correct/undo/manual log/time validation.

### Phase 3 — LocationManager correctness

- [ ] Set visit metadata when creating automatic `CLVisit` rows.
- [ ] Match departure updates against detected/original coordinates with tolerance, not only effective coordinates.
- [ ] Guard reverse-geocode writes so corrected/manual/confirmed visits are not overwritten.
- [ ] Add one-shot current location support for manual check-in without starting route tracking.
- [ ] Acceptance: correcting an open visit does not prevent later departure update.

### Phase 4 — Place search and ranking

- [ ] Add `PlaceCandidate` model and `PlaceSearching` protocol.
- [ ] Add MapKit-backed implementation.
- [ ] Add fake implementation for tests.
- [ ] Rank candidates by distance/query/category.
- [ ] Respect `allowNetworkGeocoding`.
- [ ] Acceptance: deterministic candidate ranking tests pass; offline mode never performs network-backed search.

### Phase 5 — Visit detail UI

- [ ] Add status/source badges to `VisitDetailView`.
- [ ] Add “Confirm Place”.
- [ ] Add “Correct Place” with candidate/search sheet.
- [ ] Add “Undo Correction”.
- [ ] Add editable arrival/departure times.
- [ ] Update accessibility labels.
- [ ] Acceptance: user can correct restaurant-vs-bookstore ambiguity from visit detail.

### Phase 6 — Map entry points

- [ ] Add quick-sheet actions: Confirm, Correct, Details.
- [ ] Add map-level “Check In” / “Log Past Visit” entry point.
- [ ] Add open manual visit “Check Out” state.
- [ ] Add distinct marker states for unconfirmed/confirmed/corrected/manual.
- [ ] Acceptance: manual check-in/out and past logging work from the Map tab.

### Phase 7 — Export/import metadata

- [ ] Extend visit export schemas with correction/manual metadata where appropriate.
- [ ] Extend import parsing with optional metadata fields.
- [ ] Update JSON/CSV/Markdown/GeoJSON/GPX/KML tests.
- [ ] Keep OwnTracks/Overland points-only.
- [ ] Acceptance: corrected/manual metadata round-trips; legacy imports still work.

### Phase 8 — Shortcuts/deep links

- [ ] Add optional Check In / Check Out App Intents.
- [ ] Consider `isome://checkin`, `isome://log`, and `isome://visit/<id>` deep links.
- [ ] Acceptance: Shortcuts can start check-in/out flows when enough location context exists.

### Phase 9 — Watch later

- [ ] Add read-only shared status fields for current visit/manual state.
- [ ] Later add WatchConnectivity commands for watch check-in/check-out.
- [ ] Acceptance: watch status stays backward-compatible; command support queues reliably when phone unreachable.

### Phase 10 — Docs/localization/polish

- [ ] Add strings to `Localizable.xcstrings`.
- [ ] Update README with manual correction/check-in and Apple Maps lookup privacy note.
- [ ] Add QA notes for offline/no-network geocoding mode.

## Risks

- Correcting coordinates can break open visit departure matching unless fixed first.
- Async reverse geocoding can overwrite corrections unless guarded.
- MapKit candidate quality may still be ambiguous.
- Export schema drift can break downstream consumers.
- Watch check-in requires a new communication layer and should not block MVP.
