import Foundation

/// The latest ddev release as reported by GitHub (`tag_name` like `v1.25.5`).
public struct DDEVRelease: Equatable, Sendable, Decodable {
    public let tagName: String
    public let htmlURL: String

    public init(tagName: String, htmlURL: String) {
        self.tagName = tagName
        self.htmlURL = htmlURL
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }

    /// Fetches the latest release; injected into `ProjectStore` so tests never hit the network.
    public typealias Fetcher = @Sendable () async throws -> DDEVRelease

    public static let fetchLatestFromGitHub: Fetcher = {
        var request = URLRequest(
            url: URL(string: "https://api.github.com/repos/ddev/ddev/releases/latest")!,
            timeoutInterval: 10
        )
        request.setValue("DDEVManager", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(DDEVRelease.self, from: data)
    }

    /// `v1.25.4` / `1.25.4` → `[1, 25, 4]`; prerelease/suffixed or malformed tags → nil.
    public static func numericVersion(_ tag: String) -> [Int]? {
        let core = tag.hasPrefix("v") ? tag.dropFirst() : Substring(tag)
        // Int("+4") would parse, so require plain ASCII digits.
        let parts = core.split(separator: ".", omittingEmptySubsequences: false)
            .map { $0.allSatisfy { $0.isASCII && $0.isNumber } ? Int($0) : nil }
        guard parts.count == 3, parts.allSatisfy({ ($0 ?? -1) >= 0 }) else { return nil }
        return parts.compactMap { $0 }
    }

    /// True only when both tags are plain `MAJOR.MINOR.PATCH` and `latest` is strictly newer.
    public static func isNewer(_ latest: String, than installed: String) -> Bool {
        guard let l = numericVersion(latest), let i = numericVersion(installed) else { return false }
        return i.lexicographicallyPrecedes(l)
    }
}
