import XCTest
@testable import DDEVKit

final class ProjectDetailsTests: XCTestCase {
    private func fixture(_ name: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: nil))
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func ok(_ stdout: String) -> CommandResult {
        CommandResult(stdout: stdout, stderr: "", exitCode: 0)
    }

    /// Wires every ddev + docker read the detail popovers need to real recorded output.
    @MainActor
    private func makeStore(_ runner: MockCommandRunner) throws -> ProjectStore {
        runner.results["describe t3test -j"] = ok(try fixture("ddev-describe.jsonl"))
        runner.results["version -j"] = ok(try fixture("ddev-version.jsonl"))
        runner.firstArgResults["stats"] = ok(try fixture("docker-stats.jsonl"))
        runner.firstArgResults["ps"] = ok("ddev-router\nddev-ssh-agent\n")
        runner.firstArgResults["inspect"] = ok(try fixture("docker-inspect.txt"))
        runner.firstArgResults["system"] = ok(try fixture("docker-df-volumes.json"))
        runner.firstArgResults["context"] = ok("colima|unix:///Users/x/.colima/default/docker.sock\n")
        return ProjectStore(
            service: DDEVService(runner: runner, executablePath: "/opt/homebrew/bin/ddev"),
            engineProbe: EngineProbe(runner: runner, dockerPath: nil),
            containerEngine: ContainerEngineController(runner: runner, dockerPath: nil, colimaPath: nil),
            inspector: DockerInspector(runner: runner, dockerPath: "/opt/homebrew/bin/docker"),
            defaults: UserDefaults(suiteName: "ProjectDetailsTests.\(UUID().uuidString)")!
        )
    }

    // MARK: - Store: project details

    @MainActor
    func test_loadDetails_assemblesDescribeContainersStatsAndVolumes() async throws {
        let runner = MockCommandRunner()
        let store = try makeStore(runner)

        await store.loadDetails(for: "t3test")

        let details = try XCTUnwrap(store.projectDetails["t3test"])
        XCTAssertEqual(details.description.phpVersion, "8.3")
        XCTAssertEqual(details.containers.count, 2)
        XCTAssertNotNil(details.containers.first?.stat, "running containers must get their live stats row")
        XCTAssertFalse(details.volumes.isEmpty)
        XCTAssertGreaterThan(details.dataBytes, 0)
        XCTAssertGreaterThan(details.cacheBytes, 0)
        XCTAssertEqual(details.totalBytes, details.dataBytes + details.cacheBytes)
        XCTAssertEqual(details.drift?.isDrifting, false, "fixture project matches the installed ddev tag")
        XCTAssertNil(store.detailErrors["t3test"])
        XCTAssertFalse(store.isLoadingDetails("t3test"))
    }

    @MainActor
    func test_loadDetails_describeFails_setsDetailErrorAndNoDetails() async throws {
        let runner = MockCommandRunner()
        let store = try makeStore(runner)
        runner.results["describe t3test -j"] = CommandResult(stdout: "", stderr: "no such project", exitCode: 1)

        await store.loadDetails(for: "t3test")

        XCTAssertNil(store.projectDetails["t3test"])
        XCTAssertNotNil(store.detailErrors["t3test"])
    }

    @MainActor
    func test_loadDetails_noInspector_stillShowsDescribeFields() async throws {
        let runner = MockCommandRunner()
        runner.results["describe t3test -j"] = ok(try fixture("ddev-describe.jsonl"))
        let store = ProjectStore(
            service: DDEVService(runner: runner, executablePath: "/opt/homebrew/bin/ddev"),
            engineProbe: EngineProbe(runner: runner, dockerPath: nil),
            containerEngine: ContainerEngineController(runner: runner, dockerPath: nil, colimaPath: nil),
            inspector: nil,
            defaults: UserDefaults(suiteName: "ProjectDetailsTests.\(UUID().uuidString)")!
        )

        await store.loadDetails(for: "t3test")

        let details = try XCTUnwrap(store.projectDetails["t3test"])
        XCTAssertEqual(details.description.webserverType, "apache-fpm")
        XCTAssertTrue(details.containers.isEmpty)
        XCTAssertTrue(details.volumes.isEmpty)
    }

    @MainActor
    func test_action_invalidatesCachedDetails() async throws {
        let runner = MockCommandRunner()
        let store = try makeStore(runner)
        await store.loadDetails(for: "t3test")
        XCTAssertNotNil(store.projectDetails["t3test"])

        await store.stop("t3test")

        XCTAssertNil(store.projectDetails["t3test"], "stale container state must not survive an action")
    }

    @MainActor
    func test_loadDetails_runsDescribeOnlyForRequestedProject() async throws {
        let runner = MockCommandRunner()
        let store = try makeStore(runner)

        await store.loadDetails(for: "t3test")

        let describeCalls = runner.invocations.filter { $0.first == "describe" }
        XCTAssertEqual(describeCalls, [["describe", "t3test", "-j"]])
    }

    // MARK: - Store: engine details

    @MainActor
    func test_loadEngineDetails_readsContextToolchainAndLiveTotals() async throws {
        let runner = MockCommandRunner()
        let store = try makeStore(runner)

        await store.loadEngineDetails()

        let details = try XCTUnwrap(store.engineDetails)
        XCTAssertEqual(details.contextName, "colima")
        XCTAssertEqual(details.socketPath, "unix:///Users/x/.colima/default/docker.sock")
        XCTAssertEqual(details.version?.ddevVersion, "v1.25.4")
        XCTAssertEqual(details.runningContainerCount, 2)
        XCTAssertGreaterThan(details.totalMemoryBytes, 0)
        XCTAssertGreaterThanOrEqual(details.totalCPUPercent, 0)
        XCTAssertFalse(store.isLoadingEngineDetails)
    }

    @MainActor
    func test_versionInfo_isFetchedOnlyOnce() async throws {
        let runner = MockCommandRunner()
        let store = try makeStore(runner)

        await store.loadEngineDetails()
        await store.loadDetails(for: "t3test")
        await store.loadEngineDetails()

        XCTAssertEqual(runner.invocations.filter { $0 == ["version", "-j"] }.count, 1)
    }

    // MARK: - Volume attribution

    func test_volumesForProject_matchesComposeLabelCaseInsensitively() {
        let volumes = [
            VolumeUsage(name: "ES-Consulting-mariadb", sizeText: "115.3MB", bytes: 115_300_000,
                        composeProject: "ddev-es-consulting", links: 0),
            VolumeUsage(name: "other-mariadb", sizeText: "1MB", bytes: 1_000_000,
                        composeProject: "ddev-other", links: 0),
        ]

        let matched = ProjectDetails.volumes(volumes, forProject: "ES-Consulting")

        XCTAssertEqual(matched.map(\.name), ["ES-Consulting-mariadb"])
    }

    func test_volumesForProject_fallsBackToNamePrefixWhenUnlabelled() {
        let volumes = [
            VolumeUsage(name: "legacy_project_mutagen", sizeText: "1MB", bytes: 1_000_000,
                        composeProject: nil, links: 0),
            VolumeUsage(name: "legacy-mariadb", sizeText: "2MB", bytes: 2_000_000,
                        composeProject: nil, links: 0),
            VolumeUsage(name: "unrelated", sizeText: "3MB", bytes: 3_000_000,
                        composeProject: nil, links: 0),
        ]

        let matched = ProjectDetails.volumes(volumes, forProject: "legacy")

        XCTAssertEqual(matched.map(\.name), ["legacy-mariadb", "legacy_project_mutagen"])
    }

    // MARK: - Image drift

    func test_imageDrift_flagsOnlyOutdatedServices() {
        let drift = ImageDrift(expectedTag: "v1.25.4", tagsByService: ["web": "v1.24.0", "db": "v1.25.4"])

        XCTAssertTrue(drift.isDrifting)
        XCTAssertEqual(drift.outdatedServices, ["web"])
    }

    func test_imageDrift_matchingTags_isNotDrifting() {
        let drift = ImageDrift(expectedTag: "v1.25.4", tagsByService: ["web": "v1.25.4"])

        XCTAssertFalse(drift.isDrifting)
        XCTAssertTrue(drift.outdatedServices.isEmpty)
    }
}
