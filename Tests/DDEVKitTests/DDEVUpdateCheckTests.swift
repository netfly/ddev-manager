import XCTest
@testable import DDEVKit

final class DDEVReleaseVersionTests: XCTestCase {
    func test_isNewer_comparesNumerically() {
        XCTAssertTrue(DDEVRelease.isNewer("v1.25.5", than: "v1.25.4"))
        XCTAssertTrue(DDEVRelease.isNewer("v1.26.0", than: "v1.25.10"))
        XCTAssertTrue(DDEVRelease.isNewer("v2.0.0", than: "v1.99.99"))
        XCTAssertTrue(DDEVRelease.isNewer("1.25.10", than: "v1.25.9"))   // missing `v` tolerated
        XCTAssertFalse(DDEVRelease.isNewer("v1.25.4", than: "v1.25.4"))
        XCTAssertFalse(DDEVRelease.isNewer("v1.25.3", than: "v1.25.4"))
    }

    func test_isNewer_prereleaseOrGarbage_neverReportsUpdate() {
        XCTAssertFalse(DDEVRelease.isNewer("v1.26.0-rc1", than: "v1.25.4"))
        XCTAssertFalse(DDEVRelease.isNewer("v1.26.0-alpha", than: "v1.25.4"))
        XCTAssertFalse(DDEVRelease.isNewer("latest", than: "v1.25.4"))
        XCTAssertFalse(DDEVRelease.isNewer("v1.26", than: "v1.25.4"))
        XCTAssertFalse(DDEVRelease.isNewer("", than: "v1.25.4"))
        XCTAssertFalse(DDEVRelease.isNewer("v1.26.0", than: "v1.25.4-dirty"))
    }

    func test_decodesGitHubPayload() throws {
        let json = #"{"tag_name":"v1.25.5","html_url":"https://github.com/ddev/ddev/releases/tag/v1.25.5","name":"x"}"#
        let release = try JSONDecoder().decode(DDEVRelease.self, from: Data(json.utf8))
        XCTAssertEqual(release, DDEVRelease(tagName: "v1.25.5", htmlURL: "https://github.com/ddev/ddev/releases/tag/v1.25.5"))
    }
}

/// Fake fetcher + clock shared with the store's @Sendable closures.
private final class FakeReleaseSource: @unchecked Sendable {
    var calls = 0
    var result: Result<DDEVRelease, Error> = .success(DDEVRelease(tagName: "v1.25.5", htmlURL: "https://example.test/v1.25.5"))
    var now = Date(timeIntervalSince1970: 1_800_000_000)
}

final class ProjectStoreUpdateCheckTests: XCTestCase {
    private var suiteName = ""

    override func setUp() { suiteName = "UpdateCheckTests.\(UUID().uuidString)" }
    override func tearDown() { UserDefaults().removePersistentDomain(forName: suiteName) }

    @MainActor
    private func makeStore(_ source: FakeReleaseSource) throws -> ProjectStore {
        let runner = MockCommandRunner()
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/ddev-version.jsonl", withExtension: nil))
        runner.results["version -j"] = CommandResult(stdout: try String(contentsOf: url, encoding: .utf8), stderr: "", exitCode: 0)
        let list = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/ddev-list-empty.jsonl", withExtension: nil))
        runner.results["list -j"] = CommandResult(stdout: try String(contentsOf: list, encoding: .utf8), stderr: "", exitCode: 0)
        return ProjectStore(
            service: DDEVService(runner: runner, executablePath: "/opt/homebrew/bin/ddev"),
            engineProbe: EngineProbe(runner: runner, dockerPath: nil),
            containerEngine: ContainerEngineController(runner: runner, dockerPath: nil, colimaPath: nil),
            defaults: UserDefaults(suiteName: suiteName)!,
            fetchLatestRelease: { source.calls += 1; return try source.result.get() },
            now: { source.now }
        )
    }

    @MainActor
    private func refreshAndWait(_ store: ProjectStore) async {
        await store.refresh()
        await store.updateCheckTask?.value
    }

    @MainActor
    func test_firstRefresh_fetchesAndReportsUpdate() async throws {
        let source = FakeReleaseSource()
        let store = try makeStore(source)

        await refreshAndWait(store)

        XCTAssertEqual(source.calls, 1)
        XCTAssertEqual(store.installedDDEVVersion, "v1.25.4")
        XCTAssertEqual(store.availableUpdate?.tagName, "v1.25.5")
    }

    @MainActor
    func test_within24h_reusesPersistedResult_after24h_checksAgain() async throws {
        let source = FakeReleaseSource()
        await refreshAndWait(try makeStore(source))
        XCTAssertEqual(source.calls, 1)

        // New app run 23 h later: no fetch, banner from the persisted result.
        source.now += 23 * 3600
        let restarted = try makeStore(source)
        await refreshAndWait(restarted)
        await refreshAndWait(restarted)
        XCTAssertEqual(source.calls, 1)
        XCTAssertEqual(restarted.availableUpdate?.tagName, "v1.25.5")

        source.now += 3600
        source.result = .success(DDEVRelease(tagName: "v1.25.4", htmlURL: "https://example.test/v1.25.4"))
        await refreshAndWait(restarted)
        XCTAssertEqual(source.calls, 2)
        XCTAssertNil(restarted.availableUpdate, "up to date → no banner")
    }

    @MainActor
    func test_failure_isSilentAndRetriesOnNextRefresh() async throws {
        let source = FakeReleaseSource()
        source.result = .failure(URLError(.notConnectedToInternet))
        let store = try makeStore(source)

        await refreshAndWait(store)
        XCTAssertEqual(source.calls, 1)
        XCTAssertNil(store.availableUpdate)
        XCTAssertNil(store.lastError)

        source.result = .success(DDEVRelease(tagName: "v1.25.5", htmlURL: "https://example.test/v1.25.5"))
        await refreshAndWait(store)
        XCTAssertEqual(source.calls, 2, "timestamp not stored on failure, so the next refresh retries")
        XCTAssertEqual(store.availableUpdate?.tagName, "v1.25.5")
    }

    @MainActor
    func test_prereleaseLatest_showsNoBanner() async throws {
        let source = FakeReleaseSource()
        source.result = .success(DDEVRelease(tagName: "v1.26.0-rc1", htmlURL: "https://example.test/rc"))
        let store = try makeStore(source)

        await refreshAndWait(store)

        XCTAssertNil(store.availableUpdate)
    }
}
