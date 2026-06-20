import SwiftUI
import Notelet

// MARK: - In-app release notes

enum IsoMeReleaseNotes {
    private static func releaseNoteVideoURL(_ resourceName: String) -> URL {
        if let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: "mp4",
            subdirectory: "ReleaseNoteVideos"
        ) {
            return url
        }

        if let url = Bundle.main.url(forResource: resourceName, withExtension: "mp4") {
            return url
        }

        assertionFailure("Missing release note video resource: \(resourceName).mp4")
        return URL(fileURLWithPath: "/dev/null")
    }

    static let notes: [NoteletVersionNotes] = [
        .init(
            version: "1.6.2",
            items: [
                .media(
                    kind: .video,
                    url: releaseNoteVideoURL("apple-watch-tracking"),
                    title: "Track from Apple Watch",
                    description: "Start location tracking from your wrist, watch the live timer, and review today’s visits, distance, points, and current location."
                ),
                .list(
                    title: "New Apple Watch app",
                    rows: [
                        .init(
                            symbolSystemName: "applewatch",
                            title: "Track from your wrist",
                            description: "Start or stop iso.me tracking directly on Apple Watch without opening your iPhone."
                        ),
                        .init(
                            symbolSystemName: "figure.walk",
                            title: "Today’s stats at a glance",
                            description: "See visits, distance, location points, current location, and remaining session time right on the watch."
                        ),
                        .init(
                            symbolSystemName: "rectangle.on.rectangle",
                            title: "Watch face complications",
                            description: "Add iso.me to supported watch faces for quick tracking status and today’s totals."
                        )
                    ]
                ),
                .media(
                    kind: .video,
                    url: releaseNoteVideoURL("outings-export"),
                    title: "Export every outing",
                    description: "The Export tab can now write one file per outing, with previews that show the exact format, count, and filenames before you share or save."
                ),
                .media(
                    kind: .video,
                    url: releaseNoteVideoURL("outing-detail-export"),
                    title: "Share a single outing",
                    description: "Open any outing and export it directly in JSON, CSV, Markdown, OwnTracks, Overland, GPX, KML, or GeoJSON."
                ),
                .list(
                    title: "More control over outing exports",
                    rows: [
                        .init(
                            symbolSystemName: "doc.text.magnifyingglass",
                            title: "Markdown pages for your log",
                            description: "Markdown outing exports include YAML front matter, notes, visits, and route points so they drop cleanly into a journal or PKM system."
                        ),
                        .init(
                            symbolSystemName: "tag",
                            title: "Filenames can use outing names",
                            description: "Use {title} or {name} in export paths, and iso.me keeps one-file-per-outing exports distinct automatically."
                        ),
                        .init(
                            symbolSystemName: "point.topleft.down.curvedto.point.bottomright.up",
                            title: "Routes work in every format",
                            description: "JSON and CSV summarize each outing, while GPX, KML, GeoJSON, OwnTracks, and Overland export the route fixes."
                        )
                    ]
                )
            ]
        ),
        .init(
            version: "1.6.1",
            items: [
                .media(
                    kind: .video,
                    url: releaseNoteVideoURL("outings-dashboard"),
                    title: "Outings for every trip",
                    description: "Recorded sessions now live in a dedicated Outings tab, with totals, live/current status, inferred badges, and quick access to every route."
                ),
                .media(
                    kind: .video,
                    url: releaseNoteVideoURL("route-replay"),
                    title: "Replay your route",
                    description: "Open an outing to watch the path play back with a moving marker, scrubber, elapsed time, duration, and distance stats."
                ),
                .media(
                    kind: .video,
                    url: releaseNoteVideoURL("map-focus"),
                    title: "Jump from outing to map",
                    description: "Show an outing on the main map to focus the exact route, start and finish markers, and cleaned-up current visit state."
                ),
                .media(
                    kind: .video,
                    url: releaseNoteVideoURL("visit-renaming"),
                    title: "Name visits faster",
                    description: "Rename stops from nearby business suggestions, filter the list, and reset back to the detected location whenever you need."
                ),
                .media(
                    kind: .video,
                    url: releaseNoteVideoURL("inferred-rules"),
                    title: "Sort and filter outings",
                    description: "Sort your outing history and show or hide inferred historical outings so the timeline matches how you want to review trips."
                )
            ]
        ),
        .init(
            version: "1.5.0",
            items: [
                .list(
                    title: "What’s new in iso.me",
                    rows: [
                        .init(
                            symbolSystemName: "eye",
                            title: "Preview before exporting",
                            description: "Check the destination, file names, counts, warnings, and contents before writing or sharing your location history."
                        ),
                        .init(
                            symbolSystemName: "bell.badge",
                            title: "More dependable daily exports",
                            description: "Scheduled exports now use iOS background wakes, server nudges, and a tap-to-retry fallback notification to run closer to your chosen time."
                        ),
                        .init(
                            symbolSystemName: "folder",
                            title: "Cleaner export organization",
                            description: "File path templates now support folders, more date tokens, and a dated-folder preset for tidy daily archives."
                        ),
                        .init(
                            symbolSystemName: "calendar",
                            title: "Quickly focus on yesterday",
                            description: "New Yesterday filters make it easier to review or export the previous day’s visits and tracks."
                        ),
                        .init(
                            symbolSystemName: "sparkles",
                            title: "A fresh coat of polish",
                            description: "iso.me has a refreshed app icon and updated release polish across the app experience."
                        )
                    ]
                )
            ]
        )
    ]

    static var presentedVersion: NoteletPresentedVersion? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--seed-screenshot-data") { return nil }
        #endif

        return .current
    }

    static let configuration = NoteletConfiguration(
        nextButtonLabel: "Next",
        doneButtonLabel: "Done",
        accentColor: TE.accent
    )
}

extension View {
    func isoMeReleaseNotesSheet() -> some View {
        noteletSheet(
            notes: IsoMeReleaseNotes.notes,
            version: IsoMeReleaseNotes.presentedVersion,
            configuration: IsoMeReleaseNotes.configuration
        )
    }
}
