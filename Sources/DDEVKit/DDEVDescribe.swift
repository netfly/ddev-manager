import Foundation

/// The subset of `ddev describe <name> -j` the detail popover shows. `describe` costs one
/// process per project, so it is only ever run on demand (when a detail popover opens),
/// never during the panel's list refresh.
public struct DDEVProjectDescription: Equatable, Sendable {
    public let name: String
    public let type: String?
    public let docroot: String?
    public let phpVersion: String?
    public let webserverType: String?
    public let databaseType: String?
    public let databaseVersion: String?
    public let nodejsVersion: String?
    public let performanceMode: String?
    public let mutagenEnabled: Bool?
    public let mutagenStatus: String?
    public let webImage: String?
    public let dbImage: String?

    public init(
        name: String,
        type: String? = nil,
        docroot: String? = nil,
        phpVersion: String? = nil,
        webserverType: String? = nil,
        databaseType: String? = nil,
        databaseVersion: String? = nil,
        nodejsVersion: String? = nil,
        performanceMode: String? = nil,
        mutagenEnabled: Bool? = nil,
        mutagenStatus: String? = nil,
        webImage: String? = nil,
        dbImage: String? = nil
    ) {
        self.name = name
        self.type = type
        self.docroot = docroot
        self.phpVersion = phpVersion
        self.webserverType = webserverType
        self.databaseType = databaseType
        self.databaseVersion = databaseVersion
        self.nodejsVersion = nodejsVersion
        self.performanceMode = performanceMode
        self.mutagenEnabled = mutagenEnabled
        self.mutagenStatus = mutagenStatus
        self.webImage = webImage
        self.dbImage = dbImage
    }

    /// `mariadb 10.11` — nil when ddev reports no database (e.g. `omit_containers: [db]`).
    public var databaseSummary: String? {
        switch (databaseType, databaseVersion) {
        case let (type?, version?): "\(type) \(version)"
        case let (type?, nil): type
        case let (nil, version?): version
        default: nil
        }
    }

    /// Image tags this project is configured to use, keyed by service, for drift detection.
    public var imageTagsByService: [String: String] {
        var tags: [String: String] = [:]
        if let tag = DDEVVersionInfo.tag(of: webImage) { tags["web"] = tag }
        if let tag = DDEVVersionInfo.tag(of: dbImage) { tags["db"] = tag }
        return tags
    }
}

public enum DDEVDescribeParser {
    private struct Envelope: Decodable {
        let raw: Raw?

        struct Raw: Decodable {
            let name: String
            let type: String?
            let docroot: String?
            let phpVersion: String?
            let webserverType: String?
            let databaseType: String?
            let databaseVersion: String?
            let nodejsVersion: String?
            let performanceMode: String?
            let mutagenEnabled: Bool?
            let mutagenStatus: String?
            let webImage: String?
            let dbImage: String?

            enum CodingKeys: String, CodingKey {
                case name, type, docroot
                case phpVersion = "php_version"
                case webserverType = "webserver_type"
                case databaseType = "database_type"
                case databaseVersion = "database_version"
                case nodejsVersion = "nodejs_version"
                case performanceMode = "performance_mode"
                case mutagenEnabled = "mutagen_enabled"
                case mutagenStatus = "mutagen_status"
                case webImage = "webimg"
                case dbImage = "dbimg"
            }
        }
    }

    /// Like `ddev list -j`, `describe` wraps its payload in JSON-lines log records; exactly
    /// one line carries `raw` — here an object, not an array.
    public static func parse(_ output: String) throws -> DDEVProjectDescription {
        let decoder = JSONDecoder()
        for line in output.split(whereSeparator: \.isNewline) {
            guard let data = line.data(using: .utf8),
                  let envelope = try? decoder.decode(Envelope.self, from: data),
                  let raw = envelope.raw else { continue }
            return DDEVProjectDescription(
                name: raw.name,
                type: raw.type,
                docroot: raw.docroot,
                phpVersion: raw.phpVersion,
                webserverType: raw.webserverType,
                databaseType: raw.databaseType,
                databaseVersion: raw.databaseVersion,
                nodejsVersion: raw.nodejsVersion,
                performanceMode: raw.performanceMode,
                mutagenEnabled: raw.mutagenEnabled,
                mutagenStatus: raw.mutagenStatus,
                webImage: raw.webImage,
                dbImage: raw.dbImage
            )
        }
        throw DDEVError.unparsableOutput(String(output.prefix(200)))
    }
}
