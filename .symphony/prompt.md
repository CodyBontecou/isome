You are Symphony, an autonomous coding agent working on GitHub issue CodyBontecou/isome#21: Drives-only mode (disable visit detection, track only vehicle trips).

Issue URL: https://github.com/CodyBontecou/isome/issues/21
Issue author: CodyBontecou

Issue body:
## Summary

Add a top-level **Drives Only** mode that suppresses visit detection and walking/cycling auto-start, so the app behaves purely as a mileage tracker (like MileIQ) for users who don't want a full place-history log.

## Motivation

Several users — especially business drivers evaluating iso.me as a MileIQ replacement — don't want the app recording every coffee shop and grocery stop. They want drives, period. Today the only knobs are auto-start activity types and visit detection, and there's no single setting that turns iso.me into a focused mileage app.

## Proposed UX

- **Settings → Tracking Mode** (new section) with three presets:
  - **Full History** (current default) — visits + all auto-start activities.
  - **Drives Only** — visits disabled, auto-start limited to driving.
  - **Custom** — exposes the existing granular toggles.
- Selecting a preset flips all the underlying knobs at once.
- A short explainer under each preset describing what's recorded and what isn't.
- Onboarding: add a "Why are you using iso.me?" step with **Mileage tracking** as one of the options that pre-selects Drives Only.

## Implementation notes

- No new tracking infrastructure required — this is a settings preset that drives existing flags:
  - Visit detection on/off (`CLLocationManager.startMonitoringVisits`).
  - `ActivityDetectionManager` allowed activities → `[.automotive]` only.
  - Hide the "Visits" tab/section when in Drives Only mode (or replace it with a "Drives" tab).
- Persist as a single `trackingMode` enum in user defaults; derive the existing toggles from it when not Custom.

## Acceptance criteria

- [ ] User can switch to Drives Only from settings and the app stops recording visits within one tracking cycle.
- [ ] Auto-start triggers only on driving, not walking/cycling/running.
- [ ] Onboarding offers the mode as an option.
- [ ] Switching back to Full History restores prior behavior without data loss.
- [ ] UI hides visit-only sections (Visits map pins, visit list) while in Drives Only.

<!-- isobot:discord-thread:1501667030032711730 -->

Instructions:

1. Work only inside the current repository/workspace.
2. Inspect the codebase and implement the issue as completely as possible.
3. Run the most relevant formatter, tests, typecheck, or build that is practical for this repository.
4. Do not create a pull request yourself; Symphony will commit, push, and open the PR after you exit.
5. Do not wait for human input. If blocked, make the best safe progress and leave notes in your final response.
