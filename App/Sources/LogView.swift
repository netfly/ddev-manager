import SwiftUI
import DDEVKit

/// Takes the store directly (not a snapshot) so entries appear live as actions run,
/// even while the popover stays open.
struct LogView: View {
    let store: ProjectStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                if store.log.isEmpty {
                    Text("No actions yet — start, stop, restart, or power off a project to see results here.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(Array(store.log.enumerated().reversed()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 360, height: 240)
    }
}
