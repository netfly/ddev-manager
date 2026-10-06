import Foundation
@testable import DDEVKit

final class MockCommandRunner: CommandRunner, @unchecked Sendable {
    var results: [String: CommandResult] = [:]          // keyed by joined arguments
    var defaultResult = CommandResult(stdout: "", stderr: "", exitCode: 0)
    private(set) var invocations: [[String]] = []

    func run(executable: String, arguments: [String], timeout: TimeInterval) async throws -> CommandResult {
        invocations.append(arguments)
        return results[arguments.joined(separator: " ")] ?? defaultResult
    }
}
