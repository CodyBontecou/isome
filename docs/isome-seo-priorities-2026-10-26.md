# iso.me SEO priorities after the first guide release

Reviewed October 26, 2026. This supersedes the outstanding-work list in [the original plan](isome-seo-plan-2026-10-26.md). The audit below is the pre-implementation assessment. See [implementation and release results](seo-implementation-2026-10-26.md) for deployed changes, verified release facts, and the remaining gates.

## Decision

Build on the live English cluster. First reconcile product claims, measure the acquisition path, and strengthen the private-journal, Google comparison, and GPX pages. The first new page should walk through Google Timeline import, once the public app's support is confirmed. Country Days is the next distinct scenario candidate after its release and workflow are verified.

Apply Vaultaire's connection between a specific problem, a useful answer, related pages, and an app download. Reproduce its search-data feedback loop before its multilingual scale. Priorities below are editorial judgments based on product fit, existing evidence, and effort; search volumes and keyword difficulty have not been measured.

## Current website: what is actually live

The production website is **https://isome.isolated.tech/**. iso.me is the product name. Keep the existing host and `/blog/` URLs.

A direct HTTP audit fetched all **27 sitemap URLs** successfully. Each returned 200, one H1, a unique title, an English language declaration, and the expected self-canonical. All sitemap pages were reachable within two internal-link clicks of the homepage. No language alternatives were present. These results establish delivery and basic site structure, not Google indexation or rankings.

| Live content | Count |
| --- | ---: |
| Homepage | 1 |
| Blog hub and articles | 1 + 7 |
| Comparison hub and Google comparison | 1 + 1 |
| Documentation hub and reference pages | 1 + 11 |
| About, contact, privacy, terms | 4 |
| Total | 27 |

The local site checker also passes: **28 HTML pages, 873 local targets**, metadata, JSON-LD, IDs, and sitemap coverage. Its 28th page is the 404 template, excluded from the sitemap. Live audit details are in [the inventory](seo-live-inventory-2026-10-26.json). Some web-search extraction still showed the previous one-article blog; the direct live fetch establishes the current inventory.

Strengths already implemented: task-oriented homepage links and guide hub; separate setup/history/GPX/backup/support intents; crawlable static content; contextual related links; comparison content; author/review dates; screenshots; synthetic downloadable examples; accurate free-recording versus paid-export explanations. No framework migration, duplicate `/guides/` section, or broad redesign is indicated by this audit. Core Web Vitals, live mobile rendering, backlinks, and whole-property indexation were not measured in this review.

## Priority zero: reconcile the product before expanding claims

### Google import changes the acquisition opportunity

The deployed Google comparison says **“No Google Timeline importer.”** The history guide says iso.me does not import Google files. The backup guide says it does not skip duplicates. These statements describe older behavior and conflict with current source:

- `IsoMe/Utilities/GoogleTimelineImportService.swift` handles classic Location History, legacy Semantic Timeline, and device Timeline JSON.
- `IsoMe/Utilities/TimelineImportService.swift` implements preview, selected record types, and approximate duplicate detection.
- [Existing simulator QA](qa/google-timeline-import.md) records preview, cancellation, persistence, and repeated-import checks.

Confirm support in the publicly distributed build before changing the website to an availability promise. Apple's public US lookup returned **1.7.16**, released October 26 at 15:37 UTC; the checkout targets **1.7.17**. The importer commit itself targeted 1.7.16, so the version difference does **not** establish that import is unreleased. Check the released build/source mapping or the installed App Store build. Record the verified minimum version on the relevant pages.

Reconcile `/compare/google-maps-timeline/`, `/blog/view-location-history-iphone/`, `/docs/export-import/`, `/blog/back-up-iphone-location-history/`, and any conflicting linked copy in one content batch. Preserve valid distinctions: an importer cannot recreate unrecorded/deleted history; raw points do not imply inferred visits; GPX import remains unsupported. Separate the older iso.me restore workflow from the new Google migration workflow.

Also reconcile prices between the website, README, and authoritative regional purchase sheet. The website quotes US $19.99/$39.99; README quotes $10/$20, also surfaced in the sampled App Store extraction. This is a consistency issue to verify, not a basis to declare one source current from cached text. Review the privacy policy/App Store disclosure alongside the actual telemetry behavior. Keep this a factual reconciliation, not a redesign project.

### Make the acquisition path measurable

