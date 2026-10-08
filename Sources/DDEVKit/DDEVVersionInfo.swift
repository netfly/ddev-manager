import Foundation

/// The toolchain versions `ddev version -j` reports. Cached once per app run — these only
/// change when the user upgrades ddev itself, so there is no point re-running it on every
/// panel refresh.
public struct DDEVVersionInfo: Equatable, Sendable {
    public let ddevVersion: String?
    public let mutagenVersion: String?
    public let dockerVersion: String?
    public let dockerAPIVersion: String?
    public let buildxVersion: String?
    public let dockerPlatform: String?
    public let globalDDEVDir: String?
    public let webImage: String?
    public let dbImage: String?
    public let routerImage: String?

    public init(
        ddevVersion: String? = nil,
        mutagenVersion: String? = nil,
        dockerVersion: String? = nil,
        dockerAPIVersion: String? = nil,
        buildxVersion: String? = nil,
        dockerPlatform: String? = nil,
        globalDDEVDir: String? = nil,
        webImage: String? = nil,
        dbImage: String? = nil,
        routerImage: String? = nil
    ) {
        self.ddevVersion = ddevVersion
        self.mutagenVersion = mutagenVersion
        self.dockerVersion = dockerVersion
        self.dockerAPIVersion = dockerAPIVersion
        self.buildxVersion = buildxVersion
        self.dockerPlatform = dockerPlatform
        self.globalDDEVDir = globalDDEVDir
        self.webImage = webImage
        self.dbImage = dbImage
        self.routerImage = routerImage
    }

    /// The image tag ddev itself would use (`v1.25.4`), derived from its own web image.
    /// Used to spot projects still running containers built from an older ddev release.
    public var expectedImageTag: String? { Self.tag(of: webImage) }

    /// `ddev/ddev-webserver:v1.25.4` → `v1.25.4`; tolerates a missing tag.
    public static func tag(of image: String?) -> String? {
        guard let image, let colon = image.lastIndex(of: ":") else { return nil }
        let tag = String(image[image.index(after: colon)...])
        return tag.isEmpty ? nil : tag
    }
}

public enum DDEVVersionParser {
    private struct Envelope: Decodable {
        let raw: [String: String]?
    }

    /// `ddev version -j` emits JSON-lines; one record carries a flat `raw` dictionary.
    public static func parse(_ output: String) throws -> DDEVVersionInfo {
        let decoder = JSONDecoder()
        for line in output.split(whereSeparator: \.isNewline) {
            guard let data = line.data(using: .utf8),
                  let envelope = try? decoder.decode(Envelope.self, from: data),
                  let raw = envelope.raw else { continue }
            return DDEVVersionInfo(
                ddevVersion: raw["DDEV version"],
                mutagenVersion: raw["mutagen"],
                dockerVersion: raw["docker"],
                dockerAPIVersion: raw["docker-api"],
                buildxVersion: raw["docker-buildx"],
                dockerPlatform: raw["docker-platform"],
                globalDDEVDir: raw["global-ddev-dir"],
                webImage: raw["web"],
                dbImage: raw["db"],
                routerImage: raw["router"]
            )
        }
        throw DDEVError.unparsableOutput(String(output.prefix(200)))
    }
}
