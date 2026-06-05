import SwiftUI
import Notelet

// MARK: - In-app release notes

enum IsoMeReleaseNotes {
    static let notes: [NoteletVersionNotes] = [
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
