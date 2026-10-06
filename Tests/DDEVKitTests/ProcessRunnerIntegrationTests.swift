import XCTest
@testable import DDEVKit

final class ProcessRunnerIntegrationTests: XCTestCase {
    func test_realDdevList_parses() async throws {
        guard let path = DDEVService.resolveExecutable(override: nil) else {
            throw XCTSkip("ddev not installed")
        }
        let projects = try await DDEVService(runner: ProcessRunner(), executablePath: path).list()
        XCTAssertFalse(projects.isEmpty, "expected at least one ddev project on this machine")
    }
}
