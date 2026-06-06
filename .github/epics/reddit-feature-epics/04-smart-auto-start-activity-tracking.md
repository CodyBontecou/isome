# Epic: Smart Auto-Start / activity-based tracking

**Source:** Reddit questions about 24/7 usage, auto-start on activity, CarPlay/exercise automation, and Google Maps-style always-on logging  
**Difficulty:** Hard  
**Primary user need:** “I want iso.me to start tracking automatically when I’m moving/driving without me remembering to press Start.”

## Goal

Add explicit opt-in Smart Start tracking that can start route tracking from feasible iOS signals:

1. Shortcuts/App Intents automations for CarPlay, workout, Driving Focus, Bluetooth, or NFC.
2. CoreMotion activity classification when the app is alive or woken.
3. Low-power CoreLocation visit/significant-change monitoring as background wake source.
4. Clear reliability/battery limitations.

MVP should not promise native CarPlay or native workout background execution.

## Product contract

Smart Start should be off by default.

In-app copy should say:

> iso.me can try to start tracking when iOS reports meaningful movement, but iOS may delay or suppress background triggers. Force-quitting the app prevents automatic relaunch until you open it again. Shortcuts automations are the most reliable way to start from CarPlay, workouts, Focus modes, Bluetooth, or NFC.

## Current touchpoints

- `IsoMe/Services/LocationManager.swift` — monolithic tracking lifecycle; visits/significant-change monitoring currently only active while full tracking is on.
- `IsoMe/Info.plist` — has background location usage but no `NSMotionUsageDescription`.
- `IsoMe/Views/SettingsView.swift` — location settings live here; Smart Start should be a new section.
- `IsoMe/Views/ContentView.swift` — onboarding/bootstrapping; currently creates `LocationManager` from view task.
- `IsoMe/Services/IsoMeIntents.swift` — already has Start/Stop Tracking App Intents; best immediate path for CarPlay/workout automations.
- `IsoMe/AppDelegate.swift` — detects background location launch but does not initialize the full service container.
- `IsoMe/Services/DailyDistanceTracker.swift` — stats-only; should not become an implicit auto-start signal until explicitly designed.

## Architecture

### Separate states

Current `isTrackingEnabled` means full high-accuracy route recording. Add separate concepts:

- `smartStartEnabled`: user opted in.
- `ambientMonitoringActive`: low-power visit/significant-change monitors are armed.
- `isTrackingEnabled`: active route recording session.

When Smart Start is on and Always permission exists, ambient monitoring can stay armed while not saving route points.

### New components

- `AutoStartPolicy.swift` — pure, testable policy with no Apple framework dependency.
- `ActivityDetectionManager.swift` — CoreMotion wrapper that emits normalized activity signals.
- `AutoStartCoordinator.swift` — orchestrates policy, motion/location signals, LocationManager, logs, cooldowns.

### LocationManager changes

- Add `TrackingStartSource`: manual, shortcut, smartMotion, carPlayShortcut, workoutShortcut, significantLocationChange, visitDeparture.
- Persist `trackingStartTime`, `trackingStartSource`, `lastManualStopAt`, `lastAutoStartAt`.
- Make start idempotent.
- Add `startTracking(source:allowsPermissionPrompt:)`.
- Split ambient monitoring from active standard location updates.
- Ensure `stopTracking()` does not disarm ambient monitoring when Smart Start remains enabled.
- Use activity-specific `CLLocationManager.activityType` where appropriate.

## Implementation checklist

### Phase 0 — Product and platform guardrails

- [ ] Write final Smart Start UX/permission copy.
- [ ] Add `NSMotionUsageDescription` to `Info.plist`.
- [ ] Document iOS limitations in README/support copy.
- [ ] Clarify that native CarPlay/HealthKit are future/R&D, not MVP.
- [ ] Acceptance: Smart Start is clearly opt-in and limitation-aware.

### Phase 1 — Session state and LocationManager refactor

- [ ] Add `TrackingStartSource`.
- [ ] Persist tracking start time across relaunch.
- [ ] Persist tracking source.
- [ ] Persist `lastManualStopAt` and `lastAutoStartAt`.
- [ ] Add legacy-safe optional shared data fields for source if needed.
- [ ] Add tests for persisted defaults/session metadata.
- [ ] Acceptance: manual tracking still behaves exactly as before.

### Phase 2 — Split ambient monitoring from active tracking

- [ ] Add `startAmbientMonitoring()` and `stopAmbientMonitoring()`.
- [ ] Add `startActiveLocationUpdates()` and `stopActiveLocationUpdates()`.
- [ ] Keep visit/significant-change monitoring armed when Smart Start is enabled.
- [ ] Ensure no route points are saved while ambient-only.
- [ ] Ensure stopping active tracking leaves ambient monitoring armed if Smart Start is still enabled.
- [ ] Acceptance: Smart Start off preserves current behavior; Smart Start on keeps low-power monitors alive.

