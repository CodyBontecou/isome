# Apple Watch guide: queue and phone disk-store replay

October 26, 2026. Improves the existing `/docs/apple-watch/` intent owner, with
contextual discovery from the docs hub and missing-history guide. The physical
Watch-only route and paired-device transport gates remain open. This editorial
priority addresses missing evidence, not a measured new search opportunity.

## Setup

Used the existing isolated Debug rebuild of released 1.7.16 (46), source
`6ae78e622c72ee051e6f14113082556c398d926a`, in
`/private/tmp/isome-seo-restore-release-08_3e_ws`. Argent list-devices confirmed
the booted `iso-me-country-days-QA`
(`5AC67EDC-DE2E-4EE7-AD57-DCBA324C8C6B`), iOS 26.5. No physical device selected.

[Evidence test](WatchQueueDiskEvidence.swift) was appended only to the temporary
copy's WatchLocationSyncTests.swift. Shared queue/payload, iPhone receiver, and
Watch client source were compared byte-for-byte to the release revision and
match. No native production repository source or app binary was submitted.

The existing `watch-offline-route.json` fixture is explicitly synthetic: 503
points, two completed visits, and one completed outing. No personal route is
read or published. The test uses production queue batching/acknowledgement,
wire encoding/decoding, and the actual phone receiver. Real WatchConnectivity
activation is disabled, with delivery supplied directly by the test.

## Native test

The new test saves queue state and first-payload JSON to temporary files and
uses an on-disk SwiftData phone store. Both are reopened between deliveries.
The temporary directory is removed afterward. Containers are scoped in
separate autorelease pools; this is not an app-process restart.

1. Import the first 500 points, withholding the acknowledgement. Phone has
   500 saved points; the saved queue still has 503.
2. Reopen queue and phone store. Retry the original wire data: zero new points
   and zero new visits. Apply its acknowledgement: three points remain queued,
   along with the completed outing waiting for its final batch.
3. Reopen queue JSON, send the final three points, and acknowledge. Queue has
   no points, visits, or sessions and cannot produce another payload.
4. Reopen both files/stores again. Phone has 503 points, two visits, one outing.
   Every saved point ID and timestamp matches the fixture. A delayed repeat of
   the first wire data still adds zero points and leaves the phone at 503.

```sh
xcodebuild test -project /private/tmp/isome-seo-restore-release-08_3e_ws/IsoMe.xcodeproj \
  -scheme IsoMe -configuration Debug \
  -destination 'platform=iOS Simulator,id=5AC67EDC-DE2E-4EE7-AD57-DCBA324C8C6B' \
  -derivedDataPath /private/tmp/isome-seo-restore-derived \
  -parallel-testing-enabled NO \
  -only-testing:IsoMeTests/WatchLocationSyncTests \
  -only-testing:IsoMeTests/WatchLocationSyncImportTests
```

**15 tests passed, zero failures.** Fourteen existing tests cover queue state,
in-flight departure updates, out-of-order acknowledgements, legacy recovery,
readiness, invalid payloads, session completion, and receiver updates. The new
test adds actual disk reads/writes and a new phone container between retries.
Log: `/private/tmp/isome-seo-watch-disk.log`.

## Published interpretation and limits

The guide now provides a stage table, a phone-copy checklist, and three focused
questions. It explains that queued points can already exist on the phone while
an acknowledgement is pending. An empty queue is not an archive or evidence of
unrecorded history. Retrying the same Watch IDs differs from reimporting a
point file, which is linked to its separately checked append behavior.

Apple's [WCSession overview](https://developer.apple.com/documentation/watchconnectivity/wcsession)
was checked October 26, 2026 for the linked background-transfer timing limit.
Apple's [transferUserInfo documentation](https://developer.apple.com/documentation/watchconnectivity/wcsession/transferuserinfo(_:))
requires paired-device testing for actual transport; that remains unverified
here. No physical GPS/Watch recording, radio delivery, real background transfer,
Watch sync UI, or app-process restart is newly claimed. No replay fixture was
added as a public journal import download.

Static build passes 31 HTML pages, 30 Markdown pages, 1,074 local targets,
metadata, JSON-LD, IDs, sitemap coverage, and `git diff --check`. Mobile checks
show a 390 px document/viewport with the result table inside its named region.

Local Lighthouse 13.5.0 scores 100 in all four categories for the Watch guide,
docs hub, and missing-history article on mobile and desktop. Reports:
`/private/tmp/isome-seo-watch-queue-before/`. These are lab checks, not search
performance or field Core Web Vitals.
