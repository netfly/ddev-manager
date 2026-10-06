import SwiftUI

struct LogView: View {
    let entries: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                if entries.isEmpty {
                    Text("No actions yet").foregroundStyle(.secondary)
                } else {
                    ForEach(Array(entries.enumerated().reversed()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(10)
        }
        .frame(width: 360, height: 240)
    }
}
