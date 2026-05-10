# iso.me new-feature simulator QA artifacts — 2026-05-09

Captured from the integration branch on the iPhone 17 simulator (`36F3910D-951D-44D6-9B9E-9A3793BA37AD`) with seeded dummy data via:

```sh
--seed-screenshot-data --default-tab=<tab>
```

Seeded scenario includes a San Francisco usage day with multiple classified trips, timestamped GPS path points, active/archived vehicles, vehicle-linked mileage, Dawarich webhook defaults, and export-unlocked state.

## Feature coverage

| Feature | Screenshots | Video |
|---|---|---|
| Map route, seeded path, GPS timestamp callout | `screenshots/00-launch-map.png`, `screenshots/02-map-timestamp-callout.png` | `videos/01-map-trips-classification.mp4` |
| Trip classification / MileIQ-style visit list | `screenshots/03-trips-classification-list.png` | `videos/01-map-trips-classification.mp4` |
| Visit detail classification, purpose, and vehicle assignment | `screenshots/04-visit-detail-classification-vehicle.png`, `screenshots/05-visit-vehicle-assignment.png` | `videos/01-map-trips-classification.mp4` |
| Settings entry points for reports and vehicles | `screenshots/06-settings-reports-vehicles.png` | — |
| Multi-vehicle management with active/default/archived vehicles | `screenshots/07-multi-vehicle-list.png` | `videos/02-vehicles-bluetooth-form.mp4` |
| Bluetooth vehicle auto-detection / paired route detail | `screenshots/14-bluetooth-vehicle-detection-detail.png` | `videos/02-vehicles-bluetooth-form.mp4` |
| Vehicle edit form and odometer/default controls | `screenshots/15-vehicle-edit-form.png` | `videos/02-vehicles-bluetooth-form.mp4` |
| IRS mileage report filters, vehicle/purpose toggles | `screenshots/08-irs-mileage-report.png` | `videos/03-mileage-report-export.mp4` |
| Mileage report preview and CSV/PDF export controls | `screenshots/16-mileage-report-preview-export.png` | `videos/03-mileage-report-export.mp4` |
| Export formats including KML and webhook entry | `screenshots/09-export-kml-dawarich.png` | — |
| Dawarich webhook setup and preset selection | `screenshots/10-dawarich-webhook-settings.png`, `screenshots/11-dawarich-enabled-settings.png`, `screenshots/12-dawarich-target-picker.png`, `screenshots/13-dawarich-selected.png` | `videos/04-dawarich-webhook-setup.mp4` |
| Drives-only mode and export defaulting to points | `screenshots/17-drives-only-mode-selected.png`, `screenshots/18-drives-only-export-points-default.png` | `videos/05-drives-only-export-points.mp4` |
| Spanish Settings localization | `screenshots/19-settings-spanish-localization.png` | — |

## Notes

- Real Bluetooth hardware route matching cannot be fully validated in Simulator; this run verifies the seeded paired-route UI, vehicle attribution, and controls.
- Location permission was granted in Simulator and seeded data was used to simulate real app usage without changing production data.
- Post-capture validation passed: `xcodebuild test -project IsoMe.xcodeproj -scheme IsoMe -destination 'platform=iOS Simulator,name=iPhone 17'` → 49 tests / 0 failures.
