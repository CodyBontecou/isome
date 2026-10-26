# Google discovery check: Dawarich and the preserved Chinese homepage

October 26, 2026. Follow-up through the owner's authenticated Search Console
session, scoped to `https://isome.isolated.tech/`.

## Report availability and discovery

The dedicated property's overview still reports performance, indexing,
experience, and enhancement data as processing. These values are unavailable,
not measured zeros. The submitted sitemap remains Success, last read October
25, with 17 discovered pages. The live sitemap now contains 31 URLs, including
both URLs below. A stale discovery count is not a count of indexed pages.

Individual index inspections report both URLs as **URL is unknown to Google**,
with no last crawl, referring page, or referring sitemap reported:

- `/integrations/dawarich/`
- `/zh-hans/`

These are reported index states at inspection time, not proof that the site
has no working internal links or sitemap entries. The new Dawarich guide was
published today; the Chinese homepage was already live and was reconciled
into main today. No crawl-delay cause is inferred from this small sample.

## Google live tests

| URL | UI test time, October 26 | Availability | Crawl allowed | Fetch | Indexing allowed | Declared canonical |
| --- | --- | --- | --- | --- | --- | --- |
| `/zh-hans/` | 6:07:06 PM | URL is available to Google | Yes | Successful | Yes | Same inspected HTTPS URL |
| `/integrations/dawarich/` | 6:08:07 PM | URL is available to Google | Yes | Successful | Yes | Same inspected HTTPS URL |

Both tests used **Google Inspection Tool smartphone**. UI times are reproduced
as displayed; their timezone was not independently established. The Dawarich
test detected one valid Breadcrumbs item. Google's selected canonical is only
determined after indexing. A successful live test does not establish indexing,
ranking, search traffic, or a crawl-queue submission.

Independent HTTP checks with the established `iso.me-site-verification/1.0`
user agent returned 200 for both pages, their exact self-canonicals,
`index,follow`, no `X-Robots-Tag` header, and inclusion in the 31-URL sitemap.
An initial generic urllib request received 403; it is retained as a client
limitation, not described as a Googlebot failure. Google's own live fetches
succeeded.

The previous approvals and accepted requests for Country Days, comparison,
history, and GPX are preserved. No duplicate request for those pages was made.
Indexing requests for these two different URLs require separate explicit
approval under the earlier automatic-review decision. Approval was requested
after both live tests passed; submission remains pending the owner's answer.
No CAPTCHA was encountered or completed during these inspections.

Local evidence is retained outside the public release at
`build/seo-evidence/discovery-20261026/`. No website asset, app binary, campaign,
scheduled automation, DNS record, permission, or collector was changed.

## Next decision

If approved, submit each of these two URLs once and record Google's response.
An accepted request still does not establish completed indexing. Leave the
successful sitemap submission in place. Wait for actual reporting updates
before judging the new cluster's visibility or changing titles based on this
unavailable data. The Google-import acquisition article remains release-gated.
