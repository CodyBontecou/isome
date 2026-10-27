# Whereday download handoff during the App Store rename

October 26, 2026, America/Puerto_Rico. No new acquisition URL.

## Finding and change

Apple's public US lookup for app ID 6761960794 still reports **iso.me 1.7.16**,
released at 2026-10-26T15:37:00Z, while the website uses Whereday. The editable
1.7.17 rename draft does not establish a public listing or release. A reader
following a Whereday CTA otherwise reaches a differently named product.

Added the factual clarification “Whereday is currently listed as iso.me in the
U.S. App Store.” to the four measured acquisition pages:

- Homepage: hero download, existing QR handoff, and pricing download.
- Original journal: introduction and closing download.
- Google comparison and GPX guide: introductory header beside the navigation
  download path. Their generator owns this temporary paragraph.

The wording is scoped to the storefront actually checked. No submission date,
release schedule, new importer support, improved conversion, or App Review
state is promised. App IDs, exact campaign URLs, QR asset, collector, prices,
canonicals, Whereday branding, and historical evidence remain unchanged.

## Removal gate

When the public US listing is confirmed as Whereday, remove every
`store-listing-note` paragraph from `marketing/public/index.html` and
`marketing/public/blog/private-location-journal-iphone/index.html`, plus the
`store_notice` generation in `marketing/scripts/build_seo_pages.py`. Rebuild
HTML and Markdown together. Do not remove it solely because the draft is
saved, a build is attached, or review is submitted. Check release contents
separately before promoting the Google import walkthrough.

## Local verification

Build: 32 HTML pages, 31 Markdown representations, 1,124 local targets,
metadata, JSON-LD, IDs, blog inventory, and sitemap pass. All four changed
pages fit at 320 and 390 CSS pixels with no document overflow. The browser
confirms the scoped note and unchanged per-page campaign on every page.
Homepage desktop placement was visually inspected at 1280 × 1000. Mobile
and desktop Lighthouse scores are all 100 on all four changed pages.

This is download-message consistency work, not a measured conversion lift.
No Apple account change, binary submission, Google indexing request, or
scheduled follow-up occurred.

## Publication checks

Pushed main content commit `e67d2bb` and published deployment `93a60946` to
the existing Pages project. All 31 production HTML/Markdown pairs and the
response/API/cache/error/method/asset contract pass. Six acquisition/redirect
tests pass. The four live pages have the expected note in HTML and Markdown,
exact Whereday canonicals, and unchanged campaigns: six home links, five
journal links, three comparison links, and two GPX links. Production homepage
fits 320px and 390px, and desktop placement is checked at 1280 × 1000.

All mobile Lighthouse checks and three desktop checks initially scored 100
in every category. The first desktop comparison run scored performance 92
with a 5,586ms observed document time-to-first-byte and 3.4s speed index; CLS
and total blocking time were zero. Three independent follow-up document
header waits were 0.840s, 0.333s, and 0.674s. One focused desktop comparison
recheck scored 100 in every category, with no code/configuration change.
The initial report is preserved; its delay cause was not established.

Reports: `/private/tmp/whereday-store-name-local/`,
`/private/tmp/whereday-store-name-production/`, and
`/private/tmp/whereday-store-name-comparison-recheck/`.
Live verification and response probes are retained under
`build/seo-evidence/whereday-store-handoff-20261026/`; screenshot `live.jpg`.
A larger PNG screenshot could not be saved through a shell argument due to
the process argument-size limit; the final JPEG was saved successfully.
The local preview server was stopped after verification.
