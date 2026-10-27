# Whereday host migration and main integration

October 26, 2026. The parallel rename changes the SEO operating base. The
original host-preservation recommendation is superseded by the owner's approved
rename and domain move; historical measurements retain their original scope.

## Approved integration

The owner explicitly approved merging PR #85 in the SEO chat. Its reviewed
head was `dc4330d78febcbe24e9cf1ea45b853126ed601f5`, with a passing IsoMe XCTest
CI check. Marked the draft ready and merged with a matching-head requirement.
GitHub confirms merge commit `1482f80d6aec56ed13b89bc040e4926b8879cf94`.
Fast-forwarded this clean SEO worktree on main; neither checkout was reset.
The parallel Whereday checkout remains untouched. Coordination was authorized
by the owner and acknowledged to the rename chat.

The existing live deployment from the rename checkout is `64fa727e`. This turn
did not publish another site deployment or submit/release anything to Apple.
Future website work must use Whereday main, with canonical https://whereday.com.
Historical exported fixtures, raw screenshots, protocol/bundle/purchase IDs,
and pre-rename release evidence remain unchanged where needed.

## Read-only live migration audit

Machine-readable results: [host audit](../seo-whereday-host-migration-2026-10-26.json).

- All 31 sitemap URLs are on whereday.com.
- Each old-host page returns a direct HTTP 301 to the matching new-host path.
- Every new-host page returns HTML 200, one H1, and its expected self-canonical.
- Every page returns Markdown 200 with the expected media type and new-host
  Source URL. Markdown links do not point back to the old host.
- Both homepages have reciprocal en/zh-Hans/x-default alternates on the new host.
- Every page retains an App Store link. The homepage proof section retains its
  three guide anchors and genuine seo-home campaign links.
- Additional direct 301 checks pass for a guide query string, the exact GPX
  sample, sitemap, robots, and product metadata endpoint. Paths and the probe
  query string are preserved. Robots names the new-host sitemap.

Production browser inspection confirms Whereday navigation, new-host canonical,
and preserved checked-example links. Screenshot:
`build/seo-evidence/whereday-host-migration-20261026/live.png`.

Merged-source build passes: 32 HTML pages including 404, 31 Markdown pages,
1,124 local targets, metadata, JSON-LD, IDs, sitemap, and blog inventory.
All 12 Python marketing tests and six acquisition/redirect tests pass. The
normal rebuild leaves public output unchanged. The merged response checker also
passes all 31 production HTML/Markdown pairs and its existing API/error/cache/
method/asset contract on whereday.com.

## Remaining SEO work

Check the Whereday Search Console property, new-host sitemap submission, and
Google's site-move workflow where supported. These were not performed in this
audit. Old-property indexing approvals are not reused as new-URL submissions.
Direct HTTP/metadata checks do not establish Google's indexation or retention
of search signals. Keep pre-rename and post-move reporting scopes separate.

Apple's US public lookup still reports iso.me 1.7.16, released at
2026-10-26T15:37:00Z. The new 1.7.17 build 48 remains a separate App Store draft.
The prepared Google import article stays gated until a supporting public build
and its import workflow are verified. Physical GPX/restore/Watch and mobile or
scheduled integration checks remain open.

## Search Console follow-up

The subsequent owner-requested migration verified Whereday by DNS, processed
the sitemap with 31 discovered pages, and started the Change of Address from
the old product subdomain. Both properties display the accepted move. See
[the Search Console record](seo-whereday-search-console-2026-10-26.md).
Indexing and performance data remain processing.
