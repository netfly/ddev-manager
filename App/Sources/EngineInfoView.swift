import SwiftUI
import DDEVKit

/// Badge popover: which backend is actually answering (A1), the ddev toolchain versions (A7),
/// and live CPU/memory across all containers (A9). Takes the store itself — not a snapshot —
/// so values appear as soon as the on-demand load finishes while the popover stays open.
struct EngineInfoView: View {
    let store: ProjectStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                DetailSectionHeader(title: "Container engine")
                DetailRow(label: "Backend", value: store.engineKindDisplayName)
                DetailRow(label: "Status", value: statusText)
                if let context = store.engineDetails?.contextName {
                    DetailRow(label: "docker context", value: context, monospaced: true)
                }
                if let socket = store.engineDetails?.socketPath, !socket.isEmpty {
                    DetailRow(label: "Endpoint", value: socket, monospaced: true)
                }

                if let version = store.engineDetails?.version {
                    Divider()
                    DetailSectionHeader(title: "Toolchain")
                    if let v = version.ddevVersion { DetailRow(label: "ddev", value: v) }
                    if let v = version.dockerVersion { DetailRow(label: "docker", value: v) }
                    if let v = version.dockerAPIVersion { DetailRow(label: "docker API", value: v) }
                    if let v = version.buildxVersion { DetailRow(label: "buildx", value: v) }
                    if let v = version.mutagenVersion { DetailRow(label: "mutagen", value: v) }
                    if let v = version.dockerPlatform { DetailRow(label: "ddev platform", value: v, monospaced: true) }
                    if let v = version.globalDDEVDir { DetailRow(label: "global dir", value: v, monospaced: true) }
                }

                Divider()
                DetailSectionHeader(title: "Live usage")
                if let details = store.engineDetails, details.runningContainerCount > 0 {
                    DetailRow(label: "Containers", value: "\(details.runningContainerCount) running")
                    DetailRow(label: "CPU", value: DetailFormat.percent(details.totalCPUPercent))
                    DetailRow(label: "Memory", value: DockerSize.format(details.totalMemoryBytes))
                } else if store.isLoadingEngineDetails {
                    ProgressView().controlSize(.small)
                } else {
                    Text("No running containers.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 330, height: 330)
        .task { await store.loadEngineDetails() }
    }

    private var statusText: String {
        switch store.engine {
        case .running(let version): "reachable · server \(version)"
        case .down(let reason): "down — \(reason)"
        case .dockerMissing: "no `docker` CLI found"
        }
    }
}