Use the existing [Search Console baseline](search-console-baseline-2026-10-26.md): September 27–October 24 had **5 clicks, 297 impressions, 1.7% CTR**. The original journal article had **60 impressions and zero clicks**; the homepage received all five clicks. These are historical values from a filtered property, not performance of the newly deployed cluster. Query/country/device breakdowns are partial; there is no defensible country ranking or complete branded/nonbranded split.

First measurement tasks:

1. Record the deployment/intervention date from the release history. Check sitemap discovery and URL Inspection for the comparison, GPX, history, and original journal pages. The old report's 17 discovered URLs is not a current count.
2. Add explicit outbound `app_store_clicked` collection with page path and CTA placement, preserving the existing analytics exclusion gate. Do not include coordinates, user text, arbitrary query strings, or location files.
3. Generate genuine page-level Apple campaign links using the account's provider token. Start with home, journal, Google comparison, and GPX rather than fragmenting a tiny audience into dozens of campaigns.
4. Report organic landing visits, outbound clicks, attributable first-time downloads, and purchases separately. Apple campaign reporting has minimum thresholds; missing reports are not measured zeros. Do not promise a deterministic click-to-purchase join.

## Ordered page backlog

Existing pages are improvements, not pages to recreate. Effort estimates are editorial/engineering person-days, excluding App Store review, waiting for search data, and access-dependent verification.

| Order | Action / page | Target reader intent | Concrete deliverable | Effort |
| --- | --- | --- | --- | ---: |
| 1 | Improve Google comparison + export reference | “Google Timeline alternative iPhone”; supported imports | Release-accurate migration row, preserved Google strengths, supported-format matrix, preview/deduplication limits, tested screenshot, link to migration guide when live | 1–2 days |
| 2 | Improve existing private-journal article | “private location journal iPhone”; “location history stored locally” | One verified first-recording example, current screenshots, specific privacy boundaries, contextual CTA after the successful example | 1 day |
| 3 | Improve GPX route article | “record route iPhone GPX”; “iPhone GPS logger export GPX” | Real app recording → export → opened in a named compatible viewer, measured point/time details, screenshots of the same route, clear paid-file boundary | 1–2 days |
| 4 | Create `/blog/import-google-timeline-iphone/` | “import Google Timeline iPhone”; “move Google Timeline to another app” | Versioned export-to-import walkthrough with preview, duplicates, supported Google JSON variants, failure paths, and original archive retained | 1–2 days after availability check |
| 5 | Improve history article and backup guide | Find already-recorded history; retain/restoring iso.me records | Current Apple/Google screenshots and migration link; actual clean-destination restore check and corrected duplicate behavior | 1–2 days |
| 6 | Improve `/docs/apple-watch/` | “record GPS route Apple Watch without iPhone” | Watch-only route, reconnect/Sync Now, phone route confirmation, then export; tested device/app/OS labels | 1–2 days |
| 7 | Improve homepage and hubs incrementally | Choose the right next task | Add migration link after publication; surface verified workflow proof near download; add desktop App Store QR; group support pages separately from acquisition entry points | 0.5–1 day |
| 8 | Create `/blog/track-days-in-country-iphone/` | “track days spent in each country iPhone” | Country Days setup, recorded/manual dates, travel-day/timezone example, gaps, CSV export and clear counting rules | 1–2 days after release/workflow check |
| 9 | Improve existing Obsidian article; then verify Dawarich | Use location records in another system | Add only verified plugin/mobile/scheduling behavior; publish Dawarich integration only after actual receiver persistence test | Estimate after checks |

Order 1 corrects misleading buying information. Order 2 has the strongest existing page-level visibility evidence. Order 3 is closest to the paid export workflow. Order 4 is the first genuinely new acquisition task. If release verification blocks migration, continue the journal/GPX/Watch improvements rather than publish unsupported instructions.

### New page brief: Google Timeline migration

**Title:** How to Import Google Timeline into iso.me on iPhone. **URL:** `/blog/import-google-timeline-iphone/`. **Primary action:** download/open the supported app version and preview an import. Import is free in current source; clearly separate paid re-export.

Cover one complete task:

1. Identify the app version and supported JSON variants. Link Google's official iPhone export instructions; distinguish current device export from legacy Takeout archives.
2. Save the original archive to Files and keep a separate unchanged copy. Unzip Takeout before selecting individual JSON files.
3. In iso.me, open Settings → Data Import → Import File. Show format, date range, invalid/unsupported counts, new records, duplicates, and selection controls.
4. Demonstrate preview cancellation and a confirmed import. Review a known date on the map/Timeline. Reopen the same synthetic fixture to show the duplicate result.
5. Explain single-file limits: 50 MiB and 250,000 visits plus points; no ZIP/folder import; raw-history points do not create visits; untimed waypoints are not invented.
6. Address unsupported archives, empty results, and approximate duplicate matching. Avoid implying a lossless replica of every Google activity or label.

