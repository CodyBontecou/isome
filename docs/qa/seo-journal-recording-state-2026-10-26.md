# Private journal: checked recording-state example

October 26, 2026. Improves the existing acquisition page rather than creating
another overlapping journal or troubleshooting URL.

## Setup

Used the existing isolated Debug simulator rebuild of release source
`6ae78e622c72ee051e6f14113082556c398d926a`, version 1.7.16 (46), on
`iso-me-country-days-QA` (`5AC67EDC-DE2E-4EE7-AD57-DCBA324C8C6B`), iOS 26.5.
This is not the App Store-distributed binary. Separate identity
`com.bontecou.isome.seorestore` and app group preserve normal app journals.
No native production source or App Store binary changed.

Granted Always location permission through Argent because the prior backup
test had denied it. Launched with `-hasCompletedOnboarding YES` and
`-allowNetworkGeocoding NO`; onboarding and geocoding were outside this check.
No physical device was used, and no personal route was read or published.

## Observed UI

1. Baseline map: zero visits and zero path points; Start tracking, tracking off.
2. Tapped Start. The control changed to Stop, the elapsed timer read 0:01,
   and the map still had zero path points. Location status was Determining
   Location; the session summary said No active session path points.
3. Stopped, then opened Timeline. It showed one movement, zero visits, zero
   distance, and an eight-second Outing 1 with zero points.
4. Opened that outing. Start and end were both displayed at 2:41 PM on
   October 26, duration 8s, distance 0 m, points 0, with the explicit message
   No GPS points were saved for this outing yet.

All taps used the fresh accessibility frames returned by Argent. Stop and
Timeline navigation were batched with run-sequence because neither depended
on an intermediate result. No coordinates were inferred from screenshot pixels.

No GPS points were saved during the short check. The UI alone does not
establish whether a callback was absent or a fix was rejected, and this does
not establish a GPS failure on physical hardware. It verifies that a saved
session and running timer can exist without a recorded route. A successful
physical recording, visit detection, background continuity, and battery use
remain unverified in this batch.

## Published change

Strengthened the existing first-recording checklist to inspect the outing's
Points and Path, added the checked empty-path example and exact screenshot,
and linked the existing troubleshooting guide. Labelled the older interface
screenshots as illustrative and removed a duplicated adjacent download CTA.
The surviving inline CTA retains the approved `seo-private-journal` campaign.
The page description now reflects the concrete recording checks.

Screenshot copied unchanged from Argent's capture to
`marketing/public/screenshots/journal-empty-outing.png` (302×656). It contains
only the empty test outing and no personal location history.

This advances the journal's setup and diagnostic evidence. It does not close
the backlog gate for a successful recording-to-route workflow.

## Publication and checks

Committed and pushed on `main` as `7d16364`. Production Pages deployment short
ID `fce6b01f`: https://fce6b01f.spotted-8ez.pages.dev.

- Static build: 29 HTML pages, 962 local targets, metadata, JSON-LD, IDs, and
  sitemap coverage pass. `git diff --check` passes.
- Pre-deployment and production Lighthouse 13.5.0: this article scores 100 for
  performance, accessibility, best practices, and SEO, mobile and desktop.
  These lab checks do not establish field Core Web Vitals or search results.
- Production HTTP checker: all 28 HTML/Markdown pairs and cache, error, API,
  method, representation, and asset checks pass.
- Live mobile inspection: client and scroll width both 390 px; screenshot
  loaded at 304 CSS px wide, with a natural width of 302 px. The checked
  example is present and the single inline campaign CTA retains
  `ct=seo-private-journal`.
- Live screenshot returns 200 and matches the unchanged captured bytes:
  SHA-256 `398115164acee2058b3d625a41aa0160be86b5d0c95de2e2ecaae5e41a4c9bb5`.
- Local reports: `/private/tmp/isome-seo-journal-before/` and
  `/private/tmp/isome-seo-journal-after/`.
- Stopped Argent services scoped to the QA simulator; recording had already
  been stopped in the app. Other devices and personal app journals were untouched.
