# Manual visit Shortcuts and links (#76)

## Shortcuts

In Shortcuts, add an iso.me **Check In** action. Select a Saved Place, or enter a Place Name plus both Latitude and Longitude. With neither destination supplied, the action requests one fresh location fix (maximum age 30 seconds, accuracy within 100 metres, 12 second timeout). Existing location permission is required; the action never prompts for permission or starts tracking. Explicit destinations work without location permission and can execute in the background.

Arrival Time defaults to now and may be in the past. Allow Overlap defaults to off. An overlapping visit fails with a useful error unless the shortcut author explicitly enables Allow Overlap. Combining a saved place with coordinates, supplying only one coordinate, invalid coordinates, empty names, missing saved places and future arrival times fails without inserting a visit.

Add **Check Out** to finish a manual visit. Set Visit to the output of Check In to address the exact record. Alternatively select an open visit from the picker. If Visit is omitted, the action finishes the only open manual visit; with multiple open visits it asks which one, and with none it reports an error. Stale selections, repeated checkout, automatic/imported visits, departure before arrival and future departure fail without changing the record. The picker includes arrival date/time to distinguish equal place names.

Both actions return a Visit for chaining. The mutations preserve source, confirmation, place provenance and original detection/correction fields. The app and intents call ManualVisitStore; intents do not construct the map view model or enable tracking. A live foreground context is reused to update visible model identities; cold launches open the same SwiftData configuration as the app.

Check In uses the app's remaining tenth App Shortcut card. Check Out is available in the action search when composing a shortcut. Existing App Shortcut cards remain available. Apple limits automatically supplied App Shortcuts to ten per app.

## Deep-link contract

Links open editable forms or details, never silently save or check out a visit:

- `isome://check-in`
- `isome://check-in?name=Cafe&latitude=18.2&longitude=-67.1`
- `isome://log-visit`
- `isome://log-visit?name=Library&latitude=18.2&longitude=-67.1&arrival=2026-10-23T15:00:00Z&departure=2026-10-23T16:00:00Z`
- `isome://visit/<visit-UUID>`

Name and coordinate pairs are optional. Coordinates use decimal degrees. Times use ISO 8601 including a timezone, must not be in the future, and must be ordered. A past-log link supplies both times or neither; without times its form starts with the last hour. Check-in accepts optional arrival only. Form saves retain the normal overlap confirmation.

Duplicate/unknown parameters, missing values, partial/invalid coordinates, empty names, invalid dates, credentials, ports, fragments, unexpected paths and invalid UUIDs are rejected. Overlap overrides cannot be passed through URLs. A missing visit displays a useful error. A link received before initialization/onboarding waits for the map; a link received while a sheet is open waits for that sheet to close, preserving unfinished edits. The existing stop-tracking and myself claim routes are retained.

## Verification

Automated tests use fresh in-memory containers and verify persistence from a second context, actual intent perform calls, explicit destination GPS avoidance, permission errors, invalid coordinates/times, missing places, overlap override, ambiguous/missing/repeated checkout, automatic/imported record protection, correction metadata and malformed/valid URL routes.

Validated on 2026-10-25 with Xcode and the dedicated iOS 26.5 simulator:

- Final full run: 318 XCTest cases and 10 Swift Testing tests passed (including 14 malformed-link parameter cases). `xcodebuild test` completed with TEST SUCCEEDED.
- Compiled App Intents metadata includes CheckInIntent and CheckOutIntent. Shortcuts displays the Check In card and finds Check Out in action search.
- Shortcuts Check Out executed after terminating iso.me, showed “Checked out of Shortcut Cafe”, and persisted the departure in the shared simulator SwiftData store. No foreground app handoff was required. Both actual intent perform methods also pass the injected-store test; physical iPhone 17 Pro QA subsequently verified saved-place Check In and Check Out through Shortcuts (see iphone17-shortcuts-qa.md).
- Check-in URL prefilled name and coordinates; saving encountered the expected overlap warning and required Save Anyway. Stored metadata remained manual/confirmed.
- Visit UUID URL opened the saved record in Visit Details.
- Past-log URL prefilled both times correctly. A second link left the unfinished form intact, then opened the queued check-in form after Cancel.
- Invalid coordinates produced the Visit Link error instead of opening or saving a form.

Local evidence: `/private/tmp/isome76-qa/evidence/` and `/private/tmp/isome76-verified-tests.log`. Captures contain synthetic simulator data only. Exploratory Argent recordings live under `/private/tmp/isome76-qa/.argent/e2e/`; they are not claimed as replay-verified regression tests.

### PR #80 shared visit-count regression

A focused test reproduced a successful background check-in leaving both the App Group snapshot and TodayVisitCountIntent at the old value (99 rather than 2). ManualVisitStore now recounts today's persisted visits after a successful insert, updates only the shared visit count, and reloads widget timelines. It does not create a LocationManager or start tracking. The regression also verifies that previous/next-day visits are excluded and cached GPS, distance, point count, timestamp, units and disabled tracking state are preserved. The full suite passes: 318 XCTest cases and 11 Swift Testing tests.
