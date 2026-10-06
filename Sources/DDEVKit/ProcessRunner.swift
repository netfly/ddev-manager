import Foundation

/// Runs a real subprocess with an explicit PATH, because a GUI app inherits
/// only /usr/bin:/bin:/usr/sbin:/sbin and would never find Homebrew's ddev/docker.
public struct ProcessRunner: CommandRunner {
    public static let searchPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    public init() {}

    public func run(executable: String, arguments: [String], timeout: TimeInterval) async throws -> CommandResult {
        guard FileManager.default.isExecutableFile(atPath: executable) else { throw DDEVError.cliNotFound }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = Self.searchPath
        env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        env["DDEV_NONINTERACTIVE"] = "true"
        env["TERM"] = "dumb"
        process.environment = env

        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        process.standardInput = FileHandle.nullDevice

        try process.run()

        // Read pipes on background queues to avoid deadlocking on >64KB output.
        let outData = Task.detached { out.fileHandleForReading.readDataToEndOfFile() }
        let errData = Task.detached { err.fileHandleForReading.readDataToEndOfFile() }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if Date() > deadline {
                process.terminate()
                throw DDEVError.timedOut(command: ([executable] + arguments).joined(separator: " "))
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        process.waitUntilExit()

        return CommandResult(
            stdout: String(decoding: await outData.value, as: UTF8.self),
            stderr: String(decoding: await errData.value, as: UTF8.self),
            exitCode: process.terminationStatus
        )
    }
}
