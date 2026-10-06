import XCTest
@testable import DDEVKit

final class ColimaControllerTests: XCTestCase {
    func test_start_noPath_throwsCliNotFound() async {
        let runner = MockCommandRunner()
        let controller = ColimaController(runner: runner, path: nil)

        do {
            try await controller.start()
            XCTFail("expected throw")
        } catch let error as DDEVError {
            XCTAssertEqual(error, .cliNotFound)
        } catch { XCTFail("wrong error \(error)") }
    }

    func test_start_success_runsColimaStart() async throws {
        let runner = MockCommandRunner()
        let controller = ColimaController(runner: runner, path: "/opt/homebrew/bin/colima")

        try await controller.start()

        XCTAssertEqual(runner.invocations.first, ["start"])
    }

    func test_start_failure_throwsCommandFailed() async {
        let runner = MockCommandRunner()
        runner.defaultResult = CommandResult(stdout: "", stderr: "vm failed", exitCode: 1)
        let controller = ColimaController(runner: runner, path: "/opt/homebrew/bin/colima")

        do {
            try await controller.start()
            XCTFail("expected throw")
        } catch let error as DDEVError {
            guard case .commandFailed(_, 1, let msg) = error else { return XCTFail("wrong case: \(error)") }
            XCTAssertTrue(msg.contains("vm failed"))
        } catch { XCTFail("wrong error \(error)") }
    }

    func test_isAvailable_reflectsPath() {
        let runner = MockCommandRunner()
        XCTAssertFalse(ColimaController(runner: runner, path: nil).isAvailable)
        XCTAssertTrue(ColimaController(runner: runner, path: "/opt/homebrew/bin/colima").isAvailable)
    }
}
