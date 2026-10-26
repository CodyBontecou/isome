# iso.me → Dawarich: native Overland delivery and persistence

October 26, 2026. Follow-up to [the original receiver hold](../dawarich-guide-verification-2026-10-26.md).

## Tested versions and isolation

- iso.me 1.7.16 (46), Debug simulator rebuild from released source
  `6ae78e622c72ee051e6f14113082556c398d926a` in the previously prepared
  temporary project. Separate `com.bontecou.isome.seorestore` identity and app
  group preserve normal journals; no repository native production source changed.
- Running iOS 26.5 simulator `5AC67EDC-DE2E-4EE7-AD57-DCBA324C8C6B`.
- Dawarich 1.18.0, official release source
  `75442a01d6c10fa5816a3ee3fe65da70115b2c96`.
- Container `freikin/dawarich:1.18.0`, digest
  `sha256:e22d39339a00ab03b057a75897a8950dfd5d084e0f23202a7c6d5e8814f96aff`.
- Redis 8 Alpine digest
  `sha256:47b08295737773de3b711fb86f13ae802f5074e96a9a2d29f5f80164ac08c046`;
  ARM PostGIS 17/3.5 Alpine digest
  `sha256:c24f99339ca46a13100b7f7b7ccc41c416ebf6c4cbb916a20569e519fb144cf1`.

Created dedicated Colima profile `isome-seo`, two CPUs, 4 GiB RAM and 20 GiB
sparse disk, with no host directory mounts, no SSH-agent forwarding, no SSH
config insertion, and no change to the active Docker context. `COLIMA_HOME`
did not relocate this installed CLI's runtime; its actual profile is under
`~/.colima/isome-seo`, with the VM under `~/.colima/_lima/colima-isome-seo`.
The profile and container network were separate from other projects.

The Compose project used an internal network, dedicated named database/storage
volumes, generated temporary secrets, and no host mounts. Internal Docker
networking prevented published host-port reachability, so a loopback-only SSH
forward reached the container through the VM: `127.0.0.1:38147` to its port 3000.
The receiver containers had no outbound internet access. This is a local HTTP
test, not production HTTPS validation. The API key stayed in a private temporary
file and the temporary XCTest source; it was not committed or included in the
public sample/screenshot.

## Native test and receiver observations

Appended the [redacted evidence template](DawarichReceiverEvidence.swift) to the
existing `ExportRoundTripTests.swift` only in the temporary release-source copy.
Replaced its placeholder with the dedicated receiver's key only in that copy.
Ran one live-receiver test plus the existing WebhookManagerTests:

```sh
xcodebuild test -project /private/tmp/isome-seo-restore-release-08_3e_ws/IsoMe.xcodeproj \
  -scheme IsoMe -configuration Debug \
  -destination 'platform=iOS Simulator,id=5AC67EDC-DE2E-4EE7-AD57-DCBA324C8C6B' \
  -derivedDataPath /private/tmp/isome-seo-restore-derived \
  -parallel-testing-enabled NO \
  -only-testing:IsoMeTests/ExportRoundTripTests/testSEODawarichReceiver \
  -only-testing:IsoMeTests/WebhookManagerTests
```

**22 tests passed, zero failures.** The live test used the actual
WebhookManager with a normal ephemeral URLSession, API-key query authentication,
and the released Overland serializer. No URLProtocol mock was used for the
receiver test. The other 21 existing regression tests use controlled responses
for credentials, sanitization, queue success/failure, transient retries, and 401s.

1. Native Test Connection returned HTTP 201.
2. An invalid synthetic key returned HTTP 401 and the expected native error.
3. Three invented LocationPoint models were enqueued and flushed through the
   real batch sender. Queue count became zero, last-sent time was present, and
   last-error was nil.
4. Read the actual receiver's Point models: exact coordinates and epoch seconds
   matched all three fixture records, as did altitude 0/1/2 m, velocity 1 m/s,
   accuracy 5 m, and tracker ID `isome`.
5. Restarted both dedicated database and app containers, then re-read those
   fields. The resulting JSON was identical. See the
   [persisted synthetic values](dawarich-persisted-synthetic-2026-10-26.json).
