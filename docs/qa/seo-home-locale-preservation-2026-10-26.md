# Keep the published Chinese homepage in the main release

October 26, 2026. This protects an already-published URL; it does not select a
new localization experiment or claim Chinese search demand.

## Finding and provenance

The live sitemap has 31 pages including `/zh-hans/`, but this checkout at
`cc2df50` contained only 30. Its immediately preceding deployment URL
`ab83f375.spotted-8ez.pages.dev` likewise has 30 sitemap entries. Releasing
that incomplete source again could remove the live locale.

Recovered the existing Chinese HTML from
`/Users/codybontecou/dev/iso.me/marketing/public/zh-hans/index.html` by reading
and copying that file only. The preserved checkout was not edited, reset,
staged, or merged wholesale. Source SHA-256:
`155d1290b5f0c86a5789f926192487d00837b324a6f6fb10217085c80dc3bedc`.
The live URL already returned HTML 200 with `lang="zh-Hans"`; its negotiated
Markdown also returned 200 before this work. These are existing capabilities
being made durable in main, not new exposure or retrieval results.

## Change

- Track the existing `/zh-hans/` introduction in main. Preserve its design and
  copy, adding a verified 1.7.16 scope note and an explicitly English Terms link.
  The normal builder normalizes its two App Store links and adds the existing
  gated acquisition listener; no new campaign or identifier is introduced.
- Add English/Chinese/x-default alternate links and a Chinese reader link to
  the current English homepage, retaining the newer English guides, campaigns,
  and layout work. The Chinese page already links back to English.
- Generate the Chinese Markdown, worker page map, and sitemap entry through
  the normal build. Document language scope in llms.txt and the marketing README.
- Add release checks requiring both homepages, exact home-language declarations,
  the complete reciprocal alternate set, and visible reader language links.
  Every HTML page must also have a syntactically well-formed language tag.

The guard covers the checked main build/deploy workflow; it does not enforce
an account-wide prohibition on manual deployments from unrelated checkouts.
Detailed guides and legal pages remain English and are labelled as such in
the Chinese introduction. Website language is separate from native app language
or regional App Store availability. No additional language cluster was created.

## Product and primary-source review

Apple's public US lookup was rechecked during this task:
`https://itunes.apple.com/lookup?id=6761960794&country=us` still reports 1.7.16,
released `2026-10-26T15:37:00Z`. Existing source/build mapping remains the basis
for its verified build 46 facts. The Google import article remains a draft.
The Chinese page's free recording, optional export unlock, US example prices,
privacy boundaries, and lack of Google importer match that verified release.

Google's [localized-version guidance](https://developers.google.com/search/docs/specialty/international/localized-versions)
was checked October 26, 2026 for self/reciprocal fully-qualified alternate
links and the x-default fallback. HTML annotations are used; no duplicate
sitemap annotation scheme or automatic language redirect was added.

## Verification

- Build: 32 HTML pages including 404; 31 Markdown pages; 1,095 local targets;
  metadata, JSON-LD, IDs, sitemap, and `git diff --check` pass.
- In an isolated temporary copy, the valid site passes and each of four faults
  fails: missing Chinese page, missing English alternate, missing reader switch,
  and empty HTML language. No working-tree files were changed by fault injection.
- All five acquisition privacy/validation tests pass. The existing campaign
  configuration is retained; the Chinese download links use the generic
  canonical App Store URL, not an invented campaign.
- Both homepages fit 320 and 390 px browser viewports with matching document
  widths. Chinese headings, English switches, Terms link, and loaded product
  screenshot were inspected.
- Local Lighthouse 13.5.0: all four categories score 100, mobile and desktop,
  on both language homepages. Reports:
  `/private/tmp/isome-seo-locale-preservation-before/`.

No ranking, Google indexation, native app language support, human translation
review, or field-performance result is claimed.

## Legacy routing handoff

The initial main release `845d4bb` deployed successfully as `4e30fff8`, but the
public Chinese page continued serving its older copy for several minutes while
the exact deployment URL served the new version. Cloudflare configuration
identified three `search-chinese-landing-pages` Worker content routes overriding
Pages: the exact HTTPS homepage, `/sitemap.xml*`, and `/zh-hans*`.

Confirmed that Pages project `spotted` already owns the `isome.isolated.tech`
custom domain and that its complete 31-page release was available before the
handoff. Saved [the rollback snapshot](../seo-legacy-home-route-snapshot-2026-10-26.json),
re-read and matched each route ID/pattern/script, then retired only those three
routes. [The result](../seo-home-route-retirement-2026-10-26.json) confirms all
other 28 zone routes are unchanged, including the search verification routes.
The shared Worker itself and other sites were not deleted or modified.

The live Chinese page immediately served the main release's version note and
Terms link after the handoff. Browser checks confirm exactly three home-language
alternates on each homepage, the English language switch, nine English guide
cards, six retained seo-home campaign links, and integrations/places discovery.
All 31 production HTML/Markdown pairs and response/cache/error/API/method/asset
checks pass. No account permissions, DNS, or billing configuration changed.

Current primary references: Cloudflare's [route configuration](https://developers.cloudflare.com/workers/configuration/routing/routes/)
and [delete-route API](https://developers.cloudflare.com/api/resources/workers/subresources/routes/methods/delete/).

## Cold-image layout correction

The first production audit retained a real failure: Chinese desktop performance
95, CLS 0.134, while accessibility/best-practices/SEO were 100. Lighthouse's
layout-shift details identify the hero image as lacking an explicit display
size, moving the adjacent text. Mobile CLS was 0.060 despite its rounded 100
performance score. Reports are retained in
`/private/tmp/isome-seo-locale-preservation-after/`.

Reserved the existing approximate display box explicitly: 240×520 px desktop,
194×420 px mobile, with object-fit containment. The artwork, copy, and overall
design are retained. A controlled browser check with the image initially
unavailable (naturalWidth 0), then loaded (480), shows identical image and text
bounds at 320 and 1280 px. Local Chinese mobile/desktop Lighthouse both score
100 in every category with CLS 0. Reports:
`/private/tmp/isome-seo-locale-image-before/`.
