import XCTest
@testable import DDEVKit

final class ProjectStoreTests: XCTestCase {
    private func fixtureString(_ name: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: nil))
        return try String(contentsOf: url, encoding: .utf8)
    }

    @MainActor
    private func makeStore(runner: MockCommandRunner, colimaPath: String? = nil) -> ProjectStore {
        ProjectStore(
            service: DDEVService(runner: runner, executablePath: "/opt/homebrew/bin/ddev"),
            engineProbe: EngineProbe(runner: runner, dockerPath: nil),
            colima: ColimaController(runner: runner, path: colimaPath),
            defaults: UserDefaults(suiteName: "ProjectStoreTests.\(UUID().uuidString)")!
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

    @MainActor
    func test_startColima_noPath_setsErrorAndAppendsLog() async {
        let runner = MockCommandRunner()
        let store = makeStore(runner: runner, colimaPath: nil)

        await store.startColima()

        XCTAssertNotNil(store.lastError)
        XCTAssertTrue(store.log.last?.contains("start colima") ?? false)
    }

    @MainActor
    func test_startColima_success_runsColimaStart() async throws {
        let runner = MockCommandRunner()
        runner.results["list -j"] = CommandResult(stdout: try fixtureString("ddev-list.jsonl"), stderr: "", exitCode: 0)
        let store = makeStore(runner: runner, colimaPath: "/opt/homebrew/bin/colima")

        await store.startColima()

        XCTAssertTrue(runner.invocations.contains(["start"]))
        XCTAssertNil(store.lastError)
    }

    @MainActor
    func test_colimaAvailable_reflectsControllerState() {
        let runner = MockCommandRunner()
        XCTAssertFalse(makeStore(runner: runner, colimaPath: nil).colimaAvailable)
        XCTAssertTrue(makeStore(runner: runner, colimaPath: "/opt/homebrew/bin/colima").colimaAvailable)
    }

    @MainActor
    func test_log_capsAt50Entries() async {
        let runner = MockCommandRunner()
        let store = makeStore(runner: runner)

        for _ in 0..<55 {
            await store.start("my-site")
        }

        XCTAssertEqual(store.log.count, 50)
    }

    @MainActor
    func test_log_persistsAcrossStoreInstances() async {
        let runner = MockCommandRunner()
        let defaults = UserDefaults(suiteName: "ProjectStoreTests.\(UUID().uuidString)")!
        let service = DDEVService(runner: runner, executablePath: "/opt/homebrew/bin/ddev")
        let first = ProjectStore(
            service: service, engineProbe: EngineProbe(runner: runner, dockerPath: nil),
            colima: ColimaController(runner: runner, path: nil), defaults: defaults
        )
        await first.start("my-site")
        XCTAssertFalse(first.log.isEmpty)

        let second = ProjectStore(
            service: service, engineProbe: EngineProbe(runner: runner, dockerPath: nil),
            colima: ColimaController(runner: runner, path: nil), defaults: defaults
        )
        XCTAssertEqual(second.log, first.log)
    }
}
