You are Symphony, an autonomous coding agent working on GitHub issue CodyBontecou/isome#18: Auto-detect active vehicle via Bluetooth connection.

Issue URL: https://github.com/CodyBontecou/isome/issues/18
Issue author: CodyBontecou

Issue body:
## Summary

When the phone connects to a known vehicle's Bluetooth (head unit, hands-free profile, or registered BLE accessory), automatically tag the resulting drive with that vehicle. Mirrors MileIQ's "Vehicles" auto-pairing behavior.

## Motivation

Removes the manual "which car was I in?" classification step for users with multiple vehicles, which is the main friction point for self-employed drivers and households with shared cars.

## Approach

iOS does **not** expose general Bluetooth peer info to third-party apps. The realistic options:

1. **CarPlay / handsfree route detection** — `AVAudioSession.routeChange` notifications include the connected device's `portType` (`.carAudio`, `.bluetoothHFP`, `.bluetoothA2DP`) and `portName` (the head unit's advertised name). On route-change to one of those ports while tracking is active, look up the matching vehicle by saved `portName` and tag the session.
2. **External Accessory framework** — for users with a registered MFi/BLE OBD dongle, watch for the accessory's UID.
3. **Manual fallback** — let the user tap "use this vehicle for this trip" if no match was found, and remember the choice.

## Proposed UX

- In **Settings → Vehicles**, each vehicle has a "Pair with Bluetooth device" button that listens for the next route-change and saves the current `portName` (e.g. "Mazda CX-5", "Tesla Model 3").
- On the next trip that triggers that route, the session is auto-tagged with the vehicle, and the trip card shows a small Bluetooth icon to indicate auto-detection (so the user can trust/verify it).
- If multiple vehicles share a head-unit name (rare), prompt the user once and remember the choice.

## Dependencies

- Requires the **multi-vehicle support** ticket to land first (need a vehicle list to pair against).

## Acceptance criteria

- [ ] User can pair a vehicle with a Bluetooth device by tapping a button while connected to it.
- [ ] On subsequent connections, drives started during that route are auto-tagged with the paired vehicle.
- [ ] Trip detail view shows the auto-detected vehicle with a clear "auto" indicator and lets the user override.
- [ ] If no pairing matches, tracking still works and the trip is left vehicle-unset.
- [ ] Documented in the README under Vehicles, including the iOS limitations (no raw BT peer scan).

<!-- isobot:discord-thread:1501666862415610079 -->

Instructions:

1. Work only inside the current repository/workspace.
2. Inspect the codebase and implement the issue as completely as possible.
3. Run the most relevant formatter, tests, typecheck, or build that is practical for this repository.
4. Do not create a pull request yourself; Symphony will commit, push, and open the PR after you exit.
5. Do not wait for human input. If blocked, make the best safe progress and leave notes in your final response.
