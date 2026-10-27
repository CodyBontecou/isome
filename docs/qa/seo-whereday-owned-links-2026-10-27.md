# Whereday owned GitHub listings after the site move

October 27, 2026, America/Puerto_Rico. Follow-up to the canonical-host migration.

## Findings and changes

The main app repository's About description still said “Source code of the
iso.me iOS app”, and its website field linked directly to the App Store. The
Maps plugin's website field was empty. The public US app lookup still returns
iso.me 1.7.16, so Google import publication and removal of the website's naming
clarification remain gated.

Updated only these public repository metadata fields:

| Repository | Field | New value |
| --- | --- | --- |
| CodyBontecou/isome | Description | Source code for Whereday (formerly iso.me), a private iPhone and Apple Watch location journal. |
| CodyBontecou/isome | Website | https://whereday.com |
| CodyBontecou/isome-maps | Website | https://whereday.com/blog/iphone-location-journal-obsidian/#map-plugin |

The plugin keeps its published iso.me Maps identity and existing description.
Its new link leads to the exact checked desktop Markdown/plugin example,
including synthetic inputs and remaining mobile/scheduled limits. Neither
repository was renamed. No plugin compatibility claim, release, source change,
permission, Apple setting, website deployment, message, or outreach occurred.

The connected GitHub tool set does not expose repository settings, so the
existing authenticated GitHub CLI performed the metadata edits. Fresh reads
of both repository listings match the intended values. Before/after records
are in [the snapshot](../seo-whereday-owned-links-2026-10-27.json).
Both target pages return HTTP 200 with matching Whereday canonicals; the
plugin's map-plugin anchor exists. Public browser views confirm both saved
About links and the main repository's new description.

Screenshots and API receipts are retained locally under
`build/seo-evidence/whereday-owned-links-20261027/`:
`app-listing.jpg`, `plugin-listing.jpg`, `before.json`, `after.json`.

## Scope and next gates

This completes two owned-profile links in the site-move follow-up. It is not
third-party editorial coverage, a measured backlink gain, or evidence of
ranking/traffic improvement. No payment or keyword-volume API call was made.

Google's official site-move guide recommends updating links and profile links
after the move:
https://developers.google.com/search/docs/crawling-indexing/site-move-with-url-changes#update-links

Further new acquisition content still needs relevant search demand and/or
first-hand workflow evidence. The supporting public Google import release,
physical recording and restore checks, and meaningful post-move performance
reporting remain the substantive gates. A missing public release should not
be treated as permission to publish the importer draft.
