# Obsidian Maps compatibility: released parser and desktop UI

October 26, 2026. Follow-up to the existing manual Markdown guide. No new
integration page is needed; the existing manual Markdown guide owns this task.

## Released plugin and exact fixture

The former repository URL redirects to
<https://github.com/CodyBontecou/isome-maps>. Public release **0.7.15** was
published June 12, 2026. Its tag and inspected main both resolve to
`90259972c5c5f103fb11bae8ebd1195412aa22b9`. The manifest requires Obsidian
1.12.0 and is not marked desktop-only; this is metadata, not a mobile test.

Downloaded release assets in `/private/tmp/isome-seo-maps-release-20261026/`
match GitHub's published SHA-256 digests:

| Asset | SHA-256 |
| --- | --- |
| main.js | f24123ec5f445f4521b96d2a550ea85149727cf011a834ed748b3d859e3e1935 |
| manifest.json | c8a479f6844e457986888694942828c1e43ed8c4e620c54a72f18b96c7c84016 |
| styles.css | b6ad46e58606f4977d47038ca990c5efe02bc218926b23238121c1b5d1fe30d7 |

These exact release assets were installed only in the approved synthetic vault
for the desktop test below; Restricted mode was restored afterward.

The exact existing native 1.7.16 Markdown sample remains unchanged:
`marketing/public/samples/synthetic-obsidian-export.md`, SHA-256
`2d8798387dfebaaa479a6c961895c85aa8ad54f61c2e86d27d45006d6e487220`.
Only invented January 1, 2000 visits near (0, 0) are used.

## Executed parser checks

The release source was cloned into
`/private/tmp/isome-seo-maps-plugin-20261026`. Locked npm dependencies were
installed with lifecycle scripts disabled. The unchanged Markdown parser was
bundled with that checkout's esbuild, then run through the retained harness:

```sh
cd /private/tmp/isome-seo-maps-plugin-20261026
./node_modules/.bin/esbuild src/markdown-parser.ts --bundle --platform=node --format=esm --outfile=/private/tmp/isome-seo-maps-markdown-parser.mjs
```

From the iso.me repository root:

```sh
node docs/qa/fixtures/check-obsidian-maps-markdown.mjs /private/tmp/isome-seo-maps-markdown-parser.mjs
```

All assertions pass:

- Two visits, zero route-point collection (`points: null`).
- Exact coordinates (0, 0) and (0.0002, 0.0001), names, notes, and 15-minute durations.
- A derived negative control with Lat/Lon columns removed produces zero visits,
  without a parse error. This control is not a newly generated native export.
- The same Markdown clock time is interpreted in the parser host's timezone:
  the first arrival is `2000-01-01T11:45:00.000Z` under UTC, but
  `2000-01-01T15:45:00.000Z` under America/Puerto_Rico. Coordinates stay equal.

Markdown's displayed clock times lack an explicit offset. This parser result
does not prove a timezone-preserving archive or equivalent JSON behavior.
The plugin's date-heading parser recognizes English month names; no localized
native export was tested. Neither parsing success nor mobile-capable metadata
establishes that the plugin renders correctly inside Obsidian.

## Approved desktop test

Obsidian 1.14.5 is still open in the previously approved temporary vault
`/private/tmp/isome-seo-obsidian-actual-export-20261026`. Its existing synthetic
native Markdown note was visible in Reading view. Before approval, the
Community plugins screen showed **Exit Restricted mode**, explaining that
plugins can execute arbitrary code. No protection setting was changed before
approval.

The owner was asked for, and explicitly granted, approval to exit Restricted mode, enable
only iso.me Maps 0.7.15 in that test vault, and restore Restricted mode after
testing. This approval is required by the computer-use policy for changing
that execution protection, beyond the prior approval merely to open the vault.
Initial gate screenshot: `build/seo-evidence/obsidian-maps-20261026/restricted-mode.png`.

Installed the staged release, reloaded the plugin list, and enabled iso.me
Maps 0.7.15. A separate `Synthetic map check.md` points to the exact native
Markdown file through `source: Location/synthetic-obsidian-export.md`.

Observed real provider failures before choosing the final example:

- Default CARTO tiles rendered **API KEY REQUIRED**, with both visit markers
  still visible. The native screenshot is retained as `default-carto.png`.
- Esri World Imagery returned **Map data not yet available** at the automatically
  selected close zoom over the synthetic ocean coordinates. This does not
  establish a general provider outage or failure at other locations/zooms.
- OpenTopoMap returned **max zoom layer = 17** above its supported zoom.
  Explicit center, `auto_fit: false`, and `zoom: 17` rendered ocean tiles.

The final block includes `show_stats: true`, `show_visits: true`, and
`show_routes: false`. Reading view showed **MD, 2 visits, Jan 1, 2000 → Jan 1,
2000** and two circle markers. Each marker was clicked separately. Stop A
showed 11:45 AM → 12:00 PM; Stop B showed 12:02 PM → 12:17 PM. Both displayed
15-minute durations and the exact invented-data note. No route was expected.
The stats bar's rounded `0h` is retained in the screenshot; it is not used as
evidence of precise elapsed-time behavior.

`samples/synthetic-obsidian-map.md` is an exact copy of the tested map note.
`screenshots/obsidian-maps-synthetic.png` is the unchanged native screenshot
of the two-visit count, map, and Stop B popup. The coordinate fixture itself
remains byte-identical. No personal records or vault were accessed.

The test selected **Turn on and reload** after collecting evidence. Obsidian
reloaded the note as a plain code block. The Community plugins screen again
showed **Exit Restricted mode** and offered to restore the one previously
installed plugin, confirming execution protection was restored. State and
screenshot are retained as `restored-restricted.txt` and `.png` in the local
evidence folder. Plugin assets remain only in the disposable test vault.

The guide adds the optional tested desktop block, sample download, screenshot,
coordinate requirement, timezone behavior, and provider failures. It does not
promise iPhone transfer, mobile rendering, scheduled delivery, arbitrary date
locales, or a timezone-preserving Markdown archive. The provider receives tile
coordinates and request metadata; only invented coordinates were used here.

The negotiated Markdown build initially wrapped the displayed code block in an
equally long fence, corrupting the nested example. The converter now chooses
an outer fence longer than any run inside the content. Three regression tests
pass for ordinary, triple-nested, and longer fences; other page output retains
its existing fence when no longer fence is needed.

The build passes 32 HTML pages (31 public) and 1,109 local targets. Both changed
pages pass all-100 mobile/desktop Lighthouse locally.

## Publication

Guide release commit `75f5fe4` is on main and origin. Production deployment
`0e0f729e` (<https://0e0f729e.spotted-8ez.pages.dev>) serves the updated guide
and comparison. Both have all-100 mobile/desktop Lighthouse scores. Reports:
`/private/tmp/isome-seo-obsidian-maps-local/` and
`/private/tmp/isome-seo-obsidian-maps-production/`.

All 31 production HTML/Markdown pairs, cache separation, error recovery,
methods, product contract, and asset checks pass. The live guide exposes the
new section, metadata, sample, and loaded screenshot. The nested `iso-me` block
remains intact inside its longer fence in negotiated Markdown. Local layout
checks at 320 and 390 and a production 390-pixel check show no document
overflow. The two new public files match the tested local files byte-for-byte.
Live guide screenshot: `build/seo-evidence/obsidian-maps-20261026/guide-live.jpg`.

The native Markdown input remains unchanged. No new URL, Google indexing
request, campaign, app binary, mobile UI change, or scheduled task was created.
The isolated native Obsidian test required no simulator or physical device.
