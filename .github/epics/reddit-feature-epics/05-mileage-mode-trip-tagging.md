# Epic: Mileage Mode — business/personal trip tagging and IRS-style exports

**Source:** Reddit request asking whether iso.me can replace MileIQ for business mileage  
**Difficulty:** XL  
**Primary user need:** “I want locally owned business mileage tracking with clean reports, without a $90/year subscription.”

## Goal

Add a privacy-first Mileage Mode for drive trips:

- Record or detect drive trips.
- Classify trips as business or personal.
- Support one or more vehicles.
- Capture business purpose/notes.
- Export IRS-style mileage reports.
- Keep data on-device.

User-facing copy should call this “Mileage Mode” or “Drive Mileage,” not “MileIQ replacement.” Avoid “IRS compliant” claims.

## Non-goals / guardrails

- Do not provide tax/legal/accounting advice.
- Do not claim compliance.
- Do not use MileIQ branding in app UI.
- Do not silently classify trips as deductible.
- Drive auto-detection depends on the Smart Auto-Start / activity detection epic and should be staged after manual trip workflows.

Required disclaimer:

> Mileage estimates are generated from GPS data and may differ from your vehicle odometer. Classifications, rates, and deduction estimates are for recordkeeping only and are not tax, legal, or accounting advice. Review every trip and consult a qualified tax professional. Tax rules and mileage rates can change.

## Current touchpoints

- `IsoMe/Models/Visit.swift` and `IsoMe/Models/LocationPoint.swift` — only current SwiftData models.
- `IsoMe/Services/LocationManager.swift` — active tracking has runtime session state but no persisted trip model.
- `IsoMe/Utilities/ExportService.swift` — existing location export architecture; mileage reports should be separate but consistent with paid export gating.
- `IsoMe/Services/StoreManager.swift` and `IsoMe/Views/ExportView.swift` — export is currently the paid feature.
- `IsoMe/Views/ContentView.swift` — main tab structure.
- `IsoMe/Info.plist` — no Motion usage string yet; drive-only depends on future CoreMotion work.

## Proposed data model

Add SwiftData models:

- `IsoMe/Models/Trip.swift`
- `IsoMe/Models/Vehicle.swift`
- Optional later: `VehicleOdometerReading.swift`

### Trip fields

- `id`
- `startedAt`, `endedAt`
- `timezoneIdentifier`
- start/end coordinates
- start/end names and addresses
- `distanceMeters`, `rawDistanceMeters`, `manualDistanceMeters`
- `pointCount`
- `classificationRaw`: unclassified, business, personal, later commute/medical/charity/etc.
- `reviewStatusRaw`: needsReview, reviewed, autoClassified
- `businessPurpose`
- `notes`
- `vehicleID`
- `vehicleNameSnapshot`
- `sourceRaw`: manualSession, autoDrive, historicalBackfill, imported
- `classifiedAt`, `createdAt`, `updatedAt`
- optional odometer fields
- `excludeFromReports`

### Vehicle fields

- `id`
- `name`
- make/model/year optional
- license plate last 4 optional
- `isDefault`
- `isArchived`
- notes
- timestamps

### LocationPoint additive field

- `tripID: UUID? = nil`

Avoid SwiftData relationships to thousands of points; use scalar IDs and summary fields to preserve point-scaling performance.

## Architecture

Add:

- `TripRecorder.swift` — manages active trip lifecycle, persists active trip ID, assigns `tripID` to points, finalizes distance/points/origin/destination.
- `MileageDistanceCalculator.swift` — pure utility for raw/filtered distance, outlier/accuracy/speed/gap handling.
- `MileageReportOptions.swift`
- `MileageReportService.swift`
- `MileageRateProvider.swift`

Drive-only auto detection should come later:

- `DriveDetectionManager.swift` using CoreMotion + speed/location heuristics.
- Requires `NSMotionUsageDescription` and real-device QA.
- Depends on Smart Auto-Start architecture for reliable background behavior.

## UX scope

Add a Mileage tab:

- Current year business miles.
- Estimated deduction.
- Unclassified trip count.
- Vehicle filter.
- Review Trips inbox.
- Export Mileage Report CTA.

Trip inbox:

- Newest-first list.
- Filter chips: All, Needs Review, Business, Personal, Missing Purpose.
- Swipe/right-left or buttons to classify Business/Personal.

Trip detail:

- Route map.
- Origin/destination.
- Date/time.
- Distance.
- Classification segmented control.
- Business purpose field.
- Vehicle picker.
- Notes.
- Manual distance override.
- Exclude from reports.
- Tax warning/disclaimer.

Vehicle settings:

- Create/edit/archive vehicles.
- Select default vehicle.
- Preserve vehicle snapshots on historical trips.

## Reporting/export

Mileage export should be paid, consistent with current export model. Capture/classification/vehicle management can be free.

MVP export formats:

- CSV
- JSON

Minimum CSV columns:

