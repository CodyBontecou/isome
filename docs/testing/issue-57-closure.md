# Issue #57 closure audit — October 26, 2026

Base: main `200382a` (including PR #77 and PR #80). This follow-up is ready for review; close #57 when it merges. No release or App Store publication is claimed by this audit.

## Acceptance evidence

| Area | Implementation and verification |
| --- | --- |
| Visit metadata | Existing optional fields and automatic/unconfirmed defaults retained. No model schema changes in this patch. |
| Legacy migration | `VisitMigrationTests` writes an on-disk store using the exact Visit fields from `38da646^`, opens it with the current full app schema, verifies both open/completed records and defaults, corrects a record, saves and reopens it again. |
| Confirm/correct/undo, check-in/out, past logs, overlap override | Existing core and persistence tests pass. PR #77 includes simulator and physical-device QA. |
| Corrected open departure | New test sends an actual Core Location delegate callback at the detected coordinate and checks that the corrected record receives departure without duplicate insertion or loss of correction. |
| Network opt-out | Shared guard in reverse geocoding, nearby POI search, and typed search runs before caches/requests and again around awaited network work. View models discard responses after opt-out; the picker/detail explain the offline fallback. Tests exercise the real services while disabled and a delayed search response after opt-out. Map tiles are still provided by MapKit; this preference governs place lookups. |
| Ranking and test doubles | Existing injectable `PlaceSearchServicing` and stub retained. Text search ranks exact/partial names, matching POI categories, then distance with deterministic ties; nearby business filtering and distance ranking have deterministic fixture coverage. Names/protocols differ from the original proposal but fulfill its purpose. |
| Marker states | Unconfirmed: orange/question mark. Confirmed: green/check. Corrected: blue/pencil. Manual: purple/hand. Current visit keeps a blue outline; VoiceOver includes status and source. State tests cover all four. |
| Immediate map refresh | Current manual saves extend the selected range to include arrival enable visit markers, refresh route/photo caches, and focus the saved coordinate. Past saves continue to focus their chosen day. Regression covers the expired Today upper bound. |
| Export/import | JSON retains the complete audit payload. CSV adds `visit_metadata`; Markdown adds `Visit Metadata`, containing a JSON string-valued audit object. Their importers accept this optional column and preserve legacy files. GPX extensions, KML ExtendedData and GeoJSON properties include the same audit fields. |
| Export safety | Coordinate/name/address opt-outs also redact original/detected values. Backup round-trips test automatic and manual records, dates, provenance, audit coordinates, Unicode and escaped separators. Six visit formats are covered; OwnTracks/Overland remain points-only. Existing eight-format parsing/schema tests pass with explicit updated schemas. GPX/KML/GeoJSON remain one-way map exports, as documented in the importer. |
| Docs/localization | README describes manual visits, privacy and marker semantics. New offline explanation has translations in all 11 supported locales. The catalog-wide audit has the same 2,576 pre-existing errors before and after this patch (zero new errors); the added key is separately checked for complete translated locale coverage. |
| Extensions | Watch commands stay in #75; Shortcuts/deep links are complete through #80. Neither blocks this iOS epic. |

## Export audit fields

`source`, `confirmationStatus`, `confirmedAt`, `updatedAt`, `originalLatitude`, `originalLongitude`, `originalLocationName`, `originalAddress`, `detectedLatitude`, `detectedLongitude`, `detectedLocationName`, `detectedAddress`, `placeSource`, `placeDistanceMeters`. Optional unset values are omitted. Consumers should accept additive columns/properties/extensions. Source/status columns use stable raw values rather than translated display labels.

## Verification

- Before fix: `testCSVPreservesCorrectionAuditCoordinates` failed twice: original/detected latitude were nil after CSV import.
- Focused suite: 23 tests passed (before the additional text-ranking test).
- Full simulator suite: **340 passed, 0 failed, 0 skipped**, successful test command exit, iOS 26.5 simulator `BF9F9B4E-43B7-4888-BC70-31CA40ADA914`.
- Result bundle: `~/Library/Developer/XcodeBuildMCP/workspaces/iso.me-a993e450d16a/result-bundles/test_sim_2026-10-26T19-28-49-548Z_pid6216_398c9e7c.xcresult`.
- Build and launch succeeded. Live seeded Map showed the orange question-mark markers. In Add Past Visit → location picker, network opt-out explanation was visible; Drop Pin produced Pinned location with coordinates and enabled Use, without an address lookup.
- The optional recorded UI replay missed a sheet transition after two attempts. It is diagnostic only, not a passing automated UI regression. The live screenshots/tree inspection and executable service/model tests above are the evidence used here.

Reproduce the application suite:

```sh
xcodebuild test -project IsoMe.xcodeproj -scheme IsoMe \
  -destination 'platform=iOS Simulator,id=BF9F9B4E-43B7-4888-BC70-31CA40ADA914' \
  -derivedDataPath /private/tmp/isome-57-derived \
  -parallel-testing-enabled NO
```

Use a simulator test host with location permission denied, as in the existing manual-visit QA setup, so real location delivery cannot contaminate count fixtures. The migration test uses a separate temporary store and deletes it afterward.

## Pre-merge revalidation

Main was integrated after the initial PR run; the README retains its distinction between development controls and the verified public release. Automated review identified that a `---` substring in audit metadata could be mistaken for a Markdown table separator and discard the whole visit. A three-visit regression reproduced this before the fix. Separator detection now requires every cell to be a Markdown rule (hyphens with optional alignment colons), preserving those audit values.

The updated full simulator suite passed **341 tests, zero failures, zero skipped**, with successful command exit. Result bundle: `~/Library/Developer/XcodeBuildMCP/workspaces/iso.me-b28a86da2136/result-bundles/test_sim_2026-10-26T19-55-41-470Z_pid32373_51c8f168.xcresult`.
