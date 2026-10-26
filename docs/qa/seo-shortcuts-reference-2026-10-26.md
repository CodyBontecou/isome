# Released Shortcuts reference reconciliation

Reviewed October 26, 2026. This implements the existing backlog item to reconcile
the Shortcuts reference before expanding automation promises or adding another
article. No app binary or native production source was changed.

## Finding and changes

The website described nine actions, including three obsolete exports: Export
Today's Data, Export Today's Outings, and Export Yesterday's Data. The verified
1.7.16 (46) release source at `6ae78e622c72ee051e6f14113082556c398d926a`
instead has twelve AppIntent definitions and nine AppShortcut registrations
with built-in phrases. The three read actions are available for custom
shortcuts but have no registration in that built-in phrase provider.

The [released action catalog](../seo-shortcuts-release-catalog-2026-10-26.json)
records exact action titles, types, source files, and phrase registrations.
Manual Check In / Check Out actions are absent from this release; current
development source was not used as evidence of public availability.

- Replaced the obsolete table on `/docs/siri-shortcuts/` with the release's
  recording, snapshot, read, rename, and configurable Export Data actions.
- Documented optional Start Date and End Date defaults, four data kinds, eight
  formats, and the inverted-range error caused by a past end with no start.
- Corrected Today's Tracking Duration to describe the current active recording,
  rather than imply a sum of all sessions today.
- Added a source-reviewed Export Data → Save File Markdown recipe and links
  to Obsidian, export formats, scheduling, and troubleshooting.
- Reconciled homepage FAQ HTML and JSON-LD, removed the incorrect action count
  from feature copy, and linked the detailed action reference.
- Updated the reference review date, title, description, and sitemap lastmod.
  Existing URLs remain the intent owners.

Apple's [custom shortcut guide](https://support.apple.com/guide/shortcuts/create-a-custom-shortcut-apd84c576f8c/ios)
and [share actions reference](https://support.apple.com/guide/shortcuts/share-actions-apdaf74d75a5/ios)
were read on October 26. They support adding and testing actions and passing
file output to Save File. The recipe does not claim a newly completed editor,
Siri, Action Button, physical-device, or unattended file-delivery test.

## Native verification

Used the isolated release-source copy and separate app identity prepared for
earlier documentation checks, preserving the normal app's journal. Ran the
existing suites without adding native tests or changing production source:

```sh
xcodebuild test -project /private/tmp/isome-seo-restore-release-08_3e_ws/IsoMe.xcodeproj \
  -scheme IsoMe -configuration Debug \
  -destination 'platform=iOS Simulator,id=5AC67EDC-DE2E-4EE7-AD57-DCBA324C8C6B' \
  -derivedDataPath /private/tmp/isome-seo-restore-derived \
  -parallel-testing-enabled NO \
  -only-testing:IsoMeTests/ExportDataIntentTests \
  -only-testing:IsoMeTests/GetVisitsGetMovementsIntentTests \
  -only-testing:IsoMeTests/GetCurrentOutingNameIntentTests \
  -only-testing:IsoMeTests/RenameIntentsTests
```

All **48 selected tests passed, zero failures**. Coverage includes date default
and invalid-range handling, data-kind mapping and export rendering, visit and
movement range reads, active-outing names, and rename persistence/error paths.
These are native logic tests, not a test of Shortcuts registration or Siri.
Local log: `/private/tmp/isome-seo-shortcuts-tests.log`; xcresult:
`/private/tmp/isome-seo-restore-derived/Logs/Test/Test-IsoMe-2026.10.26_14-31-45--0400.xcresult`.

## Mobile layout correction

At a 390×844 mobile viewport, the docs footer extended to 419 px because its
six links could not wrap. Added `flex-wrap: wrap` to the shared docs footer.
The corrected reference has client width and scroll width both 390 px, with
all three tables contained inside the content area. The shared stylesheet is
embedded by the generator, so the generated docs HTML changes together.

No community plugin, receiver, sync destination, account permission, new
automation, or download campaign was configured in this work.