- `trip_id`
- `date`
- `start_time`
- `end_time`
- `origin_name`
- `origin_address`
- `destination_name`
- `destination_address`
- `classification`
- `business_purpose`
- `vehicle`
- `distance_miles`
- `rate_per_mile_usd`
- `deduction_usd`
- `review_status`
- `source`
- `notes`
- `start_odometer_miles`
- `end_odometer_miles`

Summary:

- Total business/personal/unclassified miles.
- Reviewed business trips.
- Business trips missing purpose.
- Estimated deduction.
- Totals by vehicle.

## Implementation checklist

### Phase 0 — Foundations

- [ ] Add `Trip` SwiftData model.
- [ ] Add `Vehicle` SwiftData model.
- [ ] Add optional `LocationPoint.tripID`.
- [ ] Update `IsoMeApp` model schema.
- [ ] Update `IsoMeIntents` model schema.
- [ ] Update tests/previews with new models.
- [ ] Add migration smoke tests.
- [ ] Add `MileageDistanceCalculator` and tests.
- [ ] Acceptance: existing stores open, existing exports unchanged, new models compile.

### Phase 1 — Manual trip logging and tagging

- [ ] Add vehicle management MVP in Settings.
- [ ] Ensure exactly one default vehicle.
- [ ] Archive vehicles without losing historical trip names.
- [ ] Add `TripRecorder`.
- [ ] Persist manual tracking sessions as Trips when Mileage Mode is enabled.
- [ ] Assign `tripID` to saved points.
- [ ] Finalize trip on stop with distance/point count/start/end coordinates.
- [ ] Recover active trip after app relaunch.
- [ ] Add Mileage tab and trip inbox.
- [ ] Add trip detail/classification UI.
- [ ] Acceptance: user can create/review/classify trips manually before any auto-drive detection exists.

### Phase 2 — IRS-style mileage export

- [ ] Add `MileageReportOptions`.
- [ ] Add `MileageReportService`.
- [ ] Add stable CSV export.
- [ ] Add JSON export.
- [ ] Filter by tax year/date range, vehicle, classification, reviewed-only.
- [ ] Flag business trips missing purpose.
- [ ] Add mileage report tests.
- [ ] Add Mileage Report export UI.
- [ ] Gate export with existing lifetime purchase.
- [ ] Add disclaimer to report UI and output footer/metadata.
- [ ] Acceptance: purchased users can export clear mileage reports; unpaid users see paywall.

### Phase 3 — Rate provider

- [ ] Add `MileageRateProvider`.
- [ ] Include date-aware built-in rate table.
- [ ] Add custom rate override.
- [ ] Show rate source in report.
- [ ] Add tests for rate selection and deduction math.
- [ ] Acceptance: reports calculate estimated deduction without claiming tax compliance.

### Phase 4 — Drive-only / auto-detect mode

- [ ] Add Motion permission copy to `Info.plist`.
- [ ] Add `DriveDetectionManager`.
- [ ] Combine CoreMotion automotive state with speed/location heuristics.
- [ ] Add drive candidate / active / ended states.
- [ ] Add tests for walking, driving, stationary, GPS gaps.
- [ ] Add Mileage Mode auto-detect setting.
- [ ] Configure `LocationManager.activityType = .automotiveNavigation` for mileage sessions.
- [ ] Discard short false starts.
- [ ] Explain battery/background limitations.
- [ ] Acceptance: confirmed drives create trips; non-driving movement does not.

### Phase 5 — Active drive UI

- [ ] Show active drive state on Map.
- [ ] Add optional Live Activity drive distance/state.
- [ ] Update `SharedLocationData` backward-compatibly.
- [ ] Update watch/widget decode tests.
- [ ] Acceptance: active drive state is visible without breaking existing widgets/watch.

### Phase 6 — Backfill and automation

- [ ] Add opt-in historical trip backfill from existing points.
- [ ] Show “review before tax use” warning.
- [ ] Run backfill in batches and avoid duplicate points/trips.
- [ ] Add simple classification rules later: work hours, locations, similar routes.
- [ ] Mark auto-classified trips visibly and keep reviewable.
- [ ] Acceptance: users can backfill old GPS history into unclassified trips for review.

### Phase 7 — Additional reports and docs

- [ ] Add PDF summary using `UIGraphicsPDFRenderer` later.
- [ ] Add Markdown report later.
- [ ] Update README and metadata with “Mileage Mode” copy.
- [ ] Ensure no “IRS compliant” claim.
- [ ] Ensure no user-facing “MileIQ replacement” claim.

## Test scope

Add tests for:

- Trip and Vehicle defaults.
- Default vehicle uniqueness.
- Trip classification persistence.
- Business purpose validation.
- Distance calculation with outliers, poor accuracy, impossible speed, gaps, manual override.
- CSV schema stability.
- Rate lookup by date.
- Report totals by classification and vehicle.
- Legacy SwiftData migration.
- Existing export tests still passing.

## Risks

- This is a large product surface and should not block simpler location-history improvements.
- True automatic drive detection depends on hard iOS background behavior.
- GPS distance differs from odometer distance.
- CoreMotion can misclassify transit/passenger rides/walking/cycling.
- Tax rules and rates change.
- Schema changes touch app, intents, tests, and future migrations.
