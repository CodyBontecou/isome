# Backup import: system file picker and app-process restart

October 26, 2026. Follow-up to the earlier incomplete picker attempt and the
successful native disk-import test. This is a live simulator UI check, not a
physical-device migration or an App Store binary test.

## Isolated setup

Reused the already booted `iso-me-country-days-QA` iOS 26.5 simulator,
`5AC67EDC-DE2E-4EE7-AD57-DCBA324C8C6B`, selected through Argent list-devices.
The app is the existing Debug rebuild of verified 1.7.16 (46), source
`6ae78e622c72ee051e6f14113082556c398d926a`, with separate bundle/app-group
prefix `com.bontecou.isome.seorestore`. No normal journal or physical phone
was selected, reinstalled, or cleared. Tracking was off; permission was denied.
Launch arguments skipped onboarding and disabled network geocoding.

SettingsView, LocationViewModel, and ImportService in the temporary source
copy were compared byte-for-byte with the release revision and match. No
importer, picker, save, or UI production code was changed to obtain success.
The isolated build's existing test entitlement showed Family Lifetime; this
is not evidence of a real purchase, restoration of purchases, or free-versus-
paid UI gating. No Apple transaction was performed.

## Observed workflow

1. Started with Settings totals of **0 visits, 0 points**.
2. Opened Settings → Import File. The system document picker eventually
   appeared; native inspection also showed its remote document-browser host.
   Immediate post-tap views still showed Settings. The root cause of the prior
   failed attempt is not established. A later picker-opening wait measured
   6,939 ms, so instant screen inspection is insufficient here.
3. Selected the previously downloaded `synthetic-visits.json`, shown as 641
   bytes. The alert read **Imported 2 visits**. Settings showed **1 visit, 0
   points**, consistent with the previously tested nearby-visit reconciliation.
4. Downloaded `synthetic-points.json` through Safari's actual Download prompt.
   Terminated and relaunched the isolated app. Settings still showed **1
   visit, 0 points**, establishing that the visit survived that restart.
5. Opened Import File again. Recents showed the new points file as 813 bytes.
   Selected it; the alert read **Imported 3 points**.
6. Dismissed the result, terminated and relaunched the app again, navigated
   back to Settings → Data, and checked **1 visit, 3 points** in both the
   screenshot and accessibility tree.

The Map screen's current-range accessibility summary still showed zero visible
records; the files are dated January 1, 2000. That filtered summary is not the
saved journal total. Settings is the count source for this check. No additional
field-level or re-export verification is claimed from these UI counts; the
earlier native disk test provides those distinct checks.

Public fixture hashes remain unchanged:

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| synthetic-visits.json | 641 | 39c9e0f88d8c17865a3e7369eb8f8f46cb9e38dd90d33458fdae2d3b1f50a80a |
| synthetic-points.json | 813 | b728cd33e7c6ae192a966e1e9051545d5b7db76b0d1e48b6fe42aedf16b403f8 |

The picker displayed matching names and byte sizes. Downloaded simulator-file
bytes were not independently extracted in this UI check; the files were
selected from the prior documented synthetic download and the public URL.
They are invented documentation inputs, not captured source-phone exports.

## Evidence and automation limits

Local evidence: `build/seo-evidence/restore-picker-20261026/` includes
`picker.png`, full-resolution `post-restart.png`, and `post-restart.txt`.
The public guide uses the unchanged native post-restart screenshot at
`screenshots/restore-synthetic-after-restart.png` (1206 × 2622).

The first walkthrough was recorded before launch through Argent. Its 39-step
diagnostic trace is retained locally as `unpolished-diagnostic.yaml`, not
offered as a passing automated regression. Nine waits carry cross-tree
conversion warnings: the AX live waits passed, while native runner projection
either lacked the labels or timed out with the app suspended during Safari.
Several taps were reduced to an unsafe role-only ScrollArea selector, and one
Safari tap retained coordinates. Those are not reliable reusable targets.
The original Recents ordering also changed after the downloads/imports; blindly
replaying it could select a different fixture. No uninterrupted automated replay
or two-pass regression verdict is claimed. All functional results above were
checked live with the AX tree and screenshots.

Argent services were stopped only for the simulator used in this check. No
global teardown, fixture deletion, personal data access, binary upload,
campaign change, indexing submission, or scheduled task occurred.

## Website change

The existing backup guide now separates the native field/re-export evidence
from this UI selection/import/restart result. It adds the actual saved-count
screenshot and advises allowing the picker to load before retrying. Remaining
limits are explicit: no physical transfer, captured source-phone export,
purchase-flow proof, or complete device-settings restoration.
