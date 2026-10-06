import XCTest
@testable import DDEVKit

final class ContainerEngineControllerTests: XCTestCase {
    func test_detectKind_colimaContext_returnsColima() async {
        let runner = MockCommandRunner()
        runner.results["context show"] = CommandResult(stdout: "colima\n", stderr: "", exitCode: 0)
        let controller = ContainerEngineController(runner: runner, dockerPath: "/opt/homebrew/bin/docker", colimaPath: nil)

        let kind = await controller.detectKind()

        XCTAssertEqual(kind, .colima)
    }

    func test_detectKind_desktopLinuxContext_returnsDockerDesktop() async {
        let runner = MockCommandRunner()
        runner.results["context show"] = CommandResult(stdout: "desktop-linux\n", stderr: "", exitCode: 0)
        let controller = ContainerEngineController(runner: runner, dockerPath: "/opt/homebrew/bin/docker", colimaPath: nil)

        let kind = await controller.detectKind()

        XCTAssertEqual(kind, .dockerDesktop)
    }

    func test_detectKind_orbstackContext_returnsOrbStack() async {
        let runner = MockCommandRunner()
        runner.results["context show"] = CommandResult(stdout: "orbstack\n", stderr: "", exitCode: 0)
        let controller = ContainerEngineController(runner: runner, dockerPath: "/opt/homebrew/bin/docker", colimaPath: nil)

        let kind = await controller.detectKind()

        XCTAssertEqual(kind, .orbStack)
    }

    func test_detectKind_rancherDesktopContext_returnsRancherDesktop() async {
        let runner = MockCommandRunner()
        runner.results["context show"] = CommandResult(stdout: "rancher-desktop\n", stderr: "", exitCode: 0)
        let controller = ContainerEngineController(runner: runner, dockerPath: "/opt/homebrew/bin/docker", colimaPath: nil)

        let kind = await controller.detectKind()

        XCTAssertEqual(kind, .rancherDesktop)
    }

    func test_detectKind_noDockerPath_fallsBackToColimaGuess() async {
        let runner = MockCommandRunner()
        let controller = ContainerEngineController(runner: runner, dockerPath: nil, colimaPath: "/opt/homebrew/bin/colima")

        let kind = await controller.detectKind()

        XCTAssertEqual(kind, .colima)
    }

    func test_detectKind_contextCommandFails_returnsUnknownGuess() async {
        let runner = MockCommandRunner()
        runner.defaultResult = CommandResult(stdout: "", stderr: "not a docker command", exitCode: 1)
        let controller = ContainerEngineController(runner: runner, dockerPath: "/opt/homebrew/bin/docker", colimaPath: nil)

        let kind = await controller.detectKind()

        XCTAssertEqual(kind, .unknown(""))
    }

    func test_canStart_colimaWithPath_true() {
        let controller = ContainerEngineController(runner: MockCommandRunner(), dockerPath: nil, colimaPath: "/opt/homebrew/bin/colima")
        XCTAssertTrue(controller.canStart(kind: .colima))
    }

    func test_canStart_colimaWithoutPath_false() {
        let controller = ContainerEngineController(runner: MockCommandRunner(), dockerPath: nil, colimaPath: nil)
        XCTAssertFalse(controller.canStart(kind: .colima))
    }

    func test_start_colima_runsColimaStart() async throws {
        let runner = MockCommandRunner()
        let controller = ContainerEngineController(runner: runner, dockerPath: nil, colimaPath: "/opt/homebrew/bin/colima")

        try await controller.start(kind: .colima)

        XCTAssertEqual(runner.invocations.first, ["start"])
    }

    func test_start_colima_noPath_throws() async {
        let controller = ContainerEngineController(runner: MockCommandRunner(), dockerPath: nil, colimaPath: nil)
        do {
            try await controller.start(kind: .colima)
            XCTFail("expected throw")
        } catch is DDEVError {
            // expected
        } catch {
            XCTFail("wrong error \(error)")
        }
    }

    func test_start_colima_failure_throwsCommandFailed() async {
        let runner = MockCommandRunner()
        runner.defaultResult = CommandResult(stdout: "", stderr: "boom", exitCode: 1)
        let controller = ContainerEngineController(runner: runner, dockerPath: nil, colimaPath: "/opt/homebrew/bin/colima")

        do {
            try await controller.start(kind: .colima)
            XCTFail("expected throw")
        } catch let error as DDEVError {
            guard case .commandFailed = error else { return XCTFail("wrong case: \(error)") }
        } catch {
            XCTFail("wrong error \(error)")
        }
    }

    func test_displayNames() {
        XCTAssertEqual(ContainerEngineKind.colima.displayName, "Colima")
        XCTAssertEqual(ContainerEngineKind.dockerDesktop.displayName, "Docker Desktop")
        XCTAssertEqual(ContainerEngineKind.orbStack.displayName, "OrbStack")
        XCTAssertEqual(ContainerEngineKind.rancherDesktop.displayName, "Rancher Desktop")
        XCTAssertEqual(ContainerEngineKind.podman.displayName, "Podman")
        XCTAssertEqual(ContainerEngineKind.unknown("mystery").displayName, "mystery")
    }
}
