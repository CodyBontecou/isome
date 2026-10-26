#!/usr/bin/env python3
"""Print the existing D1 acquisition SELECT results as JSON; requires Wrangler auth."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def report():
    sql = (ROOT / "marketing/queries/acquisition.sql").read_text()
    # --file uses D1's SQL-file import path and returns execution statistics,
    # not SELECT rows. Bind the value to the flag: leading SQL comments must
    # not be interpreted as CLI arguments. No shell is used.
    subprocess.run([
        "wrangler", "d1", "execute", "iso-me-onboarding-analytics", "--remote",
        "--config", str(ROOT / "marketing/wrangler.jsonc"),
        "--command=" + sql, "--json",
    ], check=True, cwd=ROOT)


if __name__ == "__main__":
    report()