Use a clearly synthetic downloadable fixture from the existing test format. Supplement existing simulator QA with the supported public build and sanitize screenshots. Link in from comparison, history article, export reference, homepage task section, and blog hub. Link out to comparison (whether to switch), backup (keeping records), and GPX (using routes). Keep export-only Google questions in this walkthrough initially instead of creating three overlapping migration pages.

### New page brief: country-day journal

**Title:** How to Track Days Spent in Each Country on iPhone. **URL:** `/blog/track-days-in-country-iphone/`. **Primary action:** try the free Country Days view once verified as available.

Current source has `CountryDaysView`, `CountryDayResolver`, `CountryStay`, and `CountryDayTests`. Verify the public version before promotion. Show Timeline → Country Days, period filters, country detail, and adding a manual stay. Demonstrate a synthetic cross-border trip: dates use location timezones; a travel date can count in both countries; repeated evidence for one date is deduplicated; unknown locations and gaps are not filled; open/unverified visits contribute only arrival dates. Show what Analyze saved locations sends through Apple geocoding and how network opt-out changes the result. Country-day CSV writing uses the export purchase.

This is a personal travel record page. Describe its actual counting rules and avoid presenting its totals as an official immigration, tax-residency, or visa calculation. Link to the history/setup guide, privacy reference, and export reference. Add deeper calculation pages only if distinct supported tasks and query demand appear.

### Improve existing pages without creating duplicates

- **Journal:** preserve the URL and answer immediately. The page already has setup, privacy and backup sections; replace illustrative evidence with a checked outing instead of adding more generic introduction. Keep the free-download CTA after demonstrated value and at the end.
- **Google comparison:** owns choosing a recorder, not the entire import tutorial. Acknowledge Google's device history and encrypted backup. Use its official docs and test dates. A Google account reset or export format alone proves nothing about competing security designs.
- **GPX:** owns recording/exporting a route. Name the viewer only after opening the actual exported track. Use a public route or a sanitized isolated recording, not private home coordinates. The current synthetic XML fixture is useful, but it is not evidence of a full app workflow.
- **History:** owns finding existing records; answer Apple and Google questions before offering future recording or import. Do not redirect every problem to a purchase.
- **Backup:** owns preservation and restoration; demonstrate saved records on a clean destination and distinguish GPX map files from importable records. New duplicate handling needs a release/version note.
- **Watch:** keep the existing reference URL as the intent owner. Add evidence to it before creating a separate competing Watch article.
- **Obsidian:** the existing page owns manual Markdown handoff. README links an iso.me Maps plugin, but plugin existence alone does not verify its current compatibility or mobile/scheduled delivery. Extend this page after testing before adding `/integrations/obsidian/`.
- **Shortcuts and places:** current source includes new manual-visit actions while docs still advertise nine actions. Reconcile the existing references with the released action set. Later add one real check-in/check-out recipe if supported queries justify it.

## Practical rollout

| Period from kickoff | Work | Completion evidence |
| --- | --- | --- |
| Days 1–2 | Public-version and pricing reconciliation; correct relevant pages; acquire baseline/indexing snapshot; specify outbound events and Apple campaigns | Release/version ledger, consistent copy, recorded measurement contract |
| Days 3–7 | Journal and GPX proof improvements; migration walkthrough if supported | Reviewed screenshots and sample, working import/export path, internal links, page-level download tracking |
| Week 2 | Backup and Watch validation; tune homepage/hub discovery; refresh history instructions | Checked restoration/transfer results, live link checks and sitemap, original pre-release baseline preserved |
| Weeks 3–4 | Review actual queries and indexation; publish country-day guide if verified and still the best product-fit next task | Source/build availability, counting example, distinct intent, no duplicate title/topic pages |
| Days 31–60 | Improve pages earning relevant impressions; select one integration or locale experiment | Evidence-based selection, explicit hypothesis and equal-window results |

This is a focused backlog, not a commitment to publish daily. New pages should add a distinct task and first-hand proof. Google recommends useful, original content; page count and publishing cadence do not establish quality.

## Weekly decision rules and expansion gates

