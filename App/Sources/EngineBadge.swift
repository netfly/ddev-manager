import SwiftUI
import DDEVKit

struct EngineBadge: View {
    let state: EngineState

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 8, height: 8)
            Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .help(helpText)
    }

    private var dot: Color {
        switch state {
        case .running: .green
        case .down: .red
        case .dockerMissing: .orange
        }
    }

    private var text: String {
        switch state {
        case .running(let v): "Docker \(v)"
        case .down: "Container engine down"
        case .dockerMissing: "docker not found"
        }
    }

    private var helpText: String {
        switch state {
        case .down(let reason): "Container engine not reachable: \(reason)"
        case .dockerMissing: "No `docker` CLI found. Install Docker Desktop, OrbStack, Rancher Desktop, or Colima + docker."
        case .running: "Container engine reachable"
        }
    }
}
