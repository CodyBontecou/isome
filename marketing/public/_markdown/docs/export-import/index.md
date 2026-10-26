§ Docs · Guide 6 of 11

# Export and restore location history

Export recorded visits, route points, and outings in eight formats. Preview is free; writing files requires Pro. Import supported iso.me visit and point files for free.

Platform

iOS 17+

Updated

October 26, 2026

Reading

5 min

Back to

[All docs](https://isome.isolated.tech/docs/)

Free vs Pro. Building and previewing exports is free. Writing export files (from the app's Export tab or an outing's page) is the Pro unlock, along with automatic exports and webhooks. Importing a prior export is free.

## Eight formats

| Format | Best for
| JSON | Structured visit and point records, scripts, and tooling.
| CSV | Spreadsheets and analysis.
| Markdown | Human-readable journals — single outings export as a front-matter page with visits and route points.
| GeoJSON | Mapping tools and GIS.
| GPX | GPS tools and route viewers; visits become waypoints, routes become tracks.
| KML | Google Earth and Earth-compatible viewers.
| OwnTracks | OwnTracks-ecosystem tools (route points).
| Overland | Overland-ecosystem tools (route points).

Choose any mix of formats in one export; each becomes its own file. OwnTracks and Overland formats carry route points (visits exports in those slots fall back to JSON). For receiver delivery, follow the [Dawarich Overland walkthrough](https://isome.isolated.tech/integrations/dawarich/) and verify the destination’s saved points.

## What gets exported

- Data: visits, route points, outings, or all of it.
- Date range: all time (default), today, yesterday, last 7 or 30 days, this month, or a custom range.
- Time of day (off by default): keep only records between two times — windows that cross midnight work too.
- Filters: only completed visits, minimum visit duration, exclude GPS glitches, and a maximum-accuracy cap (≤ 10 / 25 / 50 / 100 m).
- Fields: per-format toggles for names, addresses, durations, coordinates, notes, altitude, speed, accuracy, and glitch flags.

Your entire setup — formats, data kind, filters, field toggles — is remembered between launches.

## Filename templates

File names come from a template you control. These tokens are available:

`{date}` `{year}` `{month}` `{dayNumber}` `{weekday}` `{monthName}` `{quarter}` `{datetime}` `{time}` `{day}` `{type}` `{title}` `{name}` `{format}`

- Use `/` in a template to build dated subfolders.
- Built-in presets: Readable (default) `iso.me - {day} {date} - {type}`, Compact, and Dated `{year}/{year}-{month}/Daily Track - {date}`.
- A live preview shows the resolved path as you type.

## Output layout

- Single file (default) or one file per day — handy for journals and incremental backups.
- Exporting outings produces one file per outing automatically.
- Collisions are auto-suffixed so nothing overwrites.

## Saving and sharing

Pick a default folder (with auto-save on by default) and exports land there silently with a confirmation toast; otherwise the standard share sheet appears. The Preview button renders everything without writing — free, and a good way to sanity-check filters. Single outings can also be exported straight from their detail page.

## Import

Settings → Import file accepts visit and point files exported from iso.me as JSON, CSV, or Markdown. Importing is free. A matching file extension alone does not make another app's file compatible: The verified App Store 1.7.16 build does not support Google Timeline archives; its importer also lacks the newer preview and duplicate checks.

Choose a file for the next task
| Format | Useful for | Import into iso.me
| iso.me JSON | Structured visit or point records | Supported visit and point exports
| iso.me CSV / Markdown | Spreadsheets / readable records | Supported visit and point exports; required fields must remain
| GPX / KML / GeoJSON | Mapping tools and route viewers | No
| OwnTracks / Overland | Compatible location tools | No

If Preview is unexpectedly empty, follow the [export filter diagnosis](https://isome.isolated.tech/blog/missing-location-history-iphone/#export) before changing or importing journal records. It covers record type, arrival dates, time of day, accuracy, and visit completion.

## Keep a copy and check it

- Select visits or route points, JSON, and the dates you want to retain. Export each data type you need; keep all generated files.
- Preview the result. Check that filters, field choices, and dates have not excluded required records.
- Export to a folder you control and confirm the files exist in Files before deleting or replacing anything.
- When importing later, keep the originals and inspect several dates, visits, and points after the import. Do not assume every setting, photo association, or edited outing is restored.

[Automatic exports](https://isome.isolated.tech/docs/automatic-exports/) can keep scheduled copies, subject to iOS background execution. For the recording workflow, see [the private location journal guide](https://isome.isolated.tech/blog/private-location-journal-iphone/). For a route file, follow [the GPX recording walkthrough](https://isome.isolated.tech/blog/record-iphone-route-gpx/). For restorable records, use [the backup and restore checklist](https://isome.isolated.tech/blog/back-up-iphone-location-history/). Comparing apps? Read [iso.me and Google Timeline](https://isome.isolated.tech/compare/google-maps-timeline/).

Import adds supported records. In the checked 1.7.16 release-source example, post-import visit reconciliation combined two nearby visits into one, while importing the point file again added repeated points. The import result is not necessarily the final stored visit count. See the [checked disk import and JSON re-export](https://isome.isolated.tech/blog/back-up-iphone-location-history/#checked-import). Import each intended file once, then check individual records before retrying. The [synthetic JSON examples](https://isome.isolated.tech/blog/back-up-iphone-location-history/#sample) show the visit and point structures without using private history.

For a readable note in a desktop vault, follow the [Markdown-to-Obsidian workflow](https://isome.isolated.tech/blog/iphone-location-journal-obsidian/). It covers manual file placement and keeps generated notes separate from personal writing.

[← PreviousPhotos on the map](https://isome.isolated.tech/docs/photos/) [Next →Automatic exports](https://isome.isolated.tech/docs/automatic-exports/)

Source: https://isome.isolated.tech/docs/export-import/
