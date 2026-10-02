# Complete photo-map membership (#66)

Refs https://github.com/CodyBontecou/isome/issues/66

## Contract and corrective follow-up

At base `08029281f2e30df83e83d06ba08617ce79ed76bd`, all range metadata was fetched but only 500 photos were supplied to clustering/details. The first draft (`853e722`) removed that sample, but independent review found two P1 gaps: overflow cells repartitioned nearby place members, and selected/nested details survived same-range or readable-permission changes. This follow-up corrects those source paths; it is not a physical reproduction or a measured performance improvement.

### Complete places, bounded annotations, reachable drill-down

- Build **all** place groups first, using chronological nearest-centroid grouping within 35 metres. A 3-D spatial hash searches neighbouring metre-sized cells, not all established places for each distinct photo. Spherical centroids and the index cover the dateline; the final membership check still uses `CLLocation.distance`. This changes centroid arithmetic from the old latitude/longitude mean, avoiding fictitious dateline locations.
- If places exceed 500, coarsen **whole established place groups** into geographic areas until at most 500 annotations remain. Never split a place across area cells. Each area retains its complete place directory and photo membership. Its anchor is one actual member place, not a claim that every member shares that coordinate.
- Tapping an area opens **Photos in This Area**, a paged directory of its complete places. The map also offers **Browse N photo places**, independent of the viewport: every matched place remains reachable even when an area's anchor is off-screen. Rows show coordinates, dates and complete counts; opening a row accesses the complete place collection. Neither zoom nor a narrower date range is required to recover hidden members.
- Place-directory pages and detail-grid pages are bounded to 60 entries. The grid is a `LazyVGrid`. Full-screen browsing receives the whole selected place and requests the currently selected image. Area anchors can remain broad and overlap: physical MapKit/discovery/VoiceOver QA is still required.

### Accessibility and presentation revisions without deleting metadata

- `mapPhotoMoments` retains complete cached range metadata. `mapAccessiblePhotoMoments`, counts, places and annotations contain only identifiers currently returned by `PHAsset.fetchAssets(withLocalIdentifiers:options:)`. Identifier lookup uses batches of 250; inaccessible metadata is not deleted. Outing photo presentation uses the same accessible-ID filter.
- The existing `PHChange` observer now refreshes accessible membership even when automatic metadata sync is disabled. App activation/range loads also re-check it. New uncached metadata still follows the existing explicit/automatic sync policy.
- Value snapshots include member ID, asset identifier, timestamp, coordinates and source, plus authorization state. Relevant revisions synchronously clear shared map, directory, place and nested full-screen selection. Authorized-to-limited changes invalidate even if the current ID subset is identical; changed limited selection invalidates when accessible members change. Range changes clear the chain as well.
- Identical reloads and `lastSyncedAt`-only changes do not rebuild clusters or unnecessarily dismiss details. Metadata still fetches in full; no large-library latency or memory improvement is claimed.
- The existing `PHCachingImageManager`, original asset storage, persisted schemas, exports and sync reconciliation are preserved. Authorized sync's existing missing-GPS-record reconciliation is not a rendering-density deletion policy.

## Executable evidence

All cases remain in the already registered `IsoMeTests/PhotoMomentMembershipTests.swift`. The shared IsoMe scheme and existing read-only GitHub-hosted PR workflow run the suite; no local tests/builds are permitted in this lane. Actual latest-head execution belongs in the PR and additive follow-up report, not inferred from registration.

| Requirement / review finding | Regression |
| --- | --- |
| 501 same-place complete count, ordered members and nine pages | `test501SamePlaceHasCompleteCountPagesAndFullScreenMembership` checks all IDs, page bounds/final 21, and the real browser selection state's forward traversal and wraparound |
| Multiple complete places above 500 photos | `testAbove500AcrossMultiplePlacesPreservesEachPlaceAndStableOrder` |
| Annotation bound without lost membership | `testMoreThan500DistinctPlacesCoarsensAnnotationsWithoutDroppingMembers` |
| P1 mixed overflow / old cell boundary | `testMixedOverflowKeepsBoundaryPlaceIndivisibleAndDirectoryReachesEveryPlace`: 501 shots straddling latitude 38 plus 601 distinct places; the dense place remains indivisible, every place reaches a bounded directory page, area labels/real anchors and one-area fallback are checked |
| Spatial index/dateline/centroid movement | `testSpatialIndexGroupsAcrossDatelineAndTracksMovingCentroids` (not a timing benchmark) |
| Ranges, denied clearing and persistent metadata IDs | `testDateRangeReloadAndAuthorizationClearOnlyPresentationNotStoredMetadata` |
| P1 same-range additions/model edits, nested selection, unchanged reload | `testSameRangeMembershipAndMetadataRevisionsDismissNestedDetailsButUnchangedReloadDoesNot` exercises the shared state bound by actual sheets/covers |
| P1 authorized→limited and changed limited subset via existing observer | `testLimitedSelectionObserverFiltersPresentationAndDismissesAllLevelsWithoutDeletingMetadata`: injected accessible IDs, actual notification subscription with sync off, all selection levels, empty/denied/full restoration and all stored field snapshots |
| P2 actual selected image identifier in a rendered browser | `testHostedBrowserRequestsActualLastFirstAndPreviousSelections`: UIKit hosts the real SwiftUI view; positive loader requests verify last→first→last→previous observable selection transitions |
| P2 rendered first/last bounded grid pages | `testHostedGridRequestsOnlyCurrentBoundedPageWithPositiveRenderingControl`: UIKit hosts the real detail view and loader spy; both first and last pages must issue requests, restricted to the respective 60/21 IDs |
| Empty/out-of-bounds pagination | `testDetailPageClampsEmptyAndOutOfBoundsRequests` |

Hosted tests drive the same observable transitions used by controls; they are not physical taps/swipes, MapKit hit testing, real Photos permission UI, or live image/memory tracing. Request spies return no real images. Ignoring cancelled Swift tasks does not cancel outstanding PhotoKit requests; this follow-up makes no such claim.

## Required physical/runtime gates (not performed)

Keep issue open and PR draft until reviewed:

1. Disposable test Photos library: 501 same-coordinate assets, full count, every page, actual first/last images, arrows/swipes and wraparound.
2. Several places and >500 distinct places with dense shots across cell boundaries, broad/global areas and the dateline: MapKit taps, area directory, all-places entry point independent of viewport, place counts and overlap/discoverability.
3. Open directory/place/nested browser during range and same-range library changes; actual denied/restricted, authorized→limited, changed limited selection and full restoration; no stale detail and no unnecessary dismissal for unchanged reloads.
4. VoiceOver: complete counts, area/place meaning, paging/navigation, entry point and activation.
5. Real image requests with iCloud-only/unavailable assets, rapid navigation, responsiveness and memory; do not infer request cancellation or a measured performance result from hosted spies.
6. Original assets and cached metadata survive presentation/access changes using test-only assets; distinguish intentional existing sync reconciliation from density reduction.

## PR #67 integration gate

No merge/cherry-pick of #67 is included. The follow-up keeps the compatible `PhotoThumbnailLoader`/`loader` extension point needed for hosted detail spies. #67's dots preferences, marker branches and activation must survive later integration with complete membership, directories and area labels. The original build-file/file-reference insertion conflicts in `IsoMe.xcodeproj/project.pbxproj` still require both registrations to be retained. Map selection changes can also require manual integration with #67's call sites. A combined hosted run executing both suites and combined dots/image/pin physical QA remain unresolved; independent green runs do not establish them.