Use Search Console at the **query + page** level. Check whether an intended URL earns relevant impressions; fix indexing or answer mismatch before multiplying articles. At the present scale, one zero-click query or one high position does not establish a winner. Compare equal scoped windows after allowing for reporting lag, and retain the pre-release baseline.

- Relevant impressions but weak positions: improve the actual answer, supporting evidence and related links first; create a URL only for a materially different task.
- Visible relevant queries but few clicks: review title/snippet and intent. Do not conclude the title caused low CTR from a handful of impressions.
- Organic visits without outbound clicks: inspect task completion, product fit, CTA timing and free/paid clarity.
- Outbound clicks without visible installs: check campaign validity, reporting thresholds, and App Store message match before concluding the page fails.

At day 30, success first means key pages are discoverable/indexable, workflows match the app, and acquisition can be measured. At day 60, assess relevant nonbrand exposure, clicks and attributable installs, with sample sizes stated. Set business targets after usable conversion data exists instead of promising Vaultaire's reported conversion rate.

**Localization:** the current website is English-only. Select one language using reliable App Store demand, meaningful Search Console evidence, and available language QA. There is not enough country data in the baseline to choose Spanish, Polish, or another language on SEO evidence alone. Translate a small coherent cluster: homepage, journal, best-performing acquisition page, and relevant help/navigation. Use separate localized URLs, reciprocal `hreflang`, self-canonicals, and a language selector. Do not launch 32 languages at once.

**Tools:** defer a browser GPX/GeoJSON viewer until file-viewing queries or support needs justify it. If built later, process files locally and make its link to the recorder useful. Generic QR/image converters are a weak fit here.

**Integrations:** keep [Dawarich](dawarich-guide-verification-2026-10-26.md) on hold until protocol, authentication and destination persistence are tested. A successful connection response does not demonstrate stored route data. Avoid speculative best-app roundups or competing scenario pages until actual product tests and demand justify them.

**Authority:** make the verified examples and synthetic fixtures useful enough to cite. Link the documentation from the public repository and related product documentation where helpful. Outreach or community messages are a separate action; none were sent or scheduled. No backlink count or authority score was measured.

## Execution locations and acceptance criteria

New articles: edit `marketing/content/` and metadata/related links in `marketing/scripts/build_seo_pages.py`. Docs: edit `marketing/scripts/build_docs.py`. Homepage, blog hub and original journal: direct HTML. Rebuild with `python3 marketing/scripts/build_site.py`; run `python3 marketing/scripts/check_site.py`. Follow [the website README](../marketing/README.md).

For each material page change: immediate useful answer, distinct intent, current supported version, checked screenshots/steps, relevant sources, truthful free/paid boundary, contextual next steps, working App Store CTA, mobile-readable tables/images, title/description/canonical consistency, appropriate structured data, and sitemap inclusion. Check deployed status separately from build success. Preserve existing URLs and only update review dates for actual reviews/changes.

## Sources and limits

- Live [homepage](https://isome.isolated.tech/), [blog](https://isome.isolated.tech/blog/), [comparison](https://isome.isolated.tech/compare/google-maps-timeline/), [export reference](https://isome.isolated.tech/docs/export-import/), and [sitemap](https://isome.isolated.tech/sitemap.xml). Direct crawl, October 26, 2026; basic delivery/link audit only.
- [Public App Store listing](https://apps.apple.com/us/app/iso-me/id6761960794) and [US public lookup](https://itunes.apple.com/lookup?id=6761960794&country=us). Lookup version differs from cached search extraction; neither maps every feature to a released binary.
- Existing [Search Console baseline](search-console-baseline-2026-10-26.md), [Vaultaire analysis](vaultaire-seo-analysis-2026-10-26.md), [import QA](qa/google-timeline-import.md), and current app source. Saved QA is prior evidence; no new device test was run for this planning request.
- [Google Timeline iPhone help](https://support.google.com/maps/answer/6258979?co=GENIE.Platform%3DiOS&hl=en), [Apple campaign links](https://developer.apple.com/help/app-store-connect-analytics/acquisition/campaign-links), [Google helpful-content guidance](https://developers.google.com/search/docs/fundamentals/creating-helpful-content), [localized-page guidance](https://developers.google.com/search/docs/specialty/international/localized-versions).

No new private Search Console report, backlink dataset, keyword-volume study, conversion dataset, or performance benchmark was collected in this review. The saved baseline is clearly historical; the live audit is current to the check date.
