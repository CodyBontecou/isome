# Acquisition-page indexing audit

Inspected October 26, 2026 after the SEO releases. This records Google Search
Console observations, not a new search-performance result.

## Findings

| Page | Google index status | Live test on October 26 | Next action |
| --- | --- | --- | --- |
| `/blog/private-location-journal-iphone/` | Indexed | Not repeated | Retain URL; assess later query/page performance |
| `/compare/google-maps-timeline/` | Unknown to Google; not indexed | Available to Google; page can be indexed | Request indexing when explicitly approved |
| `/blog/record-iphone-route-gpx/` | Unknown to Google; not indexed | Available to Google; page can be indexed | Request indexing when explicitly approved |
| `/blog/view-location-history-iphone/` | Unknown to Google; not indexed | Available to Google; page can be indexed | Request indexing when explicitly approved |

The three live tests each detected one valid Breadcrumbs item. Initial index
reports showed no recorded crawl, referring page, or sitemap association for
those URLs. These are Google's currently reported discovery fields; they do
not establish that the deployed website lacks internal links or sitemap entries.
The live tests establish availability, not index inclusion or ranking.

Comparison, GPX and history inspections used the existing domain property
`sc-domain:isolated.tech`. The journal inspection used the dedicated URL-prefix
property. Its indexed details still show the September 30, 2026, 5:37:50 AM
crawl, Googlebot smartphone, successful fetch, crawl/indexing allowed, and the
inspected URL as Google's canonical. This is an older indexed snapshot, not
proof that Google has fetched today's journal changes. UI times are reproduced
as displayed; their timezone was not independently established.

The dedicated property's sitemap still reports Success, last read October 25,
17 discovered pages. Today's production sitemap has 28 URLs. Discovery counts
are not index counts, and the differing dates matter. The dedicated property's
performance and overall indexing reports still say Processing data.

The Country Days indexing request accepted in the earlier release is preserved;
no duplicate request was made during this audit.

## Submission status

Automatic approval review rejected the comparison indexing submission because
it changes Google's crawl queue and requires explicit authorization. The owner
has been asked to approve requests for the comparison, GPX and history pages
after successful live tests. No request for those three pages was submitted in
this audit while that answer is pending. Approval for an earlier Country Days
request was not reused for these different submissions.

## Measurement repair and initial snapshot

The prior documented D1 `--file` command uses SQL-file import mode. It returned
execution statistics without SELECT rows. Added
`python3 marketing/scripts/report_acquisition.py`, which passes the existing
SQL in query mode as one `--command=` argument and emits JSON results. The
remote verification read rows with zero writes and no database changes.

The date predicate now spans exactly 28 UTC calendar dates, including today's
incomplete date. The former inclusive `now - 28 days` predicate included 29
dates. An in-memory SQLite boundary check confirmed inclusion of today and day
minus 27 and exclusion of day minus 28 and tomorrow.

At the snapshot, Country Days and the comparison each had two direct-category
page loads, with zero download activations. The other report rows were absent.
See [the aggregate snapshot](seo-acquisition-snapshot-2026-10-26.json). These four
loads may include verification/automated browsers. They are not unique people,
organic sessions, installs, or evidence of a conversion trend. Later live tests
can increase the counters. No valid synthetic events were manually posted.

## Decision

Prioritize discovery of the existing acquisition pages and release-gated
workflow evidence. The present data does not justify adding overlapping
articles, localizing the site, or changing titles in response to zero clicks.
Keep the original Search Console baseline and compare explicit equal windows
after reporting lag; do not treat today's deployment as a completed experiment.

Local inspection screenshots are retained under
`build/seo-evidence/indexing-20261026/` and excluded from the website release.
No public website assets or app binaries were changed in this audit.
