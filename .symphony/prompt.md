You are Symphony, an autonomous coding agent working on GitHub issue CodyBontecou/isome#20: IRS-compliant mileage reporting.

Issue URL: https://github.com/CodyBontecou/isome/issues/20
Issue author: CodyBontecou

Issue body:
## Summary

Generate a mileage report that satisfies the IRS recordkeeping requirements for business-vehicle deductions (Pub. 463, §274(d)), so users can use iso.me logs to back a Schedule C, Form 2106, or Form 4562 deduction.

## What the IRS actually requires

Per [Pub. 463](https://www.irs.gov/publications/p463), a contemporaneous mileage log must contain, for each business trip:

1. **Date** of the trip.
2. **Business destination** (where you went).
3. **Business purpose** (why).
4. **Miles driven** (or the odometer start/end).

Plus, per vehicle, per year:

5. **Total miles driven** (business + personal + commuting).
6. **Total business miles**.
7. **Date the vehicle was placed in service**.
8. **Year-start and year-end odometer readings** (best practice; not strictly required if you can derive total miles).

## Deliverable

A "Mileage Report" export type that produces:

- **Per-trip rows**: date, start/end address, purpose, sub-purpose, vehicle, miles, optional notes.
- **Per-vehicle annual summary**: total miles, business miles, personal miles, commuting miles, business-use percentage, year-start/end odometer.
- **Standard mileage deduction calculation**: business miles × current-year IRS standard mileage rate (configurable; ship with current rate plus past 5 years of historical rates baked in).
- **Output formats**: CSV (for accountants / TurboTax import) and PDF (printable, signed-style report).
- **Date range picker** — must support "Tax Year 2025" and "Q1/Q2/Q3/Q4" presets.

## Proposed UX

- **Settings → Reports → Mileage Report**.
- Pick year/quarter, vehicles to include, and trip purposes to include (default: Business only).
- Preview screen with totals and a sample of trip rows.
- Export → CSV / PDF, route through the existing `ExportService` so it picks up the default export folder and daily-export plumbing.

## Dependencies

- **Trip classification** (Business/Personal) — required.
- **Multi-vehicle support** — required.

## Compliance notes (for the report itself)

- Round miles to one decimal place.
- Include a footer noting the report was generated from contemporaneous GPS logs with timestamps.
- Don't fabricate purpose if the trip is `.unclassified` — exclude it and surface a "N unclassified trips not included" warning so the user can go classify them first.
- The standard mileage rate should be user-overridable per year (rates update mid-year sometimes — e.g. 2022 had two rates).

## Acceptance criteria

- [ ] Mileage report includes all eight IRS-required fields above.
- [ ] CSV and PDF outputs validated against a real Schedule C / Form 2106 line-item layout.
- [ ] Per-vehicle annual summary correctly partitions business vs. personal vs. unclassified.
- [ ] Standard mileage deduction calculation matches the configured rate.
- [ ] Unclassified trips are flagged, not silently included.
- [ ] Report can be regenerated for any past year without data loss.

<!-- isobot:discord-thread:1501666983119421490 -->

Instructions:

1. Work only inside the current repository/workspace.
2. Inspect the codebase and implement the issue as completely as possible.
3. Run the most relevant formatter, tests, typecheck, or build that is practical for this repository.
4. Do not create a pull request yourself; Symphony will commit, push, and open the PR after you exit.
5. Do not wait for human input. If blocked, make the best safe progress and leave notes in your final response.
