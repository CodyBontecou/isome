You are Symphony, an autonomous coding agent working on GitHub issue CodyBontecou/isome#22: Epic: MileIQ feature parity for business mileage tracking.

Issue URL: https://github.com/CodyBontecou/isome/issues/22
Issue author: CodyBontecou

Issue body:
## Summary

Umbrella tracking issue for the work needed to make iso.me a viable MileIQ replacement for self-employed users and small businesses. Each child ticket can ship independently, but together they unlock the use case end-to-end.

## Why

Multiple users have asked whether iso.me can replace MileIQ. It's adjacent — we already do background drive detection, GPS tracking, and exports — but five concrete features are missing before the answer is "yes".

## Child tickets

- [ ] Classify trips as Business or Personal
- [ ] Multi-vehicle support
- [ ] Auto-detect active vehicle via Bluetooth connection (depends on multi-vehicle)
- [ ] IRS-compliant mileage reporting (depends on classification + multi-vehicle)
- [ ] Drives-only mode

## Suggested order

1. **Drives-only mode** — small, lands fast, immediately makes the app usable as a focused mileage tracker.
2. **Trip classification** — the foundation for everything reporting-related.
3. **Multi-vehicle support** — needed before Bluetooth pairing or per-vehicle reports.
4. **IRS-compliant mileage reporting** — the actual deliverable people care about at tax time.
5. **Bluetooth auto-detect** — quality-of-life polish that removes manual vehicle assignment.

## Out of scope (for now)

- Team / multi-user accounts (iso.me is on-device only by design).
- Cloud sync of trips between devices.
- Auto-classification rules ("weekdays = business").
- Receipt / parking / toll capture.

These can be revisited once the core five ship and we see what users actually want next.

<!-- isobot:discord-thread:1501667074962100425 -->

Instructions:

1. Work only inside the current repository/workspace.
2. Inspect the codebase and implement the issue as completely as possible.
3. Run the most relevant formatter, tests, typecheck, or build that is practical for this repository.
4. Do not create a pull request yourself; Symphony will commit, push, and open the PR after you exit.
5. Do not wait for human input. If blocked, make the best safe progress and leave notes in your final response.
