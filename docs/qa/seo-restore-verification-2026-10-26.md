# Backup guide: released-source restore attempt

October 26, 2026. The clean-destination restore gate remains open.

## Isolated setup

Exported release source `6ae78e622c72ee051e6f14113082556c398d926a` to a
temporary directory and built its IsoMe scheme for iOS Simulator. Version
1.7.16 (46) was confirmed in Settings. This was a Debug simulator rebuild of
the release revision, not the App Store-distributed binary.

To preserve existing journals, changed bundle identifiers to the separate
`com.bontecou.isome.seorestore` prefix in the temporary project and isolated
its app-group entitlement and Live Activity group path. The import code,
models and Settings implementation were unchanged. No native app source or
binary was changed in the repository or submitted to Apple.

Used iOS 26.5 simulators `iso-me-crash-repro-20261025` and
`iso-me-country-days-QA` through Argent. Both test installs showed zero visits
and zero points. Location access was denied before launch, geocoding was
disabled with a launch preference, and onboarding was skipped for this test.
The existing normal-bundle apps and their journal data were not reinstalled.

## Observed result

On the first simulator, downloaded both public JSON samples using Safari's
link context menu. Files showed `synthetic-visits.json` (641 bytes) and
`synthetic-points.json` (813 bytes).

Selecting Settings → Import File did not present a document picker in the
isolated release-source app. Re-discovery, app restart, a reboot through
Argent, initializing Files, and a second simulator did not establish a working
picker. Ordinary navigation, including Settings → View Logs, worked. The
rebuild's changed identity and simulator environment are limitations; this is
not sufficient evidence to declare the distributed app broken or identify a
root cause.

No file was selected by the importer, no records were imported, and persistence
after reopening was not verified. Do not present zero-record screenshots as
restore proof. Parser-only verification from the earlier batch remains valid
within its documented limits.

## Website improvement

Safari followed the original JSON link into a text view despite the HTML
download attribute. Touch and hold → Download Linked File saved the files.
Added narrow attachment headers for the two public synthetic JSON assets,
Safari fallback instructions, and a destination verification checklist. The
checklist covers separate visits/points results, baseline counts, date ranges,
representative fields, and reopening before retiring the original phone.

The guide explicitly labels the two-visit/three-point fixture values as
expected results, not a newly verified restore. A complete export/import
workflow, purchase boundary, cloud handoff and physical device transfer remain
unverified in this batch.

Preview `4e2995ed.spotted-8ez.pages.dev` returned 200 and the expected
`Content-Disposition: attachment` filename for both JSON fixtures, with bytes
identical to the repository samples. Safari on the second simulator presented
the Download prompt for `synthetic-visits.json`; selecting Download produced
the named 641-byte file in Files. This verifies the download fix, not import.

The site build passed 29 HTML pages and 952 local targets. Local screenshots
of the incomplete restore and downloaded sample files are retained in
`build/seo-evidence/restore-20261026/` and are not published as restore proof.
