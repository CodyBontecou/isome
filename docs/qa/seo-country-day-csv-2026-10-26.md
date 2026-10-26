# Country Days: checked counting example and exact CSV

October 26, 2026. Strengthens the existing country-day guide rather than
creating another URL. The original title/URL are retained. This is an
editorial priority based on an evidence gap; no new query volume, ranking,
or conversion result selected it.

## Setup

Used the existing isolated Debug simulator rebuild of released 1.7.16 (46),
source `6ae78e622c72ee051e6f14113082556c398d926a`, from
`/private/tmp/isome-seo-restore-release-08_3e_ws`. Argent list-devices confirmed
the already booted `iso-me-country-days-QA`
(`5AC67EDC-DE2E-4EE7-AD57-DCBA324C8C6B`), iOS 26.5. No physical device selected.

[Evidence test](CountryDaysSampleEvidence.swift) was appended only to the
temporary copy's existing CountryDayTests.swift. Models/calculator in
CountryStay.swift, Visit.swift, and LocationPoint.swift were compared
byte-for-byte to the release revision and match. No production native code,
App Store binary, or app group used for everyday journals changed.

## Native verification

The test constructs six invented points at 0/0, assigning country codes and
timezones directly. This deliberately bypasses the geocoder and is not evidence
that those coordinates resolve to the assigned countries. Inputs:

- Portugal October 1, 08:00 and 08:05 UTC, Europe/Lisbon.
- Spain October 1, 18:00 UTC, Europe/Madrid.
- France October 2, 22:30 UTC, Europe/Paris (local October 3).
- France October 4 flagged as an outlier, plus an October 5 point without a
  country or timezone; neither contributes a date.
- Manual Portugal stay October 1 through October 2.

Actual CountryDayCalculator.summaries and .csv produce three countries,
four country/date rows, and three distinct local date labels. Portugal's
October 1 is recorded+manual once; October 2 is manual. Spain October 1 and
France October 3 are recorded. The CSV is written to a temporary file and read
back byte-for-byte; that file is removed afterward. Its base64 output is
captured in the test log and decoded unchanged into the public download.

```sh
xcodebuild test -project /private/tmp/isome-seo-restore-release-08_3e_ws/IsoMe.xcodeproj \
  -scheme IsoMe -configuration Debug \
  -destination 'platform=iOS Simulator,id=5AC67EDC-DE2E-4EE7-AD57-DCBA324C8C6B' \
  -derivedDataPath /private/tmp/isome-seo-restore-derived \
  -parallel-testing-enabled NO \
  -only-testing:IsoMeTests/CountryDayTests
```

**23 tests passed, zero failures.** Existing tests also cover boundaries,
clipping, open/inferred visits, duplicates, DST, persistence, and controlled
resolver success/failure/cancellation. They do not establish real geocoding
accuracy, a physical travel workflow, payment, or the app's share interface.
Log: `/private/tmp/isome-seo-country-csv.log`.

## Download

`marketing/public/samples/synthetic-country-days.csv`: 133 bytes, CRLF rows,
header `country_code,local_date,source`, four data rows sorted by country code
and then local date. SHA-256:
`3197af026540079b4d91d424556953fb7d2f27841fabe7b9632cb5fbf74253f9`.
The source value `recorded` refers to input type, not real movement in this
fixture. The CSV is a summary example, not an importable journal backup.
A narrow attachment header gives it its intended filename.

## Site changes

The guide replaces its untested border example with explicit checked inputs,
a result table, totals explanation, and the native CSV download. It explains
source flags, timezone assignment, and excluded points. The Timeline reference
links directly to this evidence. The free viewing/manual-stay and paid file
export boundary remains explicit. No legal counting methodology is supplied.

Static build passes 31 HTML pages, 30 Markdown pages, 1,072 local targets,
metadata, JSON-LD, IDs, sitemap coverage, and `git diff --check`.

## Local publication checks

At 390 px, the guide's viewport and document width both measure 390 px.
Its four table rows match the native CSV, and the download anchor is present.
Lighthouse 13.5.0 scores 100 in all four categories for both changed pages,
mobile and desktop; reports are in `/private/tmp/isome-seo-country-csv-before/`.
These lab checks do not establish field performance or search outcomes.

A narrow `.gitattributes` entry preserves this one native CSV's exact bytes
and recognizes CRLF row endings for whitespace checks. Other whitespace
checks remain enabled. The original native output is not normalized to LF.
