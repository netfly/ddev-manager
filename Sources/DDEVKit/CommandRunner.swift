import Foundation

public struct CommandResult: Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public init(stdout: String, stderr: String, exitCode: Int32) {
        self.stdout = stdout; self.stderr = stderr; self.exitCode = exitCode
    }
    public var succeeded: Bool { exitCode == 0 }
}

public protocol CommandRunner: Sendable {
    func run(executable: String, arguments: [String], timeout: TimeInterval) async throws -> CommandResult
}
