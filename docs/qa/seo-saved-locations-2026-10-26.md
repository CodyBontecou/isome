# Saved locations: released reference and fixture verification

October 26, 2026. Improves the existing `/docs/places/` intent owner rather than
adding another overlapping journal or troubleshooting article.

## Release gate recheck

Apple's live US lookup still returned version 1.7.16 with release timestamp
`2026-10-26T15:37:00Z`. The earlier verified App Store Connect/build mapping
remains 1.7.16 (46), source `6ae78e622c72ee051e6f14113082556c398d926a`.
The cached web App Store extraction still showed 1.7.15, so it was not used to
override the live lookup and verified build mapping. Google Timeline migration
remains a nonpublic draft because the mapped release predates its importer.
No binary was uploaded, submitted, or released in this task.

## Why the places page changed

The old reference described saved places only through the manual-entry sheet,
with 50/100/150/250 m radius choices. The released app has a dedicated management
screen, direct latitude/longitude entry, a 25–10,000 m editor range, CSV preview,
and explicit keep/update duplicate choices. The reference did not explain that
saved locations, visits, and recorded GPS points are distinct records.

Updated the existing page's title, description, review date, and sitemap date.
Added task selection, management steps, screenshot, CSV schema and exact sample,
duplicate behavior, historical-visit boundaries, and links to relevant support.
The generated docs index and neighboring pager links use the new title.

## Editor check

Used the isolated Debug rebuild of the verified 1.7.16 source under separate
bundle/app-group prefix `com.bontecou.isome.seorestore`. Normal app journals were
not reinstalled or edited. Selected the existing iOS 26.5 QA simulator
`5AC67EDC-DE2E-4EE7-AD57-DCBA324C8C6B` using Argent list-devices.

Denied location permission for this test app, launched with onboarding skipped
and network geocoding disabled, then navigated Settings → Manage Locations →
Add Location. The editor showed name, optional address, Choose Location,
Latitude, Longitude, and Match radius (150 m default), with the 25–10,000 m
range and historical-visit boundary in its footer. Save appeared disabled while
required fields were empty. Cancelled without adding or editing a location.

Copied the unchanged editor capture to
`marketing/public/screenshots/saved-location-editor.png` (302×656). It contains
no personal data. All taps used fresh accessibility frames, and the known pair
of settings scrolls was batched with run-sequence. No screenshot pixels were
used to derive tap coordinates.

This establishes that the editor is accessible with location permission denied.
It does not establish a completed UI save, map search, physical visit detection,
or file-picker import. Interactive Maps services remain separate from the
network-geocoding preference.

## Native fixture verification

The downloadable UTF-8 CSV is hand-authored with two explicitly invented
locations. First row: name Synthetic stop A, latitude 1, longitude 2, quoted
address containing a comma, and radius 500 m. Second row: Synthetic stop B,
latitude 1.01, longitude 2.01, blank address and radius (150 m default).
It is a reusable-place sample, not measured history or a route/visit backup.

Appended [the evidence test](SavedLocationsSampleEvidence.swift) only to the
existing SavedPlaceManagementTests.swift in the temporary release-source copy.
Its CSV string matches the public file's bytes, including the final newline.
It uses the real SavedPlaceImportService, LocationViewModel, SavedPlace models,
and SwiftData in-memory container with a second context for persisted reads.
No parser or persistence stubs are used.

```sh
xcodebuild test -project /private/tmp/isome-seo-restore-release-08_3e_ws/IsoMe.xcodeproj \
  -scheme IsoMe -configuration Debug \
  -destination 'platform=iOS Simulator,id=5AC67EDC-DE2E-4EE7-AD57-DCBA324C8C6B' \
  -derivedDataPath /private/tmp/isome-seo-restore-derived \
  -parallel-testing-enabled NO \
  -only-testing:IsoMeTests/SavedPlaceImportTests \
  -only-testing:IsoMeTests/SavedPlaceManagementTests \
  -only-testing:IsoMeTests/RemotePastVisitTests
```

**29 selected tests passed, zero failures.** The new sample test verifies two
parsed/added places, exact coordinates and radii, quoted address preservation,
two skips on repeat Keep existing, two updates under Update matching, still two
saved places, and one unchanged historical visit. Existing tests cover invalid
CSV/coordinates/radii, preview/duplicate behavior, creation without a visit,
editing/deleting without changing historical visits, and explicit past-place
selection without silently using current GPS.

Local log: `/private/tmp/isome-seo-saved-locations-native.log`. xcresult:
`/private/tmp/isome-seo-restore-derived/Logs/Test/Test-IsoMe-2026.10.26_15-16-12--0400.xcresult`.
No repository native production source or app binary changed.

## Site checks before publication

- Build: 31 HTML pages including 404, 30 Markdown pages, 1,037 local targets,
  metadata, JSON-LD, IDs, and sitemap coverage pass. `git diff --check` passes.
- Exact native test CSV string was compared with the public sample bytes.
  SHA-256: `3b70d7dccfc1521f0dea87eaed34392cf1151570570f6de3756e09ae4b825480`.
- Screenshot SHA-256:
  `efabaf291e91c009bc19ba02e03cd0f04876e70796c7dcd992544c458d7126f1`.
- At 390×844: viewport and document widths are both 390 px, both tables fit,
  and the editor image loads at 302×656 without stretching.
- Local Lighthouse 13.5.0: places reference, docs index, photos reference, and
  an additional unchanged tracking reference all score 100 for performance,
  accessibility, best practices, and SEO on mobile and desktop. Reports:
  `/private/tmp/isome-seo-places-before/`. The other changed pager is Timeline
  and outings; it receives a production check with the places reference.
- Stopped Argent services scoped only to the selected QA simulator.

These are native logic and website lab checks, not indexing, rankings, field
Core Web Vitals, or a newly completed on-device save/import workflow.

## Publication

Committed and pushed on `main` as `69b9f6f`. Production Pages deployment short
ID `ec2c0058`: https://ec2c0058.spotted-8ez.pages.dev.

- All 30 production HTML/Markdown pairs, representations, cache separation,
  error recovery, methods, API contract, and asset-integrity checks pass.
- Places and Timeline/outings both score 100 for performance, accessibility,
  best practices, and SEO on mobile and desktop against production. Reports:
  `/private/tmp/isome-seo-places-after/`.
- Sample returns 200 as `text/csv` with the intended attachment filename and
  exact native-tested bytes. The screenshot returns 200 and matches its hash.
- Live mobile page has client and scroll widths of 390 px, the expected title
  and sample link, and a successfully loaded editor image.
- Local preview server was stopped. No indexing request, account change,
  purchase, new campaign, or scheduled automation was created.
