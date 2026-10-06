import Foundation

public enum DDEVStatus: Equatable, Sendable {
    case running, stopped, paused, starting, unknown(String)

    public init(raw: String) {
        switch raw.lowercased() {
        case "running": self = .running
        case "stopped": self = .stopped
        case "paused": self = .paused
        case "starting": self = .starting
        default: self = .unknown(raw)
        }
    }

    public var label: String {
        switch self {
        case .running: "running"
        case .stopped: "stopped"
        case .paused: "paused"
        case .starting: "starting"
        case .unknown(let raw): raw
        }
    }

    /// Projects that can be started (stopped or paused).
    public var isStartable: Bool { self != .running }
    public var isRunning: Bool { self == .running }

    /// Lower sorts first: running projects surface at the top of the list.
    public var sortRank: Int {
        switch self {
        case .running: 0
        case .starting: 1
        case .paused: 2
        case .stopped: 3
        case .unknown: 4
        }
    }
}

public struct DDEVProject: Decodable, Identifiable, Hashable, Sendable {
    public let name: String
    public let statusRaw: String
    public let statusDesc: String?
    public let approot: String
    public let shortroot: String?
    public let type: String
    public let primaryURL: String?
    public let mailpitURL: String?
    public let mutagenEnabled: Bool?
    public let mutagenStatus: String?

    public var id: String { name }
    public var status: DDEVStatus { DDEVStatus(raw: statusRaw) }
    public var displayPath: String { shortroot ?? approot }

    enum CodingKeys: String, CodingKey {
        case name, approot, shortroot, type
        case statusRaw = "status"
        case statusDesc = "status_desc"
        case primaryURL = "primary_url"
        case mailpitURL = "mailpit_https_url"
        case mutagenEnabled = "mutagen_enabled"
        case mutagenStatus = "mutagen_status"
    }
}
