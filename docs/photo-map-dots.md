# Photo dots (Refs #65)

Map → filters → enable **Photo markers**, then **Photo dots**. Dots override
Photo images; that control is disabled while dots are on. Turning dots off
restores the previous image/camera-pin choice. Photo visibility is still a
separate control. The new `showPhotoMarkerDots` preference defaults to false;
`showPhotoMarkerImages` keeps its existing key and default. No local photo or
location data is migrated or removed.

A singleton uses a 10 pt dot and opens the existing full-screen photo browser.
A group uses a 14 pt dot and opens the existing cluster picker. Both have 44 ×
44 pt rectangular hit regions and retain their semantic Button label, value,
and hint. Dot annotations are centered on their coordinates. Group count/time
remain available to VoiceOver and in the picker, not as obstructive map text.
Dot branches never instantiate `PhotoThumbnailView`; browsing retains the
existing PhotoLibraryManager / PHCachingImageManager path. Switching *from*
images to dots cannot undo requests already issued in image mode.

## Evidence / regression coverage

`IsoMeTests/PhotoMapMarkerTests.swift` is registered in the `IsoMeTests` Sources
phase. The shared IsoMe scheme runs it through the existing read-only,
cancel-in-progress, 30-minute GitHub-hosted `xcodebuild-tests.yml` PR workflow.

| Issue criterion | Source and named test |
| --- | --- |
| Reachable mode, persistent across launches | `QuickFilterBar` Photo dots binding and `LocationMapView` AppStorage; `testModeSwitchingPreservesLegacyImageAndPinChoices`, `testAppStoragePersistsDotsAndDoesNotOverwriteLegacyPreference` use a private defaults suite and new wrappers/store instances |
| Singleton/group drill-down | Existing selection callbacks and full-screen/sheet presentations retained; `testSingletonAndClusterActivationKeepsDrillDownInEveryMode` checks the Buttons' activation callbacks and deterministic cluster membership |
| No map thumbnails in dots | Both markerContent branches choose `PhotoMapDot` before images; `testRenderedDotsDoNotRequestThumbnailsAndSwitchingToImagesDoes` mounts the real singleton/group views with an injected request spy; image mode is the positive control |
| Accessibility and usable targets | Semantic Buttons retain photo/group labels, values, hints; `PhotoMapDot` has a rectangular contentShape and 44 pt frame; `testDotLayoutKeeps44PointTargetForSingleAndGroupedPhotos` measures hosted SwiftUI layout |
| Tests included in CI | Explicit project file/group/build membership and shared test scheme; all five focused tests run with the app's XCTest suite |

## Verification limits / required device pass

No local builds, tests, simulator run, photo-library access, or device QA were
performed in the source-only issue lane. Cloud execution results belong in the
PR/lane report, not assumed here. Callback tests are not physical tap tests;
defaults tests recreate wrappers but do not relaunch the app process.

Before marking ready, use an iPhone with permitted **test-only** Photos assets:

1. With images on, enable dots; confirm only small dots are visible. Repeat
   starting from compact pins. Disable dots and confirm each prior choice returns.
2. Relaunch with dots enabled; verify mode and photo visibility persist.
3. Tap a singleton and a group (including close neighbors) and verify full-screen
   browsing / picker and navigation to every grouped photo.
4. Use VoiceOver to check photo dates, group count/time, hints and activation;
   check 44 pt target usability and overlapping targets at dense map zoom levels.
5. With a Photos request diagnostic tool, confirm a cold dot-only map makes no
   thumbnail requests and opening the picker/browser loads images normally.

The PR stays draft and the issue stays open until cloud checks and required
interaction/accessibility QA have concrete evidence. No hardware evidence is
claimed by the source or hosted callback/layout tests.
