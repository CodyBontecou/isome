# Whereday Search Console migration

Completed October 26, 2026 in America/Puerto_Rico. Final observation at
2026-10-27 00:09 UTC (October 26, 8:09 PM locally). Google's move page displays
“Date started October 27, 2026”; this is retained as its UI date, not substituted
for the user's local date.

## Ownership

Reused the existing authenticated Google and Cloudflare sessions, preserving
their identities. The new domain was absent from the initial property list.
Added `sc-domain:whereday.com` and selected manual TXT verification. No Google
authorization to administer Cloudflare DNS was granted.

Added one root TXT record with TTL Auto in the Whereday zone. Existing apex
and www CNAME records were left unchanged. Public DNS lookup confirms the
Google verification value, and Search Console explicitly reported
**Ownership verified**, method **Domain name provider**. Keep that TXT record
to retain ownership. No password, private token, or verification email was used.

## Sitemap

Submitted `https://whereday.com/sitemap.xml` once to the domain property.
Google confirmed **Sitemap submitted successfully**. The first list view
briefly reported Couldn't fetch / Unknown / zero discovered pages; its detail
view subsequently reported **Sitemap processed successfully**, last read
10/26/26, **31 discovered pages**, and zero videos. No duplicate submission or
configuration change was made to produce that later result. The cause of the
transient initial status was not established. An independent live fetch
returned HTTP 200, application/xml, and 31 URL entries.

Discovered pages are not confirmed indexed pages. Performance and indexing
reports still say data is processing; they are unavailable, not zero results.

## Change of Address

Used Settings → Change of address in the verified
`https://isome.isolated.tech/` property, selecting the verified
`sc-domain:whereday.com` destination. Google's required validations passed:

- 301 redirect from the old homepage.
- Ownership verification for both sites.

Confirmed the move once under the owner's explicit Search Console migration
request. The old property now reports **This site is currently moving to
whereday.com**, with a Cancel Move control. The Whereday overview reports
**1 of your other sites is moving to this site**. These are accepted move
notifications, not proof that Google has finished recrawling or reindexing.
Only this product's subdomain was moved; the parent isolated.tech property and
other products were not migrated or removed. No individual URL indexing
requests, removal requests, Google account access grants, or scheduled jobs
were created. Existing historical property data and sitemap were retained.

## Evidence and follow-up

Screenshots remain local under
`build/seo-evidence/whereday-search-console-20261026/`:
`ownership.png`, `sitemap-submitted.png`, `sitemap-success-31.png`,
`validation-passed.png`, `move-started.png`, `destination-notice.png`.
Both Google property tabs were kept as user-facing deliverables.

Keep the verification TXT and existing direct path-preserving redirects.
Google's site-move guidance recommends keeping redirects generally at least
one year; no redirect expiration or automated cleanup was added. Review the
new property's indexing/canonical reports and relevant queries after reporting
lag, retaining separate old-property baselines. No ranking retention, traffic
improvement, or completed index migration is inferred today. No further site
deployment or native app release was needed for this task.

Primary guidance checked:
- https://support.google.com/webmasters/answer/9370220?hl=en
- https://developers.google.com/search/docs/crawling-indexing/site-move-with-url-changes
