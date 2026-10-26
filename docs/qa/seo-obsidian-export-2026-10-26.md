# Obsidian guide: actual native Markdown export

October 26, 2026. Follow-up to the existing manual desktop workflow.

## Native fixture generation

Built the isolated 1.7.16 (46) release-source copy from revision
`6ae78e622c72ee051e6f14113082556c398d926a`, prepared in the prior backup
verification. Its separate bundle prefix preserves the normal simulator app.
No production app source or App Store binary was changed.

Appended [the evidence test](ObsidianExportEvidence.swift) to the existing
`ExportRoundTripTests.swift` only in that temporary release-source copy and ran:

```sh
xcodebuild test -project /path/to/isolated-release/IsoMe.xcodeproj \
  -scheme IsoMe -configuration Debug \
  -destination 'platform=iOS Simulator,id=5AC67EDC-DE2E-4EE7-AD57-DCBA324C8C6B' \
  -derivedDataPath /private/tmp/isome-seo-restore-derived \
  -parallel-testing-enabled NO \
  -only-testing:IsoMeTests/ExportRoundTripTests/testSEOObsidianMarkdownArtifact
```

The one selected XCTest passed with zero failures. It used real `Visit` models,
`ExportOptions`, `ExportService.render` and the ExportKit adapter, then parsed
the output with the actual Markdown importer. No model stubs or replacement
serializer were used.

The test sets UTC temporarily and restores the previous default afterwards.
It renders two invented visits dated January 1, 2000, with imported/unconfirmed
status, 15-minute durations, and explicit synthetic notes. The Address column
is disabled; other visit columns use their defaults. Assertions cover suggested
filename, record count, names, arrival dates, and the second coordinate pair.

The base64-delimited payload from the test log was decoded without editing its
bytes into `marketing/public/samples/synthetic-obsidian-export.md`. The export
metadata date is October 26, 2026, 6:16 PM in the test's UTC timezone; visit
timestamps remain the invented January 1, 2000 times. This is not a captured
physical outing, a purchase test, or a verification of the phone sharing UI.

Local artifacts: `/private/tmp/isome-seo-obsidian-native.log` and the xcresult
under `/private/tmp/isome-seo-restore-derived/Logs/Test/`.

## Desktop handoff

Prepared a separate local vault at
`/private/tmp/isome-seo-obsidian-actual-export-20261026` containing an identical
copy under `Location/` and a separate synthetic `Trip reflections.md` with a
wiki-link to that note. No community plugins or external sync service were
configured for the test.

Obsidian's native UI reports 1.14.5. Automatic approval review initially paused
folder selection because the currently open vault might contain unsaved work.
The owner explicitly approved opening this temporary test vault, and the test
then continued through the native folder picker. No personal note was edited.

Opened `Trip reflections` in Reading view and followed its wiki-link to
`Location/synthetic-obsidian-export`. The exported date heading, both visit rows,
arrival/departure times, durations, coordinates, names, notes, Source and Status
were present in the rendered table and accessibility tree. The note showed one
backlink. The nine-column table exceeds the default reading width; the guide
now explains horizontal scrolling and selecting fewer export columns.

Saved the synthetic-only Reading view screenshot as
`marketing/public/screenshots/obsidian-synthetic-export.png`. The export and vault
copy remained byte-identical after the UI check, SHA-256:
`2d8798387dfebaaa479a6c961895c85aa8ad54f61c2e86d27d45006d6e487220`.

This verifies native serialization, parser compatibility, desktop rendering,
and a manual file-to-note link. It does not verify iPhone sharing, cloud transfer,
mobile vault access, scheduled delivery, or map plugins. The earlier hand-authored
sample's recorded 1.14.4 rendering check remains a separate historical result.

## Publication and checks

Committed the guide, exact export, screenshot, and evidence on `main` as
`3a97bf0`, then pushed and deployed production Pages deployment
`1c94540e` (short ID; deployment URL: https://1c94540e.spotted-8ez.pages.dev).
The earlier preview was https://70545249.spotted-8ez.pages.dev; it preceded the
desktop verification and does not contain the final screenshot.

- Static build: 29 HTML pages, 954 local targets, metadata, JSON-LD, IDs, and
  sitemap coverage pass; `git diff --check` passes.
- Production HTTP checker: all 28 HTML/Markdown pairs and representation,
  error, method, API contract, and asset checks pass.
- The live Markdown download returns HTTP 200, `text/markdown`, an attachment
  filename, and the exact bytes verified above. The screenshot returns HTTP 200
  and matches the committed PNG.
- Live guide inspected in the browser: the new download, verification text,
  screenshot, and caption are present and the screenshot renders correctly.
- Lighthouse 13.5.0: mobile and desktop both score 100 for performance,
  accessibility, best practices, and SEO. Mobile LCP 947 ms, desktop LCP 340 ms;
  CLS and total blocking time are zero in both lab runs. These are lab results,
  not field Core Web Vitals or ranking evidence.
- Local Lighthouse reports: `/private/tmp/isome-seo-obsidian-after/`.
