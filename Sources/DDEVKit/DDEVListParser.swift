import Foundation

public enum DDEVError: LocalizedError, Equatable {
    case cliNotFound
    case unparsableOutput(String)
    case commandFailed(command: String, exitCode: Int32, message: String)
    case timedOut(command: String)

    public var errorDescription: String? {
        switch self {
        case .cliNotFound:
            "ddev executable not found. Set its path in Settings."
        case .unparsableOutput(let detail):
            "Could not understand ddev output: \(detail)"
        case .commandFailed(let command, let code, let message):
            "`\(command)` failed (exit \(code)): \(message)"
        case .timedOut(let command):
            "`\(command)` timed out."
        }
    }
}

public enum DDEVListParser {
    private struct Envelope: Decodable {
        let raw: [DDEVProject]?
    }

    /// `ddev list -j` emits JSON-lines log records; exactly one carries `raw`.
    public static func parse(_ output: String) throws -> [DDEVProject] {
        let decoder = JSONDecoder()
        for line in output.split(whereSeparator: \.isNewline) {
            guard let data = line.data(using: .utf8),
                  let envelope = try? decoder.decode(Envelope.self, from: data),
                  let raw = envelope.raw else { continue }
            return raw.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        throw DDEVError.unparsableOutput(String(output.prefix(200)))
    }
}
