#!/bin/sh
set -eu

MARKETING_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

python3 "$MARKETING_ROOT/scripts/build_site.py"
node --test "$MARKETING_ROOT/scripts/acquisition.test.mjs"
wrangler d1 migrations apply iso-me-onboarding-analytics --remote --config "$MARKETING_ROOT/wrangler.jsonc"

(
  cd "$MARKETING_ROOT"
  wrangler pages deploy public --project-name spotted --branch main
)

if command -v indexnow >/dev/null 2>&1; then
  indexnow submit-sitemap isome.isolated.tech --recent-days 7 --confirm
else
  printf '%s\n' 'warning: indexnow CLI not found; production deployed without URL notification' >&2
fi
