# Acquisition review: completed UTC windows

October 26, 2026. Reporting-only work on main; no collector, site deployment,
database schema, consent gate, or scheduled automation change.

The next new acquisition article is still release-gated. Apple's public US
lookup was checked again and still returns version 1.7.16, released at
2026-10-26T15:37:00Z. The existing released-source mapping excludes Google
import. No importer availability promise or publication was made.

The remaining SEO feedback-loop task is to review meaningful data after
reporting lag. The raw acquisition report includes an incomplete current day
and covers only 28 dates. An opt-in `--summary` mode now queries two disjoint,
equal windows ending before the as-of UTC date. Default: two 28-day windows,
ending yesterday. The original raw mode remains available.

Output keeps page and coarse referrer source separate and reports event
counts plus absolute changes. It does not join people or sessions, calculate
an organic conversion rate, or infer installs. A click without a corresponding
page load is retained rather than hidden or turned into a rate. Empty
successful SELECT results are distinguishable from failed/malformed queries.
No-row dates are not proof of collector uptime or no visitors. Offline input
must cover both windows; that coverage cannot be inferred from event rows.

Six tests pass with Python unittest. The SQL runs against a temporary in-memory
SQLite database with dates outside, at, and within both boundaries. It checks
multiple click placements, independent sources, and month rollover. Other
checks cover missing page loads, empty and failed Wrangler envelopes, replay
filtering, invalid counts/windows, and credential-free offline CLI execution.

Read-only production verification:

`python3 marketing/scripts/report_acquisition.py --summary --as-of 2026-10-26`

| Period | Inclusive dates | Recorded page loads | Download activations |
| --- | --- | ---: | ---: |
| Previous | August 31–September 27 | 0 | 0 |
| Current | September 28–October 25 | 0 | 0 |

Both have zero days with recorded events. The website collector was introduced
October 26, so these empty completed periods are expected. They do not measure
historical website traffic, SEO failure, or conversion change. Today's events
are excluded deliberately. The saved Search Console baseline remains separate.
No new search-result or install dataset was collected in this task.

The original raw command was also checked against production: it returned
October 26 rows for four pages (12 page loads, all coarse `direct`; zero
download activations at capture). These partial counts may include QA and
are not a performance finding. Wrangler reported `changed_db: false`,
`rows_written: 0`. Both query modes completed successfully.

The CLI syntax was verified against the installed Wrangler `d1 execute --help`:
remote SELECT uses `--command` plus `--json`, not SQL-file import mode. Only a
SELECT was executed against production. Report changes require no deployment.
