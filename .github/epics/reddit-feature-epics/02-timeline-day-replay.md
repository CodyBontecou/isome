# Epic: Timeline / day replay view

**Source:** Reddit feedback comparing iso.me to Google Timeline and Moves  
**Difficulty:** Medium  
**Primary user need:** “I want a private Google Timeline/Moves-style day view so I can replay where I went.”

## Goal

Build a dedicated Timeline tab that turns existing on-device visits and GPS points into a day-by-day replay experience.

The feature should include:

- Date navigation.
- Daily summary cards.
- Visit + movement event list.
- Map overview of the day.
- Scrubbable replay/playback.
- Optional “Export Day” that uses the existing paid export gate.

Viewing timeline history should be free. Exporting timeline data should follow the current export purchase model.

## Current touchpoints

- `IsoMe/Models/Visit.swift` — stays/visits; day logic must include visits overlapping a day, not only `arrivedAt` within a day.
- `IsoMe/Models/LocationPoint.swift` — route points and distance helpers.
- `IsoMe/ViewModels/LocationViewModel.swift` — existing map point downsampling/lazy loading; Timeline must not hydrate full history.
- `IsoMe/Views/MapView.swift` — existing MapKit route/visit visualization patterns, but already large.
- `IsoMe/Views/ContentView.swift` — currently Map, Export, Settings tabs.
- `IsoMe/Utilities/ExportService.swift` — reuse for Export Day.
- `IsoMe/Utilities/ImportService.swift` — combined JSON import currently needs hardening if imported history should replay correctly.

## Recommended UX

Add a new tab:

1. Map
2. Timeline
3. Export
4. Settings

Timeline screen sections:

- Header: Today/date, previous/next day, date picker.
- Summary: visit count, distance, point count, movement duration, hidden outlier count if relevant.
- Replay map: full route faintly, elapsed route strongly, cursor marker, visit markers, gap indicators.
- Scrubber: play/pause, speed controls, next/previous event, follow cursor toggle.
- Event list: visit cards, movement cards, gap cards.

## Data/query model

Add non-persistent domain models, likely `IsoMe/Models/DayReplay.swift`:

- `DayReplayData`
- `DayReplaySummary`
- `DayReplaySegment`
- `DayReplayEvent`
- `ReplayCursor`

Day range semantics:

- Points: `timestamp >= dayStart && timestamp < dayEnd`
- Visits: `arrivedAt < dayEnd && (departedAt == nil || departedAt >= dayStart)`

Performance rules:

- Never load all `LocationPoint` history to render one day.
- Reuse/extract existing downsampling logic.
- Split route segments on large gaps, e.g. 10+ minutes.
- Keep first/last points.
- Cap display points similarly to current map limits.
- Avoid rebuilding huge route prefixes on every scrubber tick.

## Implementation checklist

### Phase 1 — Data model and query layer

- [ ] Add `DayReplayData`, `DayReplaySummary`, `DayReplaySegment`, `DayReplayEvent`, and `ReplayCursor` pure Swift models.
- [ ] Extract reusable point downsampling into `LocationPointSampler`.
- [ ] Add `DayReplayViewModel` that fetches only selected-day visits/points.
- [ ] Implement overlapping visit queries.
- [ ] Implement segment builder that splits route points on timestamp gaps.
- [ ] Compute distance, duration, average speed, point count, and gaps.
- [ ] Acceptance: loading Timeline does not populate full `LocationViewModel.locationPoints`.

### Phase 2 — Static Timeline UI

- [ ] Add Timeline tab in `ContentView`.
- [ ] Update debug launch tab range from `0...2` to `0...3`.
- [ ] Create `DayReplayView` with date navigation, summary cards, and empty state.
- [ ] Create vertical event list cards for visits, movement, and gaps.
- [ ] Use existing TE design tokens.
- [ ] Acceptance: users can switch dates and see counts/events without playback.

### Phase 3 — Map overview

- [ ] Add `DayReplayMapView`.
- [ ] Render full-day route segmented by gaps.
- [ ] Render visit markers.
- [ ] Fit map to selected day’s content.
- [ ] Handle days with only visits, only points, both, or no data.
- [ ] Extract/reuse coordinate-region helpers currently duplicated in map views.
- [ ] Acceptance: map remains performant on large days.

### Phase 4 — Scrubber and playback

- [ ] Add current replay time state.
- [ ] Add slider from first event to last event, with day-bound clamping.
- [ ] Add nearest-point lookup, ideally binary search.
- [ ] Render elapsed route separately from full route.
- [ ] Add cursor marker.
- [ ] Add play/pause and speed controls.
- [ ] Respect Reduce Motion.
- [ ] Acceptance: scrubber reveals route progressively and playback stops/loops predictably.

### Phase 5 — Export/import interactions

- [ ] Add “Export Day” action backed by `ExportService`.
- [ ] Gate export action with `StoreManager`/paywall; viewing remains free.
- [ ] Avoid full-history point loading for Export Day.
- [ ] Fix combined iso.me JSON import so files containing both `visits` and `points` import both.
- [ ] Consider duplicate detection for repeated imports.
- [ ] Acceptance: selected-day export works for purchased users; imported combined JSON appears in Timeline.

### Phase 6 — Performance and QA

- [ ] Add tests for visits crossing midnight.
- [ ] Add tests for segment splitting and distance computation.
- [ ] Add tests for cursor lookup/interpolation.
- [ ] Add large-day tests with 12,500+ points.
- [ ] Add accessibility labels for map/cards/controls.
- [ ] QA empty store, visits-only day, points-only day, active tracking today, cross-midnight visit, outliers hidden/shown, and large history.

### Phase 7 — Docs/localization

- [ ] Add localizable strings.
- [ ] Update README with Timeline/day replay description and limitations.
- [ ] Note that route detail depends on tracking being enabled and available data.

## Risks

- SwiftUI MapKit can lag if overlays are recomputed too frequently.
- Very large stores require careful point sampling.
- Users may expect Google-level detail even when iso.me was not actively tracking routes.
- CLVisit data and GPS route data may disagree.
- Cross-midnight visits and DST changes need explicit test coverage.
