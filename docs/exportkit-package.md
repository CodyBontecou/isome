# ExportKit integration

iso.me uses the standalone `https://github.com/CodyBontecou/ExportKit` Swift package for reusable export infrastructure while keeping all location-domain logic in this app.

## Domain mapping

- Exportable app models: `Visit` and `LocationPoint` SwiftData records.
- App settings: `ExportOptions`, `ExportFormat`, and `FilenameTemplate` remain app-owned because they drive iso.me copy, UI labels, field toggles, filters, and persisted preferences.
- ExportKit payload: `IsoMeExportSnapshot` in `IsoMe/Utilities/IsoMeExportKitAdapter.swift` conforms to `ExportRecord` and wraps the filtered visits/points for either one condensed export or one split-by-day export record.

## ExportKit adapters

`IsoMeExportKitAdapter` owns the app-local bridge:

- `ExportFormatDescriptor` values are derived from iso.me `ExportFormat` cases (`json`, `csv`, `markdown`, `owntracks`, `overland`, `gpx`, `kml`, `geojson`).
- `AnyExportRenderer<IsoMeExportSnapshot>` renderers delegate to the existing iso.me format functions so exported files remain compatible.
- `IsoMeExportPathPlanner` expands iso.me path tokens, preserves `/` as relative folder separators, rejects traversal/absolute paths, and sanitizes each path component before writes.
- `PlannedExportFile` is the shared unit for render, preview, share-sheet temp files, and default-folder writes.
- `ExportFileWriter` writes planned files in `ExportFolderManager.savePlannedFilesToDefaultFolder` and for share-sheet temporary files.
- `IsoMeExportKitAdapter.preview(...)` uses `ExportPreviewBuilder` for no-write previews.
- `IsoMeExportKitAdapter.run(...)` wraps `ExportRunOrchestrator` for generic success/failure result reporting.

## Automation

iso.me has a once-per-day export scheduler. `DailyExportScheduler` uses `ExportAutomationKit.AutomationSchedule` and `AutomationScheduleDateMath` for next-run and due-time calculations, mirrors enabled schedules to `worker/scheduled-notifications`, and handles three recovery triggers:

- a server-side silent APNs push at the selected minute;
- a local visible fallback notification shortly after the selected minute;
- app-open catch-up if the scheduled occurrence is overdue.

The worker stores only routing and timing metadata (install id, APNs token, bundle id, timezone, hour/minute, and next fire time). It must not store location records, export files, destination folder paths, or filename templates. Tapping the fallback notification retries the exact scheduled fire date only when `lastRun` does not already cover it, preventing duplicate exports when a silent push or background task already completed.

## Preserved behavior

- Existing JSON/CSV/Markdown/OwnTracks/Overland/GPX/KML/GeoJSON renderers remain in `ExportService` and are reused by ExportKit renderers.
- `ExportOptions` filters, field toggles, date ranges, time-of-day windows, and split-by-day behavior are unchanged.
- Existing filename tokens (`{date}`, `{datetime}`, `{time}`, `{day}`, `{type}`, `{format}`) and sanitizing are preserved, with additional date tokens (`{year}`, `{month}`, `{dayNumber}`, `{weekday}`, `{monthName}`, `{quarter}`) and `/` subfolders supported.
- Default folder bookmarks remain managed by `ExportFolderManager`.
- Export purchase gating, UI labels, webhook settings, app intents, and import logic remain app-specific.
