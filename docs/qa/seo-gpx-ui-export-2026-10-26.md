# GPX: stored synthetic points through Export UI, Files, and viewer

October 26, 2026. Improvement to the existing GPX guide; no new acquisition URL.
The physical recording gate remains open. This checks stored-record export,
not GPS collection on a walk.

## App and input

Reused the existing isolated Debug rebuild of released 1.7.16 (46), source
`6ae78e622c72ee051e6f14113082556c398d926a`, with bundle/app-group prefix
`com.bontecou.isome.seorestore`. Argent list-devices confirmed the booted
`iso-me-country-days-QA` simulator, iOS 26.5,
`5AC67EDC-DE2E-4EE7-AD57-DCBA324C8C6B`. No physical phone or normal journal
was selected. Tracking remained off; network geocoding was disabled at launch.

The journal already held the three invented points imported through the picker
in the preceding backup check. They are near (0, 0), dated January 1, 2000.
The test build's pre-existing unlocked state allows export; this is not an
Apple purchase or purchase-restoration test. Apple's public lookup was
rechecked and still lists 1.7.16.

ExportView.swift and ExportService.swift in the temporary source copy match
the release revision byte-for-byte. No filter, renderer, writer, or sharing
code was changed for this test.

## Actual UI path and saved file

- Opened Export, selected GPX, deselected JSON, and selected Points.
- Preview showed Destination: Share sheet; Format: GPX; Items: 3; Files: 1;
  generated filename `iso.me - Monday 2026-10-26 - points.gpx`; size 1003 B.
- Closed Preview, used Export 1 File, selected Save to Files, and saved to
  On My iPhone with the generated filename. A second Export tap was made after
  the first combined preview-dismiss/export sequence left the main screen
  visible; no specific transition failure cause is established.
- Read only the generated GPX paths in this QA simulator's app temporary folder
  and File Provider Storage. Their bytes match exactly. No unrelated file
  contents were inspected. The saved copy is retained unchanged as
  `marketing/public/samples/synthetic-ui-export.gpx`.

File SHA-256: `d016e1acc16b9c12c88b7da89c276a5607b7b45c9876a559932631df659a403d`.
Size: **1003 bytes**. XML checks find GPX 1.1 namespace, one track segment,
three track points, and no visit waypoints:

| Latitude | Longitude | UTC time on January 1, 2000 |
| ---: | ---: | --- |
| 0 | 0 | 12:00:00.000Z |
| 0.0001 | 0.0001 | 12:01:00.000Z |
| 0.0002 | 0.0001 | 12:02:00.000Z |

Metadata generation time is `2026-10-26T23:13:22.244Z`, distinct from the point
times. The filename's October date is not evidence that the track was recorded
that day. No fresh GPX XSD conformance test is claimed here; coordinates,
timestamps, segment/point counts, and file equality were checked directly.

## Viewer

Published the public synthetic file to preview deployment `927203fe`
(<https://927203fe.spotted-8ez.pages.dev>), with a narrow CORS allow-origin of
`https://gpx.studio` for only this new sample, matching the older sample's rule.
The documented public-URL integration loaded that exact preview file.

The first in-app-browser context retained another earlier synthetic export;
its aggregate statistics were not used. In a fresh isolated Chrome context
containing only this file, gpx.studio rendered the angled line, start/end
markers, **0.03 km**, **0.81 / 0.81 km/h**, and **02:00 / 02:00** moving/total
time. These are invented-data viewer results, not recording or accuracy metrics.
Public screenshot: `screenshots/gpx-studio-ui-export.png` (1280 × 900).
The native preview is `screenshots/gpx-preview-synthetic.png` (1206 × 2622).

Official integration reference: <https://gpx.studio/help/integration>.
No personal history was loaded, uploaded, or published.

## Scope and recording

The first UI walkthrough was recorded before launch. Its 18-step diagnostic
is retained locally in `build/seo-evidence/gpx-ui-export-20261026/`.
Three live waits passed on the AX source but carry cross-tree conversion
warnings; several action targets were reduced to role-only, raw coordinates,
or a containing view. It is not offered as a passing automated regression or
an uninterrupted replay. The functional path was checked live, with saved-file
equality and XML inspection providing evidence beyond screenshots.

Argent services were stopped only for this simulator after the native test.
No app binary upload, Apple transaction, real recording, scheduled export,
physical transfer, indexing request, or new campaign occurred.

## Publication checks

Content commit `f08b2be` was pushed directly to main and published to the existing
production Pages project as deployment `ec5b64fc`. Local and production mobile
and desktop Lighthouse scores were 100 for performance, accessibility, best
practices, and SEO. The build validated 32 HTML pages, 1116 local targets,
metadata, structured data, IDs, and sitemap coverage. Production response checks
passed all 31 public HTML/Markdown pairs and the existing response/API contract.

The new section fits at 320px and 390px without document overflow; both images
loaded. Production sample and both image bytes equal the committed assets, and
the sample returns the intended `https://gpx.studio` CORS origin. A fresh isolated
production viewer context loaded only this file and showed the same line,
0.03 km, 0.81 / 0.81 km/h, and 02:00 / 02:00. Saved live guide screenshot:
`build/seo-evidence/gpx-ui-export-20261026/guide-live.png`.

An initial default-Python-user-agent asset fetch returned HTTP 403; the existing
site verification client headers succeeded and established byte equality. No
site protection or access setting was changed. No search ranking, traffic, or
conversion improvement is inferred from these publication checks.
