import XCTest
@testable import DDEVKit

final class EngineProbeTests: XCTestCase {
    func test_probe_runningVersion_returnsRunning() async {
        let runner = MockCommandRunner()
        runner.defaultResult = CommandResult(stdout: "29.5.2\n", stderr: "", exitCode: 0)
        let probe = EngineProbe(runner: runner, dockerPath: "/opt/homebrew/bin/docker")

        let state = await probe.probe()

        XCTAssertEqual(state, .running(version: "29.5.2"))
    }

    func test_probe_daemonDown_returnsDown() async {
        let runner = MockCommandRunner()
        runner.defaultResult = CommandResult(stdout: "", stderr: "Cannot connect to the Docker daemon", exitCode: 1)
        let probe = EngineProbe(runner: runner, dockerPath: "/opt/homebrew/bin/docker")

        let state = await probe.probe()

        guard case .down(let reason) = state else { return XCTFail("expected .down, got \(state)") }
        XCTAssertTrue(reason.contains("Docker daemon"))
    }

    func test_probe_noDockerPath_returnsDockerMissing() async {
        let runner = MockCommandRunner()
        let probe = EngineProbe(runner: runner, dockerPath: nil)

        let state = await probe.probe()

        XCTAssertEqual(state, .dockerMissing)
    }
}
