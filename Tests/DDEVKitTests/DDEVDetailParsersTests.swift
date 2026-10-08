import XCTest
@testable import DDEVKit

final class DDEVDetailParsersTests: XCTestCase {
    private func fixture(_ name: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: nil))
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - ddev describe

    func test_describeParser_realFixture_readsStackFields() throws {
        let description = try DDEVDescribeParser.parse(fixture("ddev-describe.jsonl"))

        XCTAssertEqual(description.name, "t3test")
        XCTAssertEqual(description.type, "typo3")
        XCTAssertEqual(description.docroot, "public")
        XCTAssertEqual(description.phpVersion, "8.3")
        XCTAssertEqual(description.webserverType, "apache-fpm")
        XCTAssertEqual(description.databaseSummary, "mariadb 10.11")
        XCTAssertEqual(description.nodejsVersion, "24")
        XCTAssertEqual(description.performanceMode, "mutagen")
        XCTAssertEqual(description.mutagenEnabled, true)
        XCTAssertNotNil(description.mutagenStatus)
        XCTAssertEqual(description.imageTagsByService["web"], "v1.25.4")
        XCTAssertEqual(description.imageTagsByService["db"], "v1.25.4")
    }

    func test_describeParser_garbage_throws() {
        XCTAssertThrowsError(try DDEVDescribeParser.parse("not json\n{\"level\":\"info\"}"))
    }

    func test_databaseSummary_handlesMissingParts() {
        XCTAssertNil(DDEVProjectDescription(name: "x").databaseSummary)
        XCTAssertEqual(
            DDEVProjectDescription(name: "x", databaseType: "postgres").databaseSummary,
            "postgres"
        )
    }

    // MARK: - ddev version

    func test_versionParser_realFixture_readsToolchain() throws {
        let info = try DDEVVersionParser.parse(fixture("ddev-version.jsonl"))

        XCTAssertEqual(info.ddevVersion, "v1.25.4")
        XCTAssertEqual(info.dockerPlatform, "colima")
        XCTAssertNotNil(info.mutagenVersion)
        XCTAssertNotNil(info.dockerAPIVersion)
        XCTAssertEqual(info.globalDDEVDir, "/Users/markus/.ddev")
        XCTAssertEqual(info.expectedImageTag, "v1.25.4")
    }

    func test_versionParser_garbage_throws() {
        XCTAssertThrowsError(try DDEVVersionParser.parse(""))
    }

    func test_imageTag_handlesMissingTag() {
        XCTAssertNil(DDEVVersionInfo.tag(of: "ddev/ddev-webserver"))
        XCTAssertNil(DDEVVersionInfo.tag(of: nil))
        XCTAssertEqual(DDEVVersionInfo.tag(of: "a/b:v1.2.3"), "v1.2.3")
    }

    // MARK: - docker stats

    func test_statsParser_realFixture_parsesCPUAndMemory() throws {
        let stats = DockerStatsParser.parse(try fixture("docker-stats.jsonl"))

        XCTAssertFalse(stats.isEmpty)
        let router = try XCTUnwrap(stats.first { $0.name == "ddev-router" })
        XCTAssertNotNil(router.cpuPercent)
        XCTAssertNotNil(router.memoryBytes)
        XCTAssertGreaterThan(try XCTUnwrap(router.memoryBytes), 0)
        XCTAssertTrue(router.memoryUsageText.contains("/"))
    }

    func test_statsParser_skipsNonJSONLines() {
        XCTAssertTrue(DockerStatsParser.parse("boom\n").isEmpty)
    }

    // MARK: - docker inspect

    func test_inspectParser_realFixture_stripsSlashAndReadsState() throws {
        let containers = DockerInspectParser.parse(try fixture("docker-inspect.txt"))

        XCTAssertEqual(containers.count, 2)
        let router = try XCTUnwrap(containers.first { $0.name == "ddev-router" })
        XCTAssertFalse(router.name.hasPrefix("/"))
        XCTAssertEqual(router.status, "running")
        XCTAssertEqual(router.health, "healthy")
        XCTAssertEqual(router.restartCount, 0)
        XCTAssertNotNil(router.startedAt)
        XCTAssertNotNil(router.uptime)
    }

    func test_inspectParser_noHealthcheck_yieldsNilHealth() {
        let line = "/c|running|none|2026-10-06T15:20:32.061062399Z|2|img:tag"
        let container = DockerInspectParser.parse(line).first
        XCTAssertNil(container?.health)
        XCTAssertEqual(container?.restartCount, 2)
    }

    func test_containerInfo_uptimeIsNilWhenNotRunning() {
        let info = ContainerInfo(
            name: "ddev-x-web", status: "exited", health: nil,
            startedAt: Date(timeIntervalSinceNow: -60), restartCount: 0, image: "i"
        )
        XCTAssertNil(info.uptime)
        XCTAssertEqual(info.shortName(project: "x"), "web")
    }

    // MARK: - docker system df -v

    func test_volumeParser_realFixture_readsSizesAndComposeLabel() throws {
        let volumes = DockerVolumeParser.parse(try fixture("docker-df-volumes.json"))

        XCTAssertFalse(volumes.isEmpty)
        let db = try XCTUnwrap(volumes.first { $0.name == "t3test-mariadb" })
        XCTAssertEqual(db.composeProject, "ddev-t3test")
        XCTAssertGreaterThan(try XCTUnwrap(db.bytes), 0)
        XCTAssertFalse(db.isMutagenCache)
        XCTAssertTrue(try XCTUnwrap(volumes.first { $0.name == "t3test_project_mutagen" }).isMutagenCache)
    }

    func test_volumeParser_garbage_returnsEmpty() {
        XCTAssertTrue(DockerVolumeParser.parse("nope").isEmpty)
    }

    // MARK: - size parsing

    func test_dockerSize_parsesDecimalAndBinaryUnits() {
        XCTAssertEqual(DockerSize.bytes(from: "164.7MB"), 164_700_000)
        XCTAssertEqual(DockerSize.bytes(from: "28.67kB"), 28_670)
        XCTAssertEqual(DockerSize.bytes(from: "0B"), 0)
        XCTAssertEqual(DockerSize.bytes(from: "96.1MiB "), Int64(96.1 * 1_048_576))
        XCTAssertNil(DockerSize.bytes(from: "N/A"))
        XCTAssertNil(DockerSize.bytes(from: ""))
        XCTAssertNil(DockerSize.bytes(from: "12parsecs"))
    }
}
