# Obsidian Maps compatibility: released parser and pending UI check

October 26, 2026. Follow-up to the existing manual Markdown guide. No new
integration page or public compatibility promise has been published.

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

No release asset has been installed or enabled in a vault yet.

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

## UI gate and next action

Obsidian 1.14.5 is still open in the previously approved temporary vault
`/private/tmp/isome-seo-obsidian-actual-export-20261026`. Its existing synthetic
native Markdown note is visible in Reading view. The Community plugins screen
shows **Exit Restricted mode**, explaining that plugins can execute arbitrary
code. No protection setting was changed.

The owner was asked for explicit approval to exit Restricted mode, enable
only iso.me Maps 0.7.15 in that test vault, and restore Restricted mode after
testing. This approval is required by the computer-use policy for changing
that execution protection, beyond the prior approval merely to open the vault.
Screenshot: `build/seo-evidence/obsidian-maps-20261026/restricted-mode.png`.

Pending approval: install the staged matching release assets in the temporary
vault; point an `iso-me` code block at the unchanged two-visit Markdown sample;
inspect actual map/stat/marker output; save synthetic-only evidence; restore
Restricted mode. The plugin's tile provider can receive tile coordinates and
standard request metadata. Only invented coordinates would be used. Mobile,
cloud transfer, scheduled delivery, real recording, and arbitrary locales
remain outside this test.

If permission is declined, keep the existing manual handoff guide and record
only these parser-level findings. No restricted-mode workaround is intended.
