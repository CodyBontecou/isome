import Foundation
import OSLog
import SwiftData

enum ModelContainerRecovery {
    enum Mode: Equatable {
        case persistent
        case inMemoryFallback(ContainerFailure)
    }

    struct ContainerFailure: Equatable {
        let operation: String
        let errorType: String
        let message: String

        var diagnosticSummary: String {
            "\(operation) failed with \(errorType): \(message)"
        }
    }

    struct Startup {
        let container: ModelContainer
        let mode: Mode

        var isPersistent: Bool {
            if case .persistent = mode { return true }
            return false
        }
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.bontecou.isome",
        category: "model-container"
    )

    static var schema: Schema {
        Schema([
            Visit.self,
            LocationPoint.self
        ])
    }

    static func persistentConfiguration() -> ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
    }

    static func inMemoryConfiguration() -> ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true
        )
    }

    static func makePersistentContainer() throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: [persistentConfiguration()])
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: [inMemoryConfiguration()])
    }

    static func makeStartup(
        persistentFactory: () throws -> ModelContainer = makePersistentContainer,
        inMemoryFactory: () throws -> ModelContainer = makeInMemoryContainer
    ) -> Startup {
        do {
            let container = try persistentFactory()
            logger.info("SwiftData model container opened in persistent mode")
            return Startup(container: container, mode: .persistent)
        } catch {
            let failure = sanitizedFailure(operation: "Persistent SwiftData container initialization", error: error)
            logger.error("\(failure.diagnosticSummary, privacy: .public)")

            do {
                let fallback = try inMemoryFactory()
                logger.warning("Using in-memory SwiftData fallback after persistent store initialization failed")
                return Startup(container: fallback, mode: .inMemoryFallback(failure))
            } catch {
                let fallbackFailure = sanitizedFailure(operation: "In-memory SwiftData fallback initialization", error: error)
                logger.critical("\(fallbackFailure.diagnosticSummary, privacy: .public)")
                preconditionFailure("IsoMe could not create a persistent or in-memory SwiftData container: \(fallbackFailure.diagnosticSummary)")
            }
        }
    }

    static func sanitizedFailure(operation: String, error: Error) -> ContainerFailure {
        let rawMessage = String(describing: error)
        let message = rawMessage
            .replacingOccurrences(of: #"-?\d{1,3}\.\d{5,}"#, with: "[coordinate]", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)(authorization|bearer|token|webhook|secret|api[-_ ]?key)[^,\n ]*"#, with: "[redacted]", options: .regularExpression)

        return ContainerFailure(
            operation: operation,
            errorType: String(reflecting: type(of: error)),
            message: String(message.prefix(1_000))
        )
    }

    static func diagnosticsText(for failure: ContainerFailure, modeDescription: String) -> String {
        """
        IsoMe data store diagnostics
        Mode: \(modeDescription)
        Operation: \(failure.operation)
        Error type: \(failure.errorType)
        Error: \(failure.message)
        App version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")
        Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown")
        Timestamp: \(ISO8601DateFormatter().string(from: Date()))
        """
    }

    static func resetDefaultStoreFiles() throws {
        let fileManager = FileManager.default
        let supportDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let storeNames = [
            "default.store",
            "default.store-shm",
            "default.store-wal"
        ]

        for name in storeNames {
            let url = supportDirectory.appendingPathComponent(name)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }
}
