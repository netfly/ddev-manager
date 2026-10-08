import SwiftUI
import DDEVKit

/// Small shared layout for a label/value line in the detail popovers.
struct DetailRow: View {
    let label: String
    let value: String
    var monospaced = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: monospaced ? .monospaced : .default))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct DetailSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 2)
    }
}

enum DetailFormat {
    /// `2 h 14 m`, `3 m`, `45 s` — compact enough for a popover row.
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let days = total / 86_400, hours = (total % 86_400) / 3600
        let minutes = (total % 3600) / 60, secs = total % 60
        if days > 0 { return "\(days) d \(hours) h" }
        if hours > 0 { return "\(hours) h \(minutes) m" }
        if minutes > 0 { return "\(minutes) m" }
        return "\(secs) s"
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.1f %%", value)
    }
}
