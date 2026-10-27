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
