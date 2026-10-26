# iso.me article cluster inventory

Reviewed October 26, 2026. A subsequent direct HTTP audit confirms all paths below are now live, as part of a 27-URL sitemap. The Search Console baseline remains the pre-deployment baseline and does not measure the new cluster's results. See [the refreshed SEO priorities](isome-seo-priorities-2026-10-26.md) for the live audit and next work.

**Release reconciliation completed:** The verified public build is 1.7.16 (46), from source preceding the importer. Public pages now state those version-specific limits; the Google migration walkthrough remains a non-public draft. Country Days is in that public build and now has a guide. See [implementation results](seo-implementation-2026-10-26.md). The following was the earlier source-drift finding: current source adds Google Timeline JSON import, preview, and duplicate detection; the live comparison, history guide, backup guide, and export reference still describe the older behavior. Align claims with confirmed public app versions. Country Days and expanded manual-visit Shortcuts also need a release-aware content review. The rows below record the original article scopes, not proof that their product claims remain current.

| Page | Reader task | Distinct scope | Evidence and remaining limits |
| --- | --- | --- | --- |
| `/blog/private-location-journal-iphone/` | Start a location journal | Product introduction and first recording | Source-reviewed controls; illustrative app screenshots |
| `/blog/view-location-history-iphone/` | Find existing history | Apple, Google, or an already enabled recorder | Primary platform documentation; menus vary by version/region |
| `/compare/google-maps-timeline/` | Compare recording choices | Accounts, storage, export, backup and migration boundaries | Primary Google sources and iso.me source; no Google import promise |
| `/blog/record-iphone-route-gpx/` | Save a newly recorded path | Points, preview, GPX and viewer checks | Synthetic GPX validated against official schema; no new physical recording or third-party route-viewer test |
| `/blog/back-up-iphone-location-history/` | Preserve supported records | Separate visit and point files, verification and import | Synthetic JSON parsed by actual Swift importer; not a full device restore test |
| `/blog/iphone-location-tracking-battery/` | Diagnose energy tradeoffs | Battery report, distance filter and stopping controls | Apple guidance and source review; no measured duration or saving |
| `/blog/missing-location-history-iphone/` | Diagnose an incomplete iso.me day | Recording, hidden/rejected points, visits, Watch transfer and export filters | Source-reviewed diagnostic checklist; no promise to recover absent records |
| `/blog/iphone-location-journal-obsidian/` | Read visit records in a desktop vault | Manual Markdown handoff and generated-file boundaries | Hand-authored synthetic note rendered in Obsidian 1.14.4; mobile and scheduled delivery untested |
| `/docs/apple-watch/` | Record away from iPhone and check transfer | Existing feature reference, controls and status meanings | Current source and existing replay context; no new physical Watch walk claimed |

| `/blog/track-days-in-country-iphone/` | Review country dates | Counting rules, timezones, manual stays and optional CSV | Verified released source; current simulator interface capture; synthetic counting examples |

## Reader paths

The blog hub groups tasks into **find and check history**, **record and review routes**, and **keep and use records**. Each generated article offers two task-specific next steps. The original journal remains the introductory article and links to deeper workflows in context.

Preserve these boundaries when adding content. Expand an existing section when the task already belongs to one of these pages. New pages should answer a distinct task with evidence beyond a change in wording.

## Verification gates still open

- Dawarich: run a current receiver with synthetic records, verify protocol/authentication and destination persistence before publishing the integration.
- GPX workflow: complete a fresh device recording and open its saved export in a compatible viewer.
- Backup: check actual export and restore persistence on a clean destination, retaining originals.
- Watch: complete a physical watch-only walk and verify later points and visits on the phone.
- Obsidian: verify the selected iPhone Files/vault path and actual delivery before describing mobile or scheduled integration as tested.
- Growth measurement: deploy under separate authorization, record the release date, inspect indexing, and compare equal-length reporting windows. Local page count and link checks do not establish SEO results.
