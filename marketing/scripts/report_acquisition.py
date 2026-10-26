#!/usr/bin/env python3
"""Report coarse acquisition counts; optional equal, completed UTC windows."""
import argparse
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def query(sql):
    # --file uses D1's SQL-file import path and returns execution statistics,
    # not SELECT rows. Bind the value to the flag: leading SQL comments must
    # not be interpreted as CLI arguments. No shell is used.
    result = subprocess.run([
        "wrangler", "d1", "execute", "iso-me-onboarding-analytics", "--remote",
        "--config", str(ROOT / "marketing/wrangler.jsonc"),
        "--command=" + sql, "--json",
    ], check=True, cwd=ROOT, capture_output=True, text=True)
    return json.loads(result.stdout)


def result_rows(payload):
    """Accept Wrangler's result envelope; never mistake query failure for zero."""
    if not isinstance(payload, list) or len(payload) != 1:
        raise ValueError("Expected one Wrangler query result")
    result = payload[0]
    if not isinstance(result, dict) or result.get("success") is not True or not isinstance(result.get("results"), list):
        raise ValueError("Acquisition query did not return successful SELECT rows")
    return result["results"]


def comparison_sql(as_of, days):
    # Both values are validated by the CLI. Only ISO dates enter the SQL;
    # no user-supplied SQL or shell interpolation is accepted.
    start = as_of - timedelta(days=2 * days)
    return """SELECT day, page, source,
       SUM(CASE WHEN event = 'page_view' THEN count ELSE 0 END) AS page_loads,
       SUM(CASE WHEN event = 'app_store_clicked' THEN count ELSE 0 END) AS download_activations
FROM website_acquisition_daily
WHERE day >= '%s' AND day < '%s'
GROUP BY day, page, source
ORDER BY day, page, source;""" % (start.isoformat(), as_of.isoformat())


def summarize(rows, as_of, days):
    if not 1 <= days <= 366:
        raise ValueError("Window days must be between 1 and 366")
    current_start = as_of - timedelta(days=days)
    previous_start = current_start - timedelta(days=days)
    groups = defaultdict(lambda: {"previous": [0, 0], "current": [0, 0]})
    observed = {"previous": set(), "current": set()}
    totals = {"previous": [0, 0], "current": [0, 0]}
    for row in rows:
        day = date.fromisoformat(row["day"])
        if not previous_start <= day < as_of:
            continue
        period = "previous" if day < current_start else "current"
        counts = [row["page_loads"], row["download_activations"]]
        if any(type(value) is not int or value < 0 for value in counts):
            raise ValueError("Expected nonnegative integer event counts")
        for i, value in enumerate(counts):
            groups[(row["page"], row["source"])][period][i] += value
            totals[period][i] += value
        if any(counts):
            observed[period].add(day.isoformat())

    def counts(values):
        return dict(zip(("page_loads", "download_activations"), values))

    periods = {}
    for name, start, end in [("previous", previous_start, current_start),
                              ("current", current_start, as_of)]:
        dates = sorted(observed[name])
        periods[name] = {"start_inclusive": start.isoformat(),
                         "end_inclusive": (end - timedelta(days=1)).isoformat(),
                         "days": days, "days_with_recorded_events": len(dates),
                         "first_recorded_event_day": dates[0] if dates else None,
                         **counts(totals[name])}
    return {
        "as_of_utc_exclusive": as_of.isoformat(), "periods": periods,
        "page_sources": [
            {"page": page, "source": source,
             "previous": counts(values["previous"]),
             "current": counts(values["current"]),
             "absolute_change": counts([a - b for a, b in
                                         zip(values["current"], values["previous"])])}
            for (page, source), values in sorted(groups.items())],
        "limits": [
            "UTC calendar windows exclude the as-of date and all later dates.",
            "Counts are page loads and download-link activations, not people, sessions, installs, or purchases.",
            "Source is the coarse referrer on that page; search is not an organic-session attribution model.",
            "Recorded-event days do not establish collector uptime. Missing rows can mean no events, exclusions, or unavailable collection.",
            "Saved input must cover both windows; event rows alone cannot prove historical query coverage.",
            "QA and bots may contribute. Zero counts and small samples do not establish SEO or conversion performance.",
            "Review Search Console and Apple campaign reports separately; no causal lift or click-to-install join is calculated.",
        ],
    }


def report():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summary", action="store_true", help="Compare two completed UTC windows")
    parser.add_argument("--as-of", type=date.fromisoformat, help="Exclusive UTC cutoff (default: today)")
    parser.add_argument("--days", type=int, help="Days in each comparison window (default: 28)")
    parser.add_argument("--input", type=Path, help="Read saved Wrangler JSON instead of querying D1")
    args = parser.parse_args()
    today = datetime.now(timezone.utc).date()
    as_of, days = args.as_of or today, args.days if args.days is not None else 28
    if not args.summary and (args.as_of is not None or args.days is not None):
        parser.error("--as-of and --days require --summary")
    if as_of > today or not 1 <= days <= 366:
        parser.error("Use an as-of date no later than today and 1–366 days")
    sql = comparison_sql(as_of, days) if args.summary else (ROOT / "marketing/queries/acquisition.sql").read_text()
    payload = json.loads(args.input.read_text()) if args.input else query(sql)
    # Validate even raw results so unavailable data never looks like an empty report.
    rows = result_rows(payload)
    print(json.dumps(summarize(rows, as_of, days) if args.summary else payload, indent=2))


if __name__ == "__main__":
    report()
