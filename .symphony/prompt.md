You are Symphony, an autonomous coding agent working on GitHub issue CodyBontecou/isome#17: Classify trips as Business or Personal.

Issue URL: https://github.com/CodyBontecou/isome/issues/17
Issue author: CodyBontecou

Issue body:
## Summary

Allow users to mark each tracked drive (and visit, where relevant) as **Business** or **Personal**, so the app can drive mileage reporting and reimbursement workflows the same way MileIQ does.

## Motivation

This is the foundational feature for using iso.me as a MileIQ replacement. Without trip classification, none of the downstream business-mileage features (IRS reports, deduction totals, per-purpose summaries) are useful.

## Proposed UX

- After a continuous-tracking session ends, surface a lightweight classifier card on the session detail view: **Business** / **Personal** / **Unclassified**.
- Optional sub-purpose tag for Business (e.g. *Client Visit*, *Errand*, *Meeting*, *Between Offices*) — free-text or chips, MileIQ-style.
- Quick-classify swipe gestures on the trip list (left = Personal, right = Business), like MileIQ's swipe deck.
- Bulk classify from the trip list (multi-select → set purpose).
- Per-classification color/icon on the map and list views.

## Data model

- Extend the continuous-tracking session model with:
  - `purpose: TripPurpose` (`.business`, `.personal`, `.unclassified`)
  - `subPurpose: String?` (optional free-form tag)
  - `notes: String?`
- Store the user's frequent sub-purposes for autocomplete.
- Migration: existing sessions default to `.unclassified`.

## Out of scope

- Auto-classification rules (e.g. "weekdays 9–5 = business") — track separately if requested.
- IRS report generation — covered by a separate ticket.

## Acceptance criteria

- [ ] User can tag any past drive as Business or Personal from the trip detail view.
- [ ] User can swipe-classify from the trip list.
- [ ] Bulk classify works from a multi-select on the trip list.
- [ ] Trip purpose persists across app restarts and is included in JSON/CSV/Markdown exports.
- [ ] Existing data migrates safely to `.unclassified`.

<!-- isobot:discord-thread:1501666799907897354 -->

Instructions:

1. Work only inside the current repository/workspace.
2. Inspect the codebase and implement the issue as completely as possible.
3. Run the most relevant formatter, tests, typecheck, or build that is practical for this repository.
4. Do not create a pull request yourself; Symphony will commit, push, and open the PR after you exit.
5. Do not wait for human input. If blocked, make the best safe progress and leave notes in your final response.
