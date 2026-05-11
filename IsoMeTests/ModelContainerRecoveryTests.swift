import SwiftData
import XCTest
@testable import IsoMe

@MainActor
final class ModelContainerRecoveryTests: XCTestCase {
    private struct ForcedFailure: Error, CustomStringConvertible {
        var description: String {
            "could not open store near 37.774900 and token=super-secret-value"
        }
    }

    func testStartupFallsBackToInMemoryContainerWhenPersistentContainerFails() throws {
        let startup = ModelContainerRecovery.makeStartup(
            persistentFactory: { throw ForcedFailure() },
            inMemoryFactory: { try ModelContainerRecovery.makeInMemoryContainer() }
        )

        guard case .inMemoryFallback(let failure) = startup.mode else {
            return XCTFail("Expected startup to use the in-memory fallback")
        }

        XCTAssertFalse(startup.isPersistent)
        XCTAssertEqual(failure.operation, "Persistent SwiftData container initialization")
        XCTAssertTrue(failure.message.contains("[coordinate]"))
        XCTAssertFalse(failure.message.contains("37.774900"))
        XCTAssertFalse(failure.message.contains("super-secret-value"))
    }

    func testDiagnosticsAvoidPreciseLocationAndSecretValues() {
        let failure = ModelContainerRecovery.sanitizedFailure(
            operation: "Test operation",
            error: ForcedFailure()
        )
        let diagnostics = ModelContainerRecovery.diagnosticsText(
            for: failure,
            modeDescription: "Unit test"
        )

        XCTAssertTrue(diagnostics.contains("Test operation"))
        XCTAssertFalse(diagnostics.contains("37.774900"))
        XCTAssertFalse(diagnostics.contains("super-secret-value"))
    }
}