6. Signed into only the locally seeded test account and opened Points. Filtered
   January 1, 2000; it showed all three coordinates and times. The 1 m/s payload
   appeared as 3.6 km/h. Saved the synthetic-only screenshot, with no API key.

The live test's base64-delimited serializer output was decoded unchanged into
`marketing/public/samples/synthetic-overland-export.json`. Coordinates are
invented, away from the receiver's 0,0 filter; timestamps are 2000-01-01 at
12:00, 12:01, and 12:02 UTC. No real route or personal history was used.

The database contained exactly those three nonzero records after both Test
Connection and batch delivery. Dawarich's tagged `Points::NullIsland` service
rejects points within 5 km of 0,0; its intake silently discards them. Native
Test Connection sends 0,0. This explains why a 201 connection response did not
add a fourth record and must not be treated as persistence proof.

Local artifacts: `/private/tmp/isome-dawarich-native.log`, receiver configuration
and before/after JSON under `/private/tmp/isome-dawarich-qa/`. Credentials and
raw receiver logs are not publication artifacts.

## Scope of the public guide

Published intent owner `/integrations/dawarich/`, with a small `/integrations/`
directory linking the checked receiver workflow and existing manual Obsidian
handoff. Added contextual links from webhook/export docs, the blog hub, and
homepage FAQ. Existing aggregate measurement derives its exact page allowlist
from the generated manifest; no new campaign or analytics dimension was added.

The guide clearly separates native batch transmission and destination
persistence from physical recording, the complete settings/purchase UI,
production HTTPS, background continuity, and durable offline replay. The
OwnTracks array shape concern remains; its compatibility is not inferred from
the successful Overland test. The public sample is not an iso.me restore file.
No ranking, demand, or conversion result is inferred from publication.

## Website verification

Static build passes: 31 HTML pages including the 404 template, 30 Markdown
pages, 1,031 local targets, metadata, JSON-LD, fragment/ARIA IDs, and sitemap
coverage. The new page allowlist entries are generated; existing acquisition
and privacy regression tests pass (five tests, zero failures).

Local Lighthouse 13.5.0 checks of the new integration directory, Dawarich guide,
homepage, blog hub, webhook docs, and export docs all score 100 in performance,
accessibility, best practices, and SEO on both mobile and desktop. A mobile DOM
check caught a table-wrapper class error despite Lighthouse's 100 result. Fixed
it to use the existing `table-scroll` container and rechecked: viewport and
document width are both 390 px; the table scrolls within a 358 px region.
The corrected guide also passed a separate final mobile/desktop Lighthouse
recheck with all four categories at 100. This is
lab quality evidence, not Google indexation, rankings, or field Web Vitals.

Sample SHA-256:
`1f37c770c6348fb01297fc0591f3b9f108c8073542e35e130aa78b0728567a5f`.
Screenshot SHA-256:
`5e78fdd6d187650e59bd05abd6f187064f6cf607c6965666276792633b9c7cc9`.

After recording the evidence, closed the temporary receiver browser tab,
removed its dedicated containers/network/volumes, removed the key and environment
files, and removed the credential-bearing test from the temporary native source.
Only the redacted template is committed. The temporary Colima profile and its
container data were deleted successfully. The active Docker context was not
switched, and other runtime profiles were not stopped or deleted.

## Publication

Committed and pushed on `main` as `3692033`. Production Pages deployment short
ID `998d16ed`: https://998d16ed.spotted-8ez.pages.dev.

- All 30 live HTML/Markdown pairs and representation, error, API contract,
  cache separation, methods, and asset checks pass.
- New directory and Dawarich guide both score 100 in all four Lighthouse
  categories on mobile and desktop against production. Reports are retained
  under `/private/tmp/isome-seo-dawarich-after/`; local six-page sweep is under
  `/private/tmp/isome-seo-dawarich-before/`, with corrected guide recheck under
  `/private/tmp/isome-seo-dawarich-layout-final/`.
- The live payload and screenshot return 200 and match the hashes above; the
  sample has the intended attachment filename.
- Live mobile DOM check: viewport and document width both 390 px, table
  overflow contained, expected heading/download link and JSON-LD present.
- No Google indexing request was submitted for these new URLs; they are in the
  live sitemap. Publication and Lighthouse results do not establish indexing.
