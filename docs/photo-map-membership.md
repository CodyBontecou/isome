# Complete photo-map membership (#66)

Refs https://github.com/CodyBontecou/isome/issues/66

## Source diagnosis and contract

At base `08029281f2e30df83e83d06ba08617ce79ed76bd`, the date-range fetch read all metadata but selected 500 photos before clustering. Cluster counts, the grid and full-screen browser therefore could not see omitted members. This is a source-derived detail-access defect, not a measured performance defect or a device reproduction.

`LocationViewModel.loadMapPhotoMoments` now retains all fetched range metadata and builds cached presentation clusters once per reload. Clearing presentation data (including permission loss) also clears clusters. The map consumes that cache instead of reclustering on camera/body changes. Date-range and authorization changes dismiss selected photo details.

- For up to 500 place clusters, preserve the existing chronological, nearest-centroid 35 m grouping, now with complete membership.
- If more than 500 distinct place clusters are encountered, replace the presentation with geographic area cells, doubling cell width until at most 500 annotations remain. No members are sampled away. These groups explicitly say **area**, not that every member shares one place. Grid cells are a rendering policy, not place inference; boundaries can separate nearby photos. Zoom does not alter membership. All members remain accessible through an area group. Extremely broad/global ranges may yield broad groups; narrower date ranges restore place-level presentation.
- Each map marker loads at most three previews. Details supply at most 60 photos per page to the existing `LazyVGrid`; every page is accessible. The full-screen browser receives the **whole** group and loads one selected image, not an eager image-per-member pager.
- Metadata is still fetched in full (as before); this change retains it for detail access. No large-library latency/memory benchmark is claimed. Existing PhotoKit caching, sync reconciliation, export and SwiftData schema are unchanged. No original assets or cached metadata are deleted for map density.

Apple documents `LazyVGrid` as creating items only as needed: https://developer.apple.com/documentation/swiftui/lazyvgrid (public documentation consulted during implementation). Pagination additionally bounds the number of thumbnail view candidates regardless of the group's size.

## Criterion-to-regression mapping

All tests are in `IsoMeTests/PhotoMomentMembershipTests.swift`, registered in the Xcode project's IsoMeTests Sources phase and its shared IsoMe scheme. `.github/workflows/xcodebuild-tests.yml` runs that scheme on free GitHub-hosted `macos-latest` for PRs, with read-only permissions, concurrency cancellation and a 30-minute timeout. No local tests/builds were run in the source-only lane.

| Issue criterion | Source and executable regression evidence |
| --- | --- |
| 501 same-place count and all-member browsing | `PhotoMomentCluster`, cluster quick view and full-screen initializer; `test501SamePlaceHasCompleteCountPagesAndFullScreenMembership` checks 501, sorted IDs, all nine pages and all 501 browser navigation indices including wraparound. |
| Bounded rendering without discarded detail membership | View-model complete metadata/cache; builder's 500-annotation cap and area fallback; `testMoreThan500DistinctPlacesCoarsensAnnotationsWithoutDroppingMembers` checks 1,001 distinct places, cap, exact ID union/no duplicates, and single-annotation fallback. |
| Bounded/lazy large details | `PhotoMomentDetailPage` caps the grid slice at 60; `LazyVGrid` and one-image browser; first test checks every page's bound and full-screen membership; `testDetailPageClampsEmptyAndOutOfBoundsRequests` checks edge cases. No UI request tracing/device memory claim. |
| Above 500, multiple places, date changes | `testAbove500AcrossMultiplePlacesPreservesEachPlaceAndStableOrder` covers 1,001 + 701 photos, two complete place counts and deterministic ordering. `testDateRangeReloadAndAuthorizationClearOnlyPresentationNotStoredMetadata` exercises the real SwiftData loader over 501/601/empty ranges and denied/limited authorization via an injected provider, without requesting real Photos permissions. |
| No asset/cache deletion for density | No PhotoLibraryManager, schema, sync deletion or reconciliation edits. Date-range/authorization regression verifies all 1,102 inserted metadata IDs remain in SwiftData after reloads. Tests use metadata only, not Photos assets. |

## Required device QA (not performed)

Keep the issue open and PR draft until the following is reviewed:

1. Use a disposable test Photos library with 501 same-coordinate assets inside one range. Verify the complete count, nine grid pages, last asset, full-screen next/previous and wraparound.
2. Repeat with several places, then more than 500 places. Verify bounded markers, area labels, discoverability/taps and accessible counts. Review broad-area UX, cell-boundary behavior and dense-marker overlap.
3. Change date ranges, including to empty; verify details dismiss and membership reloads. Revoke/grant limited/full access and verify no stale details.
4. Trace image requests while opening/paging/scrolling details and browsing full screen, including iCloud-only/unavailable assets. Check UI responsiveness and memory on a large library; hosted metadata tests do not measure these.
5. Confirm original assets and cached metadata survive map interactions. Do not delete personal assets to prepare fixtures.

Related PR #67 changes marker presentation in the same two view files. It is not duplicated here; integration may need a small conflict resolution after independent review.
