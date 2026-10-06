import SwiftUI
import AppKit

/// App name, version, build date (from the executable's own mtime — accurate for
/// whatever build you're actually running, no extra build step needed), and credit.
struct AboutView: View {
    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "DDEV Manager"
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private var buildDate: String {
        guard let url = Bundle.main.executableURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = attrs[.modificationDate] as? Date else { return "unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private let websiteURL = URL(string: "https://www.markus-meier.consulting")!

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 48, height: 48)

            Text(appName)
                .font(.headline)

            Text("Version \(version) (\(buildNumber))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Built \(buildDate)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text("Built with ❤️ +")
                SparkleMark(size: 12)
                Text("by MM Consulting")
            }
            .font(.caption)
            .padding(.top, 4)

            Link(destination: websiteURL) {
                Text(websiteURL.host ?? websiteURL.absoluteString)
                    .font(.caption)
            }
        }
        .padding(16)
        .frame(width: 240)
    }
}
