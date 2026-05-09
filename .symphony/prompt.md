You are Symphony, an autonomous coding agent working on GitHub issue CodyBontecou/isome#19: Multi-vehicle support.

Issue URL: https://github.com/CodyBontecou/isome/issues/19
Issue author: CodyBontecou

Issue body:
## Summary

Let users register multiple vehicles, set a default, and assign each tracked drive to a vehicle. Required for households or self-employed users who drive more than one car.

## Motivation

Mileage deductions and reimbursements are tracked **per vehicle** (the IRS Schedule C / Form 4562 line items are per-vehicle). Without a vehicle list, iso.me cannot produce a usable mileage report for anyone with more than one car.

## Data model

New `Vehicle` SwiftData model:

- `id: UUID`
- `name: String` (e.g. "Work Truck")
- `make: String?`
- `model: String?`
- `year: Int?`
- `licensePlate: String?`
- `odometerStart: Int?` (year-start odometer for IRS reporting)
- `odometerCurrent: Int?` (kept up to date when the user enters readings)
- `isDefault: Bool`
- `bluetoothPortName: String?` (filled by the BT auto-detect ticket)
- `archivedAt: Date?` (soft-delete so historical trips keep referencing the vehicle)

Extend the continuous-tracking session model with `vehicleID: UUID?`.

## Proposed UX

- **Settings → Vehicles** — list with add / edit / archive.
- "Default vehicle" toggle; new untagged drives use the default.
- Trip detail view: vehicle picker with quick-set chips for the most-recent vehicles.
- Trip list filter by vehicle.
- Vehicle detail screen: total miles, business/personal breakdown, mileage chart, current odometer.

## Acceptance criteria

- [ ] User can add, edit, and archive vehicles.
- [ ] Drives can be assigned (or reassigned) to any non-archived vehicle.
- [ ] A default vehicle is automatically applied to new drives unless overridden.
- [ ] Vehicle is included in JSON/CSV/Markdown exports.
- [ ] Archiving a vehicle hides it from new drives but preserves it on past drives.

<!-- isobot:discord-thread:1501666903012413480 -->

Instructions:

1. Work only inside the current repository/workspace.
2. Inspect the codebase and implement the issue as completely as possible.
3. Run the most relevant formatter, tests, typecheck, or build that is practical for this repository.
4. Do not create a pull request yourself; Symphony will commit, push, and open the PR after you exit.
5. Do not wait for human input. If blocked, make the best safe progress and leave notes in your final response.
