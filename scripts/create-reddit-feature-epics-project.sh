#!/usr/bin/env bash
set -euo pipefail

# Creates a GitHub Projects v2 project for the five Reddit-derived iso.me feature epics,
# creates/reuses one GitHub issue per epic, and adds those issues to the project.
#
# Requirements:
#   gh auth login
#   gh auth refresh -s project
#
# Usage:
#   ./scripts/create-reddit-feature-epics-project.sh
#
# Optional overrides:
#   OWNER=CodyBontecou REPO=CodyBontecou/isome PROJECT_TITLE="iso.me Reddit Feature Epics" ./scripts/create-reddit-feature-epics-project.sh

OWNER="${OWNER:-CodyBontecou}"
REPO="${REPO:-CodyBontecou/isome}"
PROJECT_TITLE="${PROJECT_TITLE:-iso.me Reddit Feature Epics}"
BODY_DIR="${BODY_DIR:-.github/epics/reddit-feature-epics}"

cd "$(dirname "$0")/.."

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh CLI is required" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  cat >&2 <<'EOF'
error: gh is not authenticated or the saved token is invalid.

Run:
  gh auth login -h github.com
  gh auth refresh -s project

Then rerun this script.
EOF
  exit 1
fi

project_number_from_list() {
  local title="$1"
  gh project list --owner "$OWNER" --limit 100 --format json | PROJECT_TITLE="$title" python3 -c '
import json, os, sys
payload = json.load(sys.stdin)
for project in payload.get("projects", []):
    if project.get("title") == os.environ["PROJECT_TITLE"]:
        print(project.get("number", ""))
        break
'
}

project_url_from_number() {
  local number="$1"
  gh project view "$number" --owner "$OWNER" --format json | python3 -c '
import json, sys
payload = json.load(sys.stdin)
print(payload.get("url", ""))
'
}

json_field() {
  local field="$1"
  python3 -c "import json, sys; print(json.load(sys.stdin).get('$field', ''))"
}

create_label() {
  local name="$1"
  local color="$2"
  local description="$3"
  gh label create "$name" --repo "$REPO" --color "$color" --description "$description" --force >/dev/null || true
}

create_label "epic" "6f42c1" "Large multi-step feature scope"
create_label "reddit-request" "0e8a16" "Requested or validated from Reddit feedback"
create_label "difficulty:medium" "fbca04" "Medium implementation complexity"
create_label "difficulty:hard" "d93f0b" "Hard implementation complexity"
create_label "difficulty:xl" "b60205" "Extra-large implementation complexity"
create_label "feature:location-correction" "1d76db" "Manual visit confirmation and correction"
create_label "feature:timeline" "1d76db" "Timeline and day replay"
create_label "feature:import" "1d76db" "Import and migration"
create_label "feature:auto-start" "1d76db" "Smart auto-start and activity tracking"
create_label "feature:mileage" "1d76db" "Mileage mode and trip reporting"

project_number="$(project_number_from_list "$PROJECT_TITLE" | head -n 1)"
if [[ -z "$project_number" ]]; then
  echo "Creating project: $PROJECT_TITLE"
  project_json="$(gh project create --owner "$OWNER" --title "$PROJECT_TITLE" --format json)"
  project_number="$(printf '%s' "$project_json" | json_field number)"
  project_url="$(printf '%s' "$project_json" | json_field url)"
else
  echo "Reusing existing project #$project_number: $PROJECT_TITLE"
  project_url="$(project_url_from_number "$project_number")"
fi

# Link the project to the repository if possible. This is idempotent-ish; ignore if already linked.
gh project link "$project_number" --owner "$OWNER" --repo "${REPO#*/}" >/dev/null 2>&1 || true

issue_url_for_title() {
  local title="$1"
  gh issue list --repo "$REPO" --state all --limit 200 --json title,url | TITLE="$title" python3 -c '
import json, os, sys
items = json.load(sys.stdin)
for item in items:
    if item.get("title") == os.environ["TITLE"]:
        print(item.get("url", ""))
        break
'
}

create_or_reuse_issue() {
  local title="$1"
  local body_file="$2"
  shift 2

  if [[ ! -f "$body_file" ]]; then
    echo "error: missing body file $body_file" >&2
    exit 1
  fi

  local url
  url="$(issue_url_for_title "$title" | head -n 1)"
  if [[ -n "$url" ]]; then
    echo "Reusing issue: $title -> $url"
  else
    local label_args=(--label "epic" --label "reddit-request")
    local label
    for label in "$@"; do
      label_args+=(--label "$label")
    done
    echo "Creating issue: $title"
    url="$(gh issue create --repo "$REPO" --title "$title" --body-file "$body_file" "${label_args[@]}")"
  fi

  echo "Adding to project #$project_number: $url"
  gh project item-add "$project_number" --owner "$OWNER" --url "$url" >/dev/null || true
}

create_or_reuse_issue \
  "Epic: Manual confirm/correct locations" \
  "$BODY_DIR/01-manual-confirm-correct-locations.md" \
  "difficulty:medium" "feature:location-correction"

create_or_reuse_issue \
  "Epic: Timeline / day replay view" \
  "$BODY_DIR/02-timeline-day-replay.md" \
  "difficulty:medium" "feature:timeline"

create_or_reuse_issue \
  "Epic: Google Timeline / Takeout import" \
  "$BODY_DIR/03-google-timeline-import.md" \
  "difficulty:hard" "feature:import"

create_or_reuse_issue \
  "Epic: Smart Auto-Start / activity-based tracking" \
  "$BODY_DIR/04-smart-auto-start-activity-tracking.md" \
  "difficulty:hard" "feature:auto-start"

create_or_reuse_issue \
  "Epic: Mileage Mode — trip tagging and IRS-style exports" \
  "$BODY_DIR/05-mileage-mode-trip-tagging.md" \
  "difficulty:xl" "feature:mileage"

echo
echo "Project ready: $project_url"
