# Whole-site mobile layout: contained documentation tables

October 26, 2026. A technical usability pass after the content/evidence work.
No additional article, title experiment, or search-performance claim is made.

## Measured problem

Loaded all 30 sitemap pages in same-origin browser frames at 320 and 390 CSS
pixels: 60 cases. Waited for each document load and fonts before comparing
its scrollWidth with clientWidth. The baseline is stored in
[the measurements](../seo-mobile-layout-before-2026-10-26.json).

| Page | 320 px baseline document | 390 px baseline document |
| --- | ---: | ---: |
| Tracking reference | 414 px | 414 px |
| Privacy reference | 455 px | 455 px |
| Export/import reference | 351 px | 390 px |
| Shortcuts reference | 335 px | 390 px |

Six of 60 cases widened the entire document. All were documentation tables;
the remaining sitemap pages fit both widths. The Shortcuts page has two wide
action tables, for five affected tables across four pages.

## Change

Wrapped those five tables in named, keyboard-focusable regions with local
horizontal scrolling. Retained every column and cell. Added descriptive
captions where absent and explicit column-header scope. No shared CSS, table
font reduction, document overflow hiding, navigation changes, or copy/metadata
experiment was needed. Source changes are in `marketing/scripts/build_docs.py`;
generated HTML and Markdown are rebuilt. Review dates were not refreshed solely
for the layout adjustment.

## Verification and scope

[The final measurements](../seo-mobile-layout-after-2026-10-26.json) show all
30 pages fit at both widths: **60 cases, zero document overflow**. Frames are
sandboxed without scripts in the final sweep to avoid child-page analytics
and scripted behavior. The audit measures the static responsive layout, not
all interactive states or physically tested devices. The initial baseline
used normal frames; the changed docs use scripts only for analytics, not their
table layout. Same fonts and CSS were used throughout.

A direct 320 px browser check of Privacy confirms:

- viewport/document both 320 px;
- its region is 234 px wide and contains a 412 px table;
- the region accepts focus with the browser's visible outline;
- ArrowRight changes the region's scrollLeft from 0 to 40 px while the whole
  document stays 320 px wide.

Static build passes 31 HTML pages, 30 Markdown pages, 1,074 local targets,
metadata, JSON-LD, IDs, sitemap coverage, and `git diff --check`.
This pass establishes measured browser reflow and keyboard scrolling; it is
not a screen-reader, full accessibility-conformance, physical-device, field
Core Web Vitals, or ranking audit.

Local Lighthouse 13.5.0 scores 100 in all four categories on the four changed
references, mobile and desktop. Reports:
`/private/tmp/isome-seo-mobile-tables-before/`.
