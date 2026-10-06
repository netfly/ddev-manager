import XCTest
@testable import DDEVKit

final class DDEVServiceTests: XCTestCase {
    func test_list_usesListJsonAndParses() async throws {
        let runner = MockCommandRunner()
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/ddev-list.jsonl", withExtension: nil))
        let out = try String(contentsOf: url, encoding: .utf8)
        runner.results["list -j"] = CommandResult(stdout: out, stderr: "", exitCode: 0)

        let service = DDEVService(runner: runner, executablePath: "/opt/homebrew/bin/ddev")
        let projects = try await service.list()

        XCTAssertFalse(projects.isEmpty)
        XCTAssertEqual(runner.invocations.first, ["list", "-j"])
    }

    func test_start_passesProjectName() async throws {
        let runner = MockCommandRunner()
        let service = DDEVService(runner: runner, executablePath: "/opt/homebrew/bin/ddev")
        try await service.start("my-site")
        XCTAssertEqual(runner.invocations.first, ["start", "-y", "my-site"])
    }

    func test_stop_passesProjectName() async throws {
        let runner = MockCommandRunner()
        let service = DDEVService(runner: runner, executablePath: "/opt/homebrew/bin/ddev")
        try await service.stop("my-site")
        XCTAssertEqual(runner.invocations.first, ["stop", "my-site"])
    }

    func test_nonZeroExit_throwsCommandFailed() async {
        let runner = MockCommandRunner()
        runner.defaultResult = CommandResult(stdout: "", stderr: "boom", exitCode: 1)
        let service = DDEVService(runner: runner, executablePath: "/opt/homebrew/bin/ddev")
        do {
            try await service.start("x")
            XCTFail("expected throw")
        } catch let error as DDEVError {
            guard case .commandFailed(_, 1, let msg) = error else { return XCTFail("wrong case: \(error)") }
            XCTAssertTrue(msg.contains("boom"))
        } catch { XCTFail("wrong error \(error)") }
    }

    func test_poweroff_sendsPoweroff() async throws {
        let runner = MockCommandRunner()
        let service = DDEVService(runner: runner, executablePath: "/opt/homebrew/bin/ddev")
        try await service.poweroff()
        XCTAssertEqual(runner.invocations.first, ["poweroff"])
    }
}
