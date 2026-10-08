import Foundation
@testable import DDEVKit

final class MockCommandRunner: CommandRunner, @unchecked Sendable {
    var results: [String: CommandResult] = [:]          // keyed by joined arguments
    /// Fallback keyed by the FIRST argument (`inspect`, `stats`, …), for commands whose full
    /// argument list contains long Go templates that would be brittle to spell out in a test.
    var firstArgResults: [String: CommandResult] = [:]
    var defaultResult = CommandResult(stdout: "", stderr: "", exitCode: 0)
    private(set) var invocations: [[String]] = []

    func run(executable: String, arguments: [String], timeout: TimeInterval) async throws -> CommandResult {
        invocations.append(arguments)
        if let exact = results[arguments.joined(separator: " ")] { return exact }
        if let first = arguments.first, let match = firstArgResults[first] { return match }
        return defaultResult
    }
}
