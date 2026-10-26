"""Verify reporting boundaries and aggregation without external services."""
from datetime import date
import json
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest

from report_acquisition import comparison_sql, result_rows, summarize


class AcquisitionReportTests(unittest.TestCase):
    def test_sql_and_summary_agree_on_complete_disjoint_windows(self):
        db = sqlite3.connect(":memory:")
        db.row_factory = sqlite3.Row
        db.execute("CREATE TABLE website_acquisition_daily (day, event, page, placement, source, count)")
        db.executemany("INSERT INTO website_acquisition_daily VALUES (?,?,?,?,?,?)", [
            ("2026-02-22", "page_view", "/", "page", "search", 999),
            ("2026-02-23", "page_view", "/", "page", "search", 4),
            ("2026-02-25", "app_store_clicked", "/", "inline", "search", 2),
            ("2026-02-26", "page_view", "/", "page", "search", 10),
            ("2026-02-26", "app_store_clicked", "/", "nav", "search", 2),
            ("2026-02-26", "app_store_clicked", "/", "inline", "search", 1),
            ("2026-02-27", "app_store_clicked", "/", "inline", "search", 2),
            ("2026-02-28", "page_view", "/blog/", "page", "internal", 3),
            ("2026-03-01", "page_view", "/", "page", "search", 999),
        ])
        rows = [dict(row) for row in db.execute(comparison_sql(date(2026, 3, 1), 3))]
        report = summarize(rows, date(2026, 3, 1), 3)
        self.assertEqual(report["periods"]["previous"]["start_inclusive"], "2026-02-23")
        self.assertEqual(report["periods"]["previous"]["end_inclusive"], "2026-02-25")
        self.assertEqual(report["periods"]["current"]["start_inclusive"], "2026-02-26")
        self.assertEqual(report["periods"]["current"]["end_inclusive"], "2026-02-28")
        self.assertEqual(report["periods"]["current"]["page_loads"], 13)
        self.assertEqual(report["periods"]["current"]["download_activations"], 5)
        self.assertEqual(report["periods"]["previous"]["page_loads"], 4)
        self.assertEqual(report["periods"]["previous"]["download_activations"], 2)
        self.assertEqual(report["page_sources"][0]["current"],
                         {"page_loads": 10, "download_activations": 5})
        self.assertEqual(report["page_sources"][1]["source"], "internal")
        self.assertEqual(report["periods"]["current"]["days_with_recorded_events"], 3)

    def test_zero_and_click_only_rows_do_not_create_a_conversion_rate(self):
        report = summarize([{"day": "2026-10-25", "page": "/", "source": "direct",
                             "page_loads": 0, "download_activations": 2}], date(2026, 10, 26), 28)
        self.assertEqual(report["periods"]["previous"]["page_loads"], 0)
        self.assertIsNone(report["periods"]["previous"]["first_recorded_event_day"])
        self.assertEqual(report["page_sources"][0]["absolute_change"]["download_activations"], 2)
        self.assertNotIn("conversion_rate", json.dumps(report))

    def test_replay_excludes_today_future_and_outside_window(self):
        rows = [{"day": day, "page": "/", "source": "search", "page_loads": 1,
                 "download_activations": 0} for day in
                ["2026-10-01", "2026-10-24", "2026-10-25", "2026-10-26", "2026-10-27"]]
        report = summarize(rows, date(2026, 10, 26), 1)
        self.assertEqual(report["periods"]["previous"]["page_loads"], 1)
        self.assertEqual(report["periods"]["current"]["page_loads"], 1)

    def test_empty_success_is_different_from_failed_query(self):
        self.assertEqual(result_rows([{"success": True, "results": []}]), [])
        for payload in [[], [{"success": False, "results": []}], [{"success": True}],
                        [{"success": True, "results": []}] * 2, [None]]:
            with self.assertRaises(ValueError):
                result_rows(payload)

    def test_rejects_invalid_counts_and_window(self):
        for days in [0, -1, 367]:
            with self.assertRaises(ValueError):
                summarize([], date(2026, 10, 26), days)
        for value in [-1, "2", None, 1.5, True]:
            with self.assertRaises(ValueError):
                summarize([{"day": "2026-10-25", "page": "/", "source": "search",
                            "page_loads": value, "download_activations": 0}], date(2026, 10, 26), 1)

    def test_offline_cli_replays_wranger_json_without_credentials(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "query.json"
            fixture.write_text(json.dumps([{"success": True, "results": []}]))
            script = str(Path(__file__).with_name("report_acquisition.py"))
            result = subprocess.run([sys.executable, script, "--summary", "--as-of", "2026-10-26",
                                     "--days", "7", "--input", str(fixture)],
                                    capture_output=True, text=True, check=True)
            report = json.loads(result.stdout)
            self.assertEqual(report["periods"]["current"]["start_inclusive"], "2026-10-19")
            self.assertEqual(report["page_sources"], [])
            result = subprocess.run([sys.executable, script, "--days", "7", "--input", str(fixture)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
