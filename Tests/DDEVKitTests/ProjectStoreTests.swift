import XCTest
@testable import DDEVKit

final class ProjectStoreTests: XCTestCase {
    private func fixtureString(_ name: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: nil))
        return try String(contentsOf: url, encoding: .utf8)
    }

    @MainActor
    private func makeStore(runner: MockCommandRunner) -> ProjectStore {
        ProjectStore(
            service: DDEVService(runner: runner, executablePath: "/opt/homebrew/bin/ddev"),
            engineProbe: EngineProbe(runner: runner, dockerPath: nil)
        )
    }

    @MainActor
    func test_refresh_populatesProjectsAndClearsError() async throws {
        let runner = MockCommandRunner()
        runner.results["list -j"] = CommandResult(stdout: try fixtureString("ddev-list.jsonl"), stderr: "", exitCode: 0)
        let store = makeStore(runner: runner)

        await store.refresh()

        XCTAssertFalse(store.projects.isEmpty)
        XCTAssertNil(store.lastError)
    }

    @MainActor
    func test_refresh_failingRunner_setsErrorAndLeavesProjectsEmpty() async {
        let runner = MockCommandRunner()
        runner.defaultResult = CommandResult(stdout: "", stderr: "boom", exitCode: 1)
        let store = makeStore(runner: runner)

        await store.refresh()

        XCTAssertNotNil(store.lastError)
        XCTAssertTrue(store.projects.isEmpty)
    }

    @MainActor
    func test_start_marksBusyDuringCallThenRefreshes() async throws {
        let runner = MockCommandRunner()
        runner.results["list -j"] = CommandResult(stdout: try fixtureString("ddev-list.jsonl"), stderr: "", exitCode: 0)
        let store = makeStore(runner: runner)

        await store.start("my-site")

        XCTAssertFalse(store.isBusy("my-site"))
        XCTAssertEqual(runner.invocations.first, ["start", "-y", "my-site"])
        XCTAssertTrue(runner.invocations.contains(["list", "-j"]))
    }

    @MainActor
    func test_actionFailure_surfacesErrorAndClearsBusyFlag() async {
        let runner = MockCommandRunner()
        runner.results["start -y my-site"] = CommandResult(stdout: "", stderr: "nope", exitCode: 1)
        let store = makeStore(runner: runner)

        await store.start("my-site")

        XCTAssertNotNil(store.lastError)
        XCTAssertFalse(store.isBusy("my-site"))
    }
}
