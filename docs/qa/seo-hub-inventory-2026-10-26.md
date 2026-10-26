# Guide hub inventory and evidence summaries

October 26, 2026. Existing hub maintenance; no new public URL.

## Finding and correction

The guide hub linked Country Days visibly but its manually maintained
`Blog.blogPost` list still described seven articles and omitted that page.
The list now derives from the eight published blog article files and retains
the exact `BlogPosting.@id` from each, including the original journal's
`#article` identity. No integration, documentation page, or non-public Google
import draft is added as a blog post.

The normal build synchronizes that list before generating Markdown. The
standalone site checker rejects a stale list or a published article without
a reader link from the hub. Three regression tests cover adding a new article,
preserving its actual identity, idempotence, stale/unlinked failures, and
excluding non-public/integration content. All 12 Python marketing tests pass.

Updated visible GPX, backup, and Obsidian summaries to describe the completed
synthetic checks. The integration directory previously said plugins remained
a separate check; it now links to the completed desktop Maps plugin example,
while mobile transfer and scheduled delivery remain unverified.

This is consistency and discovery maintenance. It makes no new workflow,
Google indexation, ranking, traffic, or conversion claim; structured article
listing is not treated as a ranking guarantee.

## Local checks

Build: 32 HTML pages, 31 Markdown representations, 1,124 local targets,
metadata, JSON-LD, IDs, sitemap and article inventory pass. The guide hub
fits at 320px and 390px with equal viewport/document widths. Browser inspection
confirms eight exact article references, including Country Days.
