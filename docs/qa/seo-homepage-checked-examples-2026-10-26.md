# Homepage: checked examples beside installation

October 26, 2026. Implements the existing backlog item to surface workflow
proof near download. Existing 31 public URLs are preserved.

## Change and rationale

The homepage task grid linked the full guides, while the computer-to-iPhone
QR block had no evidence beside it. Converted that existing block into a
compact two-column section with three direct links to the checked sections:

- GPX Export UI → Files → gpx.studio, using three imported synthetic points.
- Synthetic file-picker import and app-process restart, retaining one visit
  and three points after reconciliation.
- Released Obsidian Maps desktop plugin, showing two synthetic visit markers
  and popups from the native Markdown sample.

The section states the synthetic input and outstanding physical/scheduled
checks. It distinguishes free recording/review/import from purchased file
export. Replaced a generic trust paragraph with links to these checks, the
privacy policy, and developer support. No new workflow verification is claimed.

Existing `seo-home` campaign URLs and QR asset are retained; the text CTA uses
the collector's existing `inline` placement, and the QR retains `qr`. All six
homepage download anchors match the configured campaign and the QR URL manifest.
No collector, database, native app, account setting, indexing request, or new
Apple campaign was changed.

## Local checks

The build validates 32 HTML pages including 404, 31 Markdown representations,
1,123 local targets, metadata, JSON-LD, IDs, and sitemap coverage. Mobile and
desktop homepage Lighthouse scores are all 100. The new section fits at both
320 and 390 CSS pixels without document overflow; the QR loads at its reserved
160px size. Desktop layout was visually inspected at 1280 × 900.

This improves access to existing evidence; it does not establish a ranking,
traffic, or conversion lift. Search-data and physical-workflow gates remain.

## Publication

Pushed content commit `a624fca` directly to main and published Pages deployment
`3dad0dbb` to the existing production host. Production checks pass all 31
HTML/Markdown pairs and the existing response/API contract. Live homepage
mobile and desktop Lighthouse scores are 100 in all four categories.

Browser checks fetched all three destination pages with HTTP 200 and found
each intended anchor. Both download links in the section retain the `seo-home`
campaign; their `qr`/`inline` placements match the existing collector contract.
All five existing acquisition tests pass. Production 320px and 390px viewports
have equal viewport/document widths, with one column for the section. The QR
loads, and desktop rendering is checked at 1280 × 900. Screenshot:
`build/seo-evidence/homepage-examples-20261026/live.png`.

No additional Google indexing submission is needed for this existing homepage
update. The local preview server was stopped after verification.
