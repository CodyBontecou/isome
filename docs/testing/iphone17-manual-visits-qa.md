# iPhone 17 Pro manual visit QA — October 25, 2026

Device: connected physical iPhone 17 Pro, iOS 27.0.1.
Build: Debug build of the manual-visit-completion working tree, based on main 6ae78e6.

An isolated QA copy was built in `/private/tmp/isome-iphone17-qa-src` and installed as `com.bontecou.isome.manualqa`. Bundle IDs were changed and app-group/push entitlements removed only in the temporary copy. The production installation was preserved. The existing screenshot seeder supplied synthetic visits; one fictional saved place, QA Cafe, was added only to that QA seeder. Location permission was denied for the QA copy.

## Results

- PASS: select the fictional saved place and create an open manual visit.
- PASS: overlapping times show the conflicting place and offer Cancel / Save Anyway.
- PASS: Cancel preserves the draft; Save Anyway persists the manual record alongside the automatic visit.
- PASS: Timeline identifies the new visit as Confirmed / Manual.
- PASS: Check Out records the departure time, switches Still here off, and removes the Check Out button.
- PASS: return to Timeline and restart without the seeding argument; the same departure time and Manual status remain stored.
- FINDING: the newly created visit does not immediately appear on the map with the existing Today range. `handleManualVisitSaved` only updates the date range for past visits; the current range can end before the new visit's arrival. Returning to the map refreshes the preset. This is a map presentation gap; persistence and Timeline remain correct.

## Review artifacts

All media is under `build/qa-iphone17/` (untracked, excluded build output):

- `manual-visit-qa-review.mp4`: 37-second review. First 29 seconds are the actual USB screen recording of creation and overlap handling. Final eight seconds are clearly documented here as before/after device screenshots of Check Out, four seconds each.
- `iphone17-overlap.mp4`: usable continuous USB recording, without audio.
- `check-out-before.png` and `check-out-after.png`: actual physical-device screenshots.
- `iphone17-setup.mov`: longer setup capture.
- `device-walkthrough-diagnostic.yaml`: raw recorded device actions. It includes a USB interruption and failed waits while a release-notes sheet was covering the app. Those waits were resolved manually. This file is diagnostic, not a passing automated regression test.

QuickTime USB capture stopped during the app-restart portion. A second capture attempt failed, so the review uses the recorded overlap segment plus device screenshots for Check Out. The final MP4 was probed and decoded successfully with ffprobe/ffmpeg.

The iOS core flow was checked live. This report does not claim continuous video coverage of the restart or a clean automated replay.
