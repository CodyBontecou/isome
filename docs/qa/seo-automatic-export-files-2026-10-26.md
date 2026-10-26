# Automatic-export reference: checked file semantics

October 26, 2026. Improves the existing `/docs/automatic-exports/` intent owner
and its hub/backup links. It does not add another competing acquisition URL.
This is an editorial decision based on a verified workflow gap, not measured
new keyword demand or ranking performance.

## Native check

Used the existing isolated Debug rebuild of 1.7.16 (46), release revision
`6ae78e622c72ee051e6f14113082556c398d926a`, in
`/private/tmp/isome-seo-restore-release-08_3e_ws`. Argent list-devices confirmed
the already booted `iso-me-country-days-QA`
(`5AC67EDC-DE2E-4EE7-AD57-DCBA324C8C6B`), iOS 26.5. No physical device selected.

[Evidence tests](ScheduledExportFileEvidence.swift) were appended only to the
temporary copy's existing IntervalScheduledExportTests.swift. They call the
actual IsoMeScheduledExportPlan, IsoMeExportKitAdapter, ExportFileWriter with
FileManagerExportFileSystem, merge strategies, and ImportService. Synthetic
records are near zero on local January 1–2, 2000. Temporary files are read
back and parsed, then deleted. No personal journal, real folder bookmark,
schedule registration, push notification, or cloud service is exercised.

Compared these files byte-for-byte against the released revision: scheduled
merge strategies, daily scheduler, interval date math, export adapter,
ExportService, and ExportFolderManager. All are unchanged. No native production
repository code or binary was changed.

```sh
xcodebuild test -project /private/tmp/isome-seo-restore-release-08_3e_ws/IsoMe.xcodeproj \
  -scheme IsoMe -configuration Debug \
  -destination 'platform=iOS Simulator,id=5AC67EDC-DE2E-4EE7-AD57-DCBA324C8C6B' \
  -derivedDataPath /private/tmp/isome-seo-restore-derived \
  -parallel-testing-enabled NO \
  -only-testing:IsoMeTests/IntervalScheduledExportTests
```

**27 tests passed, zero failures.** The 24 existing tests cover schedule cycles,
DST examples, daily paths, window planning, format policy, and merge behavior.
The three new disk tests establish:

1. First append through 11:00 writes points at 10:00 and 11:00. The next append
   through 12:00, cursor 11:00, writes the boundary plus a 12:00 point. The
   actual saved CSV parses as four points (11:00 twice); JSON parses as three.
   The interval starts inclusively, CSV drops the new header but not repeated
   rows, and JSON applies its identity-key merge.
2. A 10:00 visit exported open at 11:00 receives a 12:00 departure. Appending
   from 11:00 leaves the previously exported departure absent; rewriting the
   same file through 12:00 includes it. Selection uses arrival time, so a
   departure edit does not make that old arrival new.
3. A 23:55 rewrite saves a 23:50 point. After adding a 23:59 point and a 00:05
   point, a rewrite at 00:10 creates the next day's file with only 00:05.
   Yesterday's bytes are unchanged and lack 23:59.

Log: `/private/tmp/isome-seo-scheduled-files.log`. These checks do not invoke
the scheduler's complete Run Now path, file-picker/bookmark access, actual
background wake, notification delivery, cloud sync, or unattended scheduling.
They establish file behavior for the tested inputs, not all merge edge cases.

## Source review and site changes

The scheduler calls runExport with Date() when handling overdue work, and the
planner clamps the window to that actual local day. Thus catch-up after midnight
is not historical backfill. Once-daily runs always rewrite; interval Append is
format-dependent, with GPX/KML using full-day overwrite. The manual Export
view's date/split options do not determine the scheduled window.

The reference now provides setup/verification steps, date-cutoff explanation,
correct schedule-cycle example, format tradeoffs, checked results table,
missing-file diagnosis, privacy scope, and three focused questions. Removed
blanket “no duplicates” and “self-healing” promises. The backup guide links the
checked examples and explains the post-midnight limit. The documentation hub
uses the specific new title/summary; the existing URL is retained.

Apple's [earliestBeginDate documentation](https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate)
was checked October 26, 2026 for the linked background launch limit. No
specific delivery time is promised. The app's own scheduling source is the
basis for its refresh/push/fallback/catch-up mechanisms, with no claim that
those mechanisms were exercised in this test.

Static build passes 31 HTML pages, 30 Markdown pages, 1,068 local targets,
metadata, JSON-LD, IDs, sitemap coverage, and `git diff --check`. Mobile
inspection at 390 px shows a 390 px document, two contained tables, and the
updated title and evidence section.

## Layout follow-up

The longer guide title also appears in the export and webhook references'
previous/next navigation. Both navigation layouts fit at 390 px. Inspection
found an existing webhook receiver table extending the whole document to
472 px. A narrow, named, keyboard-focusable overflow region now contains that
table; the webhook document and viewport both measure 390 px. No shared CSS
or unrelated page layout was changed.

Local Lighthouse 13.5.0 passes all four categories at 100 for automatic exports,
the docs hub, and the backup article on mobile and desktop. Reports:
`/private/tmp/isome-seo-automatic-files-before/`. The webhook neighbor has its
own reports in `/private/tmp/isome-seo-automatic-files-neighbor-before/`.

## Publication

Implementation pushed on `main` as `64267e5`. Production deployment:
`b963f622`, https://b963f622.spotted-8ez.pages.dev.

Content-specific HTTP checks confirmed all four production pages were current
before starting the final production Lighthouse run. Live browser checks
confirm the new reference/checked examples and 390 px document/viewport; the
webhook table is contained in its named region. Desktop visual proof:
`build/seo-evidence/automatic-files-20261026/automatic-export-checks-live.jpg`.

The local preview was stopped. Scoped Argent cleanup of the one QA simulator
used found no remaining services. No new campaign, Google indexing request,
external message, scheduled task, or app submission was made.

Production HTTP verification passes all 30 HTML/Markdown pairs and cache,
representation, 404, API, method, and asset checks. Final Lighthouse 13.5.0
scores 100 for performance, accessibility, best practices, and SEO on all
four audited pages, mobile and desktop (eight checks). Reports:
`/private/tmp/isome-seo-automatic-files-after/`. These lab results do not
establish field Core Web Vitals, indexation, rankings, or conversions.
