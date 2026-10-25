# iPhone 17 Pro Shortcuts QA

Date: 2026-10-25. Device: connected iPhone 17 Pro, iOS 27.0.1. App commit: `2d6adb0` (`codex/manual-visit-shortcuts`). A signed Debug build completed successfully and was installed as an update.

## Results

| Flow | Result |
| --- | --- |
| Check-in link | Passed: supplied QA name and coordinates prefilled the form. |
| Overlap in app | Passed: save stopped at Overlapping Visit; Save Anyway explicitly allowed the test record. |
| Saved place | Passed: QA reusable place appeared in the Shortcuts entity picker. |
| Past-log link | Passed: supplied arrival and departure appeared with the correct local times; cancelled without saving. |
| Invalid link | Passed: invalid coordinates displayed a Visit Link error. |
| Check In through Shortcuts | Passed: default overlap setting blocked the duplicate; explicitly enabling Allow Overlap returned Checked in at QA Shortcuts Cafe. |
| Ambiguous Check Out | Passed: two open QA visits prompted Which visit should be checked out?, distinguished by arrival date/time. |
| Selected checkout | Passed: the chosen visit completed; the other QA visit remained available in the open-visit picker. |
| Explicit checkout | Passed: selecting the remaining QA visit returned a success dialog. |
| Repeated checkout | Passed: running the shortcut again with the same selected visit reported that it was already checked out. |

Both actions executed while Shortcuts remained in the foreground. GPS permission and fresh-fix acquisition were not exercised on hardware; this run used supplied coordinates and a saved place. Automated coverage includes permission-denied errors and avoiding GPS for explicit destinations. No code fixes were needed.

## Recordings and fixtures

QuickTime captured the physical phone screen. The review copy removes audio and shortens static pauses. All media stays local under the ignored `build/qa-iphone17-shortcuts/` directory:

- `iphone17-shortcuts-qa.mp4`: 54-second review video, 720 × 1566, H.264.
- `iphone17-links.mov`: full visit-link walkthrough.
- `iphone17-shortcut-check-in.mov`: full overlap failure and successful Check In.
- `iphone17-shortcut-check-out.mov`: full disambiguation, checkout and repeated-checkout protection.
- PNG evidence for each key result.

Review video order: links at 0:00, Check In at 0:19, Check Out at 0:32.

The test created two visits named QA Shortcuts Cafe, one reusable place with that name, and two shortcuts named QA iso.me Check In and QA iso.me Check Out. Both QA visits were checked out. These fixtures remain available for inspection. The Check Out shortcut deliberately retains its closed QA visit to demonstrate repeated-checkout protection.

The exploratory Argent trace is diagnostic evidence, not a replay-verified regression test. Several native Shortcuts controls required coordinate fallback or produced inaccurate recorded selectors; repeating the entire trace against a personal journal would create more test visits. The video and live result checks establish the observed behavior.
