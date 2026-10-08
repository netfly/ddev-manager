import XCTest
@testable import DDEVKit

final class ExternalAppsTests: XCTestCase {
    func test_shellQuote_escapesSingleQuotes() {
        XCTAssertEqual(ShellQuote.single("/tmp/plain"), "'/tmp/plain'")
        XCTAssertEqual(ShellQuote.single("/tmp/it's here"), "'/tmp/it'\\''s here'")
    }

    func test_databaseClient_ddevCommandsMatchDocumentedHostCommands() {
        // https://docs.ddev.com/en/stable/users/usage/database-management/#database-guis
        XCTAssertEqual(DatabaseClient.sequelAce.ddevCommand, "sequelace")
        XCTAssertEqual(DatabaseClient.tablePlus.ddevCommand, "tableplus")
        XCTAssertEqual(DatabaseClient.tablePro.ddevCommand, "tablepro")
        XCTAssertEqual(DatabaseClient.querious.ddevCommand, "querious")
        XCTAssertEqual(DatabaseClient.dbeaver.ddevCommand, "dbeaver")
        XCTAssertEqual(DatabaseClient.mysqlWorkbench.ddevCommand, "mysqlworkbench")
        XCTAssertEqual(DatabaseClient.phpMyAdmin.ddevCommand, "phpmyadmin")
        XCTAssertEqual(DatabaseClient.adminer.ddevCommand, "adminer")
    }

    func test_databaseClient_browserBasedOnesAreTheAddOns() {
        XCTAssertTrue(DatabaseClient.phpMyAdmin.isBrowserBased)
        XCTAssertTrue(DatabaseClient.adminer.isBrowserBased)
        XCTAssertNotNil(DatabaseClient.phpMyAdmin.setupNote)
        XCTAssertFalse(DatabaseClient.sequelAce.isBrowserBased)
        XCTAssertNil(DatabaseClient.sequelAce.setupNote)
        // Add-ons can't be detected from an app bundle, so they must stay out of auto-detection.
        XCTAssertFalse(DatabaseClient.autoDetectOrder.contains(.phpMyAdmin))
        XCTAssertFalse(DatabaseClient.autoDetectOrder.contains(.adminer))
    }

    func test_databaseClient_resolveHonoursExplicitPreference() {
        XCTAssertEqual(DatabaseClient.resolve(preference: "tablePlus"), .tablePlus)
        XCTAssertEqual(DatabaseClient.resolve(preference: "phpMyAdmin"), .phpMyAdmin)
    }

    func test_databaseClient_resolveFallsBackToAutoDetection() {
        let auto = DatabaseClient.resolve(preference: "auto")
        XCTAssertEqual(auto, DatabaseClient.autoDetectOrder.first(where: \.isInstalled))
        XCTAssertEqual(DatabaseClient.resolve(preference: nil), auto)
        XCTAssertEqual(DatabaseClient.resolve(preference: "notAClient"), auto)
    }

    func test_terminalApp_resolveFallsBackToAnInstalledTerminal() {
        let resolved = TerminalApp.resolve(preference: "NotInstalledTerminal")
        XCTAssertTrue(resolved.isInstalled || resolved.id == "Terminal")
    }

    func test_terminalApp_terminalDotAppIsAlwaysAvailableAsLastResort() {
        // Terminal.app ships with macOS; it is the final fallback for the ddev ssh action.
        XCTAssertEqual(TerminalApp.known.first?.id, "Terminal")
        XCTAssertTrue(TerminalApp.known[0].isInstalled)
    }

    func test_terminalApp_resolveHonoursInstalledExplicitChoice() throws {
        let installed = try XCTUnwrap(TerminalApp.installed.first)
        XCTAssertEqual(TerminalApp.resolve(preference: installed.id), installed)
    }
}

final class HostCommandTests: XCTestCase {
    @MainActor
    func test_runHostCommand_runsViaShellInProjectDirectory() async throws {
        let runner = MockCommandRunner()
        let service = DDEVService(runner: runner, executablePath: "/opt/homebrew/bin/ddev")

        try await service.runHostCommand("sequelace", approot: "/Users/x/my site")

        let invocation = try XCTUnwrap(runner.invocations.first)
        XCTAssertEqual(invocation.first, "-c")
        let script = try XCTUnwrap(invocation.last)
        XCTAssertTrue(script.contains("cd '/Users/x/my site'"), script)
        XCTAssertTrue(script.contains("'/opt/homebrew/bin/ddev' 'sequelace'"), script)
    }

    @MainActor
    func test_runHostCommand_failure_throwsWithDdevMessage() async {
        let runner = MockCommandRunner()
        runner.defaultResult = CommandResult(
            stdout: "", stderr: #"{"level":"fatal","msg":"unknown command \"sequelace\""}"#, exitCode: 1
        )
        let service = DDEVService(runner: runner, executablePath: "/opt/homebrew/bin/ddev")

        do {
            try await service.runHostCommand("sequelace", approot: "/tmp/p")
            XCTFail("expected a failure")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("unknown command"), error.localizedDescription)
        }
    }

    @MainActor
    func test_openDatabaseClient_logsSuccessAndRefreshes() async throws {
        let runner = MockCommandRunner()
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/ddev-list.jsonl", withExtension: nil))
        runner.results["list -j"] = CommandResult(
            stdout: try String(contentsOf: url, encoding: .utf8), stderr: "", exitCode: 0
        )
        let store = ProjectStore(
            service: DDEVService(runner: runner, executablePath: "/opt/homebrew/bin/ddev"),
            engineProbe: EngineProbe(runner: runner, dockerPath: nil),
            containerEngine: ContainerEngineController(runner: runner, dockerPath: nil, colimaPath: nil),
            defaults: UserDefaults(suiteName: "ExternalAppsTests.\(UUID().uuidString)")!
        )
        let project = DDEVProject(
            name: "t3test", statusRaw: "running", statusDesc: nil,
            approot: "/tmp/t3test", shortroot: nil, type: "typo3",
            primaryURL: nil, mailpitURL: nil, mutagenEnabled: nil, mutagenStatus: nil
        )

        await store.openDatabaseClient(.sequelAce, project: project)

        XCTAssertNil(store.lastError)
        XCTAssertTrue(store.log.last?.contains("Sequel Ace for t3test") ?? false, store.log.last ?? "")
        XCTAssertFalse(store.isBusy("t3test"))
    }

    @MainActor
    func test_recordExternalAction_logsFailureAndSetsLastError() {
        let runner = MockCommandRunner()
        let store = ProjectStore(
            service: DDEVService(runner: runner, executablePath: "/opt/homebrew/bin/ddev"),
            engineProbe: EngineProbe(runner: runner, dockerPath: nil),
            containerEngine: ContainerEngineController(runner: runner, dockerPath: nil, colimaPath: nil),
            defaults: UserDefaults(suiteName: "ExternalAppsTests.\(UUID().uuidString)")!
        )

        store.recordExternalAction(label: "ddev ssh for x", failure: "no terminal")
        XCTAssertEqual(store.lastError, "no terminal")
        XCTAssertTrue(store.log.last?.hasPrefix("❌") ?? false)

        store.recordExternalAction(label: "ddev ssh for x")
        XCTAssertTrue(store.log.last?.hasPrefix("✅") ?? false)
    }
}
