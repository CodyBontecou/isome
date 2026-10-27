# Whereday priority-page discovery and Google fetch checks

October 26, 2026 in America/Puerto_Rico. Follow-up to the accepted Change of
Address and successfully processed 31-page sitemap. This is a page-level
observation; it does not establish sitewide indexed counts or migration completion.

## Confirmed homepage indexation

Google URL Inspection reports https://whereday.com/ as **URL is on Google**
and **Page is indexed**. Its index details list the new-host sitemap, a
Googlebot smartphone crawl at Oct 26, 2026, 8:06:56 PM as displayed, successful
fetch, crawling allowed, and indexing allowed. The user-declared canonical is
the HTTPS Whereday homepage; Google's selected canonical is **Inspected URL**.
No indexing request was made for this already-indexed page.

The referring-page field includes an unfamiliar external URL. It was not
visited or treated as authority, a successful outreach result, or a cause of
indexation. This observation cannot attribute homepage indexation to the
recent move request or any particular SEO change.

## Priority article states

The journal, Google comparison, and GPX pages each report **Discovered -
currently not indexed**, with the Whereday sitemap listed and no recorded
last crawl. Their indexed-state canonical fields are unavailable. That is
different from a crawl block or a Google-selected old-host canonical.

Journal, comparison, and GPX Google live smartphone tests pass, with successful
fetch, crawling/indexing allowed, and the expected new-host declared canonical.
Journal test: Oct 26, 2026, 8:12:55 PM as displayed. Comparison test:
Oct 26, 2026, 8:13:42 PM as displayed. Google reports one valid Breadcrumbs item
for each. GPX test: Oct 26, 2026, 8:14:29 PM as displayed. A successful live test does not cause indexation or determine
Google's future selected canonical.

## Independent HTTP checks

All four priority URLs return HTTP 200, index/follow, an exact self-canonical,
and no X-Robots-Tag. Their old-host counterparts each return a direct 301 to
the matching new-host URL. The HTTP snapshot and raw Search Console views
are retained locally under `build/seo-evidence/whereday-google-crawl-20261026/`.

No website, DNS, CDN rule, app binary, campaign link, Google permission,
individual indexing request, removal request, or automation was changed in
this check. No content rewrite is justified by these fresh discovery states
alone. Keep redirects and verification in place, and revisit relevant
indexed states and search reports after processing lag.
