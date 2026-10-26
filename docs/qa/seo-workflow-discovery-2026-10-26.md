# Workflow discovery: repository and homepage

October 26, 2026. Implements the existing plan's repository-documentation links
and incremental homepage discovery work. No new public URL or outreach was needed.

## Findings and change

The guide hub already linked the main recording, backup, Obsidian, and Dawarich
workflows. The homepage exposed integration links inside its FAQ, but not its
main task list; Saved Places was two HTML links from home via the docs index.
The repository README linked the website but had no curated user-guide directory.

Added a README table with eight concrete tasks and links to the live guides,
plus docs, integration-directory, and Shortcuts references. Each example is
described at its actual verification level rather than implying physical or
unattended delivery proof.

Reconciled nearby README claims with the same release ledger used by the site:
Google import and newer manual Check Out/overlap controls are labelled as
development-source features, absent from verified public 1.7.16. Retained their
technical descriptions for contributors. Replaced the unchecked plugin
compatibility promise with the checked desktop Markdown workflow and a separate
plugin repository reference. Corrected Watch transfer to WatchConnectivity,
as present in released `IsoMeWatch/WatchLocationSyncClient.swift`, and removed
the unconditional lossless-full-history export claim in favor of filter-aware
backup checks. No native app source or binary changed.

Added two task cards to the homepage's existing grid: integrations and saved
locations. The GPX card now points readers to the concrete synthetic viewer
example. Existing design, download actions, campaign URLs, and analytics remain.

## Link and layout verification

[Graph evidence](../seo-discovery-links-2026-10-26.json) records the baseline at
`44527d8` and the changed graph. Shortest paths were calculated from static HTML
hrefs to existing public-page paths, with no external or asset URLs in the graph.
All 30 pages were and remain reachable in at most two links. Saved Places moved
from depth two to one; integration pages were already depth one through the FAQ.
These are website-link depths, not Google crawl/index data or ranking effects.

All 15 unique product-site URLs in the revised README returned HTML 200 on the
existing production site. No community message, account change, or new external
backlink was created. Publication in the project's own repository is not proof
of third-party authority or search-performance improvement.

Static build passes: 31 HTML pages including 404, 30 Markdown pages, 1,047 local
targets, metadata, JSON-LD, IDs, and sitemap coverage. `git diff --check` passes.
Mobile DOM check at 390×844: viewport and scroll width both 390 px, nine task
cards contained within the screen, and six `seo-home` campaign links retained.
Local mobile/desktop Lighthouse scores are 100 in all four categories. Reports:
`/private/tmp/isome-seo-discovery-before/`.

This is discovery and claim-consistency work; no new workflow test, physical
recording, restore, or platform compatibility beyond the referenced evidence
is claimed.
