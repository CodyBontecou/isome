# SEO implementation and release results

October 26, 2026. Implements the available first release of [the prioritized plan](isome-seo-priorities-2026-10-26.md). Later product releases, physical workflow checks, and traffic observation remain separate gates; this does not claim the full 60-day plan is finished.

## Deployed

Production: **https://isome.isolated.tech/**. Cloudflare Pages project: `spotted`. Final deployment: `9b4b2698` ([snapshot](https://9b4b2698.spotted-8ez.pages.dev)). Prior production before this batch: `9770175a`. The site now has 28 sitemap pages plus its excluded 404 template.

- Published [Track days spent in each country on iPhone](https://isome.isolated.tech/blog/track-days-in-country-iphone/), with counting rules, travel-day and timezone examples, manual stays, geocoding boundaries, CSV limitations, current app UI, and links to setup/backup help.
- Linked the guide from the homepage, guide hub, original journal article, and Timeline reference. Added a download CTA after the journal setup steps and clarified background-permission wording.
- Added a locally generated App Store QR image and a desktop-to-phone download path. It uses the existing official app URL.
- Added explicit public-build scope to Google comparison, history, export, and backup instructions. The published limitations were accurate for the released binary even though development source had advanced.
- Reconciled README US prices and removed blanket no-analytics/no-dependencies wording that conflicted with the actual product. The website's existing prices were confirmed, not changed in App Store Connect.
- Added gated first-party acquisition counters, strict server validation, a separate aggregate D1 table, reporting SQL, privacy disclosure, public API contract, deployment migration step, and regression checks.
- Prepared the Google import article in `marketing/content/import-google-timeline-iphone.html`, with release-preview metadata and an outside-public preview command. The normal build rejects an accidentally deployed draft file. The live migration URL intentionally returns 404.

## Release findings

App Store Connect confirms **1.7.16 build 46** as publicly distributed. The archive source checkout was clean at `6ae78e622c72ee051e6f14113082556c398d926a`. That revision contains Country Days and predates Google Timeline import commit `0b7d5c6`. The current checkout targets 1.7.17; it was not released as part of this website task.

Current US lifetime prices: Individual $19.99, Family $39.99, Family Upgrade $19.99. Other storefronts vary. Machine-readable, non-secret facts are saved in [the release snapshot](seo-release-facts-2026-10-26.json).

Country Days UI was opened in the existing test simulator. Its captured development build is 1.7.17 (47), iOS 26.5; the public guide labels that fact. It shows zero resolved country dates. The counting example is invented, not a newly recorded cross-border trip. Its WebP image is approximately 53 KB.

## Measurement contract

`POST /api/v1/acquisition` accepts only `page_view` or `app_store_clicked`, an exact known public page path, a fixed placement, and a coarse referrer category. It rejects cross-origin/form requests, unknown fields/pages, and bodies over 512 bytes. The browser waits for the existing analytics exclusion gate, fails closed, and honors GPC/DNT. Requests omit credentials and referrer headers.

The `website_acquisition_daily` table stores UTC day, event, public page, placement, source category, and count. No event-level log, user ID, cookies, browser storage, location file, coordinates, free text, full referrer, or query string is stored by this collector. It shares the existing D1 database but uses a separate table and never writes onboarding records.

Page loads and activations are not unique visitors, installs, purchases, or an organic session conversion rate. The source category is per-page referrer context; the code does not preserve the original acquisition source through internal navigation. Excluded browsers, early exits, network failures, and automated requests limit interpretation. No synthetic valid event was inserted into production to inflate counts.

Apple campaign links are now configured after explicit owner approval. An existing
signed-in App Store Connect browser session was used to generate `seo-home`,
`seo-private-journal`, `seo-google-timeline`, and `seo-gpx`. Each returned the
genuine public developer provider token `126424970`. The approved links are
applied to all download anchors on their four respective pages, including
header/footer anchors. The homepage QR was regenerated for `seo-home` and its
URL consistency is enforced by the build. Unmeasured pages and product metadata
keep the canonical App Store URL.

Automatic review initially blocked opening campaign generation, after which the
owner explicitly authorized creating and applying the four links. That blocker
is resolved. No credentials or session tokens were copied into the repository.
Apple still reports insufficient campaign data; generation is not evidence of
installs, and its reporting thresholds/delays still apply.

Report with the SQL command in [the website README](../marketing/README.md). No recurring automation was created.

## Verification

- Build: 29 HTML pages, 950 local targets, metadata, JSON-LD, canonical URLs, IDs, and sitemap coverage pass. Consecutive builds produce identical public assets.
- Acquisition regression tests: five tests covering valid counts, invalid/private dimensions, methods/origins/body bounds, unavailable binding, GPC/DNT, exclusions/gate failures, preview suppression, and no-referrer requests pass.
- Local Pages + real local D1: one page view and two activations produce two daily rows with counts one and two. These are local test data only.
- All 28 production HTML/Markdown pairs, cache separation, API representation/method behavior, missing-page responses, and asset integrity passed the HTTP checker.
- Production guide, listener, and QR returned 200 with the verification user agent; held migration URL returned 404. The live collector returned 400 for an intentionally invalid path without storing it. Generic Python requests sometimes received edge 403s; the verifier and actual Chrome loads succeeded.
- Mobile browser: homepage, journal, and new guide fit a 390-pixel viewport with no page-level horizontal overflow or broken images. The new guide's mobile Lighthouse accessibility, best-practices, SEO, and agentic-browsing scores were 100. That audit excludes performance; no new production Core Web Vitals claim is made.
- Existing public JSON samples still pass the actual Swift importer: two visits, three points, expected values, and rejection of an incomplete visit. This is parser compatibility, not a new device restore test.
- Google Search Console's live URL test reports **URL is available to Google / Page can be indexed**, with one valid Breadcrumbs item. A subsequent request confirmed **Indexing requested / URL was added to a priority crawl queue**. Google completed its verification automatically; no CAPTCHA was solved. Indexing or ranking is not yet established.

Screenshot of the live mobile guide is retained locally at `build/seo-evidence/country-guide-mobile.png` (ignored build output). Search performance still uses the preserved September 27–October 24 baseline; it has not been recast as results of this deployment.

## Remaining work and publication gates

Follow-up on `main`: the GPX guide now includes a reproducible synthetic file
from the actual released GPX serializer, a checked gpx.studio example, and a
screenshot showing both segments. See [the GPX evidence record](qa/seo-gpx-viewer-2026-10-26.md).
This advances file/viewer evidence; the physical recording and sharing checks
below remain open.

The backup guide now has verified Safari sample-download behavior and a
destination verification checklist. The isolated 1.7.16 simulator rebuild did
not present its file picker, so no clean-destination restore or persistence
success is claimed. See [the restore attempt](qa/seo-restore-verification-2026-10-26.md).

The Obsidian guide now includes an exact Markdown file generated through the
released 1.7.16 export pipeline, native parser assertions, and a checked desktop
vault example with screenshot and wiki-link navigation. Production HTTP checks
pass and mobile/desktop Lighthouse scores are all 100. See
[the Obsidian evidence record](qa/seo-obsidian-export-2026-10-26.md).
Mobile transfer, plugins, and scheduled delivery remain separate gates.

The Siri and Shortcuts reference and homepage now match the released action
set: twelve App Intents, nine built-in phrase registrations, and one configurable
Export Data action. The reference includes date defaults, error recovery, and a
source-reviewed Markdown recipe. All 48 existing native logic tests pass;
production HTTP checks and mobile/desktop Lighthouse checks pass. A shared docs
footer overflow was also corrected. See
[the Shortcuts verification record](qa/seo-shortcuts-reference-2026-10-26.md).

The private-journal guide now has a checked Start/Stop/Timeline example showing
an eight-second outing with zero points, plus a concrete Points/Path checklist
and troubleshooting link. This verifies recording controls and empty-path
behavior, not a successful physical route. The duplicate adjacent download CTA
was removed while retaining the campaign. Site checks and mobile/desktop
Lighthouse pass. See [the recording-state evidence](qa/seo-journal-recording-state-2026-10-26.md).

The Dawarich Overland receiver gate has now been checked with real native HTTP
delivery and database persistence across receiver/database restart. Published
the versioned `/integrations/dawarich/` walkthrough and a small integration
directory, with a synthetic payload and receiver screenshot. Twenty-two native
tests and five acquisition/privacy tests pass; all six changed pages pass
mobile/desktop Lighthouse. The temporary receiver runtime and credentials were
removed after evidence capture. See [the receiver record](qa/seo-dawarich-receiver-2026-10-26.md).
Production deployment `998d16ed` passes all 30 HTML/Markdown pairs, exact sample
and screenshot checks, and all-100 mobile/desktop Lighthouse on both new pages.
The new URLs are in the sitemap; no new Google indexation or ranking is claimed.

The places reference now reflects released Saved Locations management, direct
coordinate entry, 25–10,000 m radii, and the separate CSV importer. A synthetic
two-place sample passes native parsing/storage and duplicate checks while
preserving historical visits. The editor was checked with location permission
denied; no complete UI save or file-picker import is claimed. All 29 selected
native tests pass. See [the places evidence](qa/seo-saved-locations-2026-10-26.md).
Apple's live lookup still reported 1.7.16 on this recheck, so the Google import
article remains a draft; revisit its release gate when the public version changes.
The places update is live in deployment `ec2c0058`. All 30 HTML/Markdown pairs
and exact sample/screenshot checks pass; the reference and its changed
Timeline/outings neighbor score 100 in all mobile/desktop Lighthouse categories.

The location-history guide now answers with concrete app/date paths, separates
Significant Locations settings from saved app history, and includes a
preservation checklist and practical questions linked to checked places and
recording-state examples. Apple/Google instructions were reviewed against their
current primary help pages, with Apple iOS 26 context. No personal history was
accessed or new platform-UI/recovery success claimed. See
[the history-answer review](qa/seo-history-answer-2026-10-26.md).
Production deployment `731861fe` passes all 30 HTML/Markdown pairs and all-100
mobile/desktop Lighthouse on the revised guide. Its established title and URL
are retained; no duplicate indexing request or new search-performance claim
was made.

Repository and homepage discovery now surface the checked workflows. The README
has a user-guide directory and explicit development/public release boundaries;
the homepage task grid links integrations and saved places. All 15 README
product-site URLs return HTML 200. All 30 pages remain within two HTML links
of home, with Saved Places now directly linked. No outreach, third-party
backlink result, or ranking effect is claimed. See
[the discovery record](qa/seo-workflow-discovery-2026-10-26.md).
Production deployment `6bcef4e4` passes all 30 HTML/Markdown pairs and all-100
mobile/desktop Lighthouse on the homepage. Live checks confirm nine task cards,
the expected destinations, no mobile overflow, and retained campaign links.

The existing missing-history guide now includes the checked zero-point outing,
arrival-date and export-filter diagnosis, and four practical questions. The
export reference links directly to the diagnosis. Release-source review
confirms the filter semantics; no new physical recording or recovery is
claimed. See [the diagnostic review](qa/seo-missing-history-2026-10-26.md).
Production deployment `09d5b867` passes all 30 HTML/Markdown pairs and all-100
mobile/desktop Lighthouse on both changed pages, with live mobile layout
and content checks.

The backup guide now has released-source native disk import, store reopening,
and JSON re-export evidence. The two nearby fixture visits reconcile to one
saved visit, while repeating the point file appends its three points again.
The prior two-saved-visits expectation is corrected across backup, export, and
troubleshooting pages. All 22 selected native tests pass; file-picker/physical
transfer and app-process restart remain unverified. See
[the disk import record](qa/seo-backup-disk-import-2026-10-26.md).

1. Confirm a public app build containing Google import, repeat preview/import/duplicate checks against it, then promote the prepared article and update linked product claims together. Do not publish it merely because source exists.
2. Capture a real recording-to-GPX-to-viewer workflow, clean-destination restore, and physical Watch-only walk/transfer before claiming those specific workflows newly verified. Existing guides remain explicit about evidence limits.
3. Verify Obsidian plugin/mobile/scheduled delivery and Dawarich physical recording, complete settings workflow, production HTTPS, and unattended delivery before extending those promises. The Dawarich native batch/persistence test used only invented data and a local receiver.
4. Review relevant queries/indexation and acquisition counters after reporting lag. Choose further articles or a small localization pilot from meaningful demand evidence, not today's sparse sample.

No app binary, pricing, account permissions, or scheduled automation was changed. The external changes in this batch are the website deployments, separate aggregate table, approved Apple campaign-link generation, and Google indexing request.