### Phase 3 — Centralize service boot

- [ ] Move service initialization out of `ContentView.task` where feasible.
- [ ] Ensure background location launches create/wire `LocationManager` with SwiftData context.
- [ ] Avoid duplicate `LocationManager` instances.
- [ ] Keep WebhookManager and daily export attachment working.
- [ ] Acceptance: background location launch path logs manager initialization.

### Phase 4 — AutoStartPolicy

- [ ] Add pure `AutoStartPolicy` types.
- [ ] Model settings, permission state, activity signals, cooldowns, active tracking state.
- [ ] Output start/stop/suppress/noop decisions with reasons.
- [ ] Add comprehensive unit tests.
- [ ] Acceptance: policy tests cover disabled, missing permissions, low confidence, movement thresholds, cooldown, already tracking, stationary stop.

### Phase 5 — ActivityDetectionManager

- [ ] Add CoreMotion wrapper around `CMMotionActivityManager`.
- [ ] Surface availability/permission status.
- [ ] Normalize walking/running/cycling/automotive/stationary confidence.
- [ ] Query recent activity when app wakes from location.
- [ ] Log state transitions without sensitive precise coordinates.
- [ ] Acceptance: handles unavailable/denied CoreMotion gracefully and does not decide start/stop directly.

### Phase 6 — AutoStartCoordinator

- [ ] Wire `ActivityDetectionManager`, `LocationManager`, and `AutoStartPolicy`.
- [ ] Observe app lifecycle and location wake events.
- [ ] Evaluate significant-change and visit events.
- [ ] Start/stop tracking with source metadata.
- [ ] Apply manual-stop cooldown.
- [ ] Log every start/suppress decision.
- [ ] Acceptance: Smart Start off creates no auto behavior; Smart Start on can start from motion/location signals when policy permits.

### Phase 7 — Settings UI

- [ ] Add Smart Start settings section.
- [ ] Toggle Smart Start on/off.
- [ ] Show Always Location and Motion permission statuses.
- [ ] Add activity mode toggles: driving, walking/running, cycling.
- [ ] Add conservative threshold/cooldown settings.
- [ ] Add optional stationary auto-stop setting.
- [ ] Add battery/reliability disclaimer.
- [ ] Acceptance: Smart Start defaults off, denied states link to Settings, UI matches TE design.

### Phase 8 — Onboarding

- [ ] Add optional explanation or post-onboarding card, but do not enable Smart Start by default.
- [ ] Avoid prompting Motion permission until user opts in.
- [ ] Preserve existing onboarding migration behavior.
- [ ] Acceptance: fresh users are not surprised by auto-start.

### Phase 9 — Shortcuts and automation recipes

- [ ] Upgrade `StartTrackingIntent` with optional source/reason, duration, and activity profile.
- [ ] Preserve existing simple phrases.
- [ ] Return useful Shortcuts dialog when permission is missing.
- [ ] Add Settings help/recipes for CarPlay connect/disconnect, workout start/end, Driving Focus, Bluetooth, NFC.
- [ ] Acceptance: users can configure reliable automations without native CarPlay support.

### Phase 10 — Observability and battery tuning

- [ ] Add Smart Start diagnostics to `LogManager` / Log Viewer.
- [ ] Add activity-specific tracking profiles.
- [ ] Tune distance filters for driving/walking/cycling smart sessions.
- [ ] Consider throttling Live Activity updates during auto-started sessions.
- [ ] Add real-device QA checklist and battery notes.
- [ ] Acceptance: QA can explain why Smart Start did or did not start.

### Phase 11 — Real-device QA

- [ ] Test fresh install, When In Use only, Always, Precise off, Motion denied, Low Power Mode, Background App Refresh off, force-quit, reboot.
- [ ] Test manual start/stop, Stop After, Live Activity, Export, Webhook, Watch state regressions.
- [ ] Test Shortcuts foreground/background/locked.
- [ ] Test CarPlay/Bluetooth/workout/Focus automations where possible.
- [ ] Test walking, driving, stationary, manual stop cooldown, low-signal areas.

## Future, not MVP

- Native CarPlay entitlement and UI.
- HealthKit/workout background execution.
- Watch start/stop controls through WatchConnectivity.

## Risks

- iOS background delivery is not guaranteed.
- Force-quit prevents relaunch.
- Background location + motion requires very clear App Review/user-trust copy.
- Battery impact can be high if high-accuracy GPS starts too often.
- False positives: trains, buses, passenger rides, GPS drift, short walks.
- Current `LocationManager` needs careful refactoring to become mockable/reliable.
