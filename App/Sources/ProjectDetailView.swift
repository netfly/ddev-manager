import SwiftUI
import DDEVKit

/// Per-project detail popover (ⓘ in the row): stack versions, docroot, performance mode,
/// per-container state/uptime, live CPU+memory, disk usage, and an image-drift warning.
/// Everything here is loaded on demand — `ddev describe` costs a process per project, so it
/// must never run as part of the panel's list refresh.
struct ProjectDetailView: View {
    let project: DDEVProject
    let store: ProjectStore

    private var details: ProjectDetails? { store.projectDetails[project.name] }
    private var error: String? { store.detailErrors[project.name] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                header
                if let details {
                    stackSection(details.description)
                    Divider()
                    performanceSection(details.description)
                    Divider()
                    containersSection(details)
                    Divider()
                    diskSection(details)
                    if let drift = details.drift, drift.isDrifting {
                        Divider()
                        driftSection(drift)
                    }
                } else if let error {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ProgressView().controlSize(.small).padding(.top, 6)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 350, height: 400)
        .task { await store.loadDetails(for: project.name) }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(project.name).font(.system(size: 12, weight: .semibold))
            Text(project.status.label).font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer()
            if store.isLoadingDetails(project.name) {
                ProgressView().controlSize(.small)
            } else {
                Button { Task { await store.loadDetails(for: project.name) } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Reload details")
            }
        }
    }

    @ViewBuilder
    private func stackSection(_ description: DDEVProjectDescription) -> some View {
        DetailSectionHeader(title: "Stack")
        if let type = description.type ?? Optional(project.type) {
            DetailRow(label: "Type", value: type)
        }
        if let php = description.phpVersion { DetailRow(label: "PHP", value: php) }
        if let webserver = description.webserverType { DetailRow(label: "Webserver", value: webserver) }
        if let database = description.databaseSummary { DetailRow(label: "Database", value: database) }
        if let node = description.nodejsVersion { DetailRow(label: "Node.js", value: node) }
        DetailRow(label: "Docroot", value: docrootText(description), monospaced: true)
    }

    /// ddev reports an empty docroot when the app lives at the project root.
    private func docrootText(_ description: DDEVProjectDescription) -> String {
        let value = description.docroot ?? ""
        return value.isEmpty ? "— (project root)" : value
    }

    @ViewBuilder
    private func performanceSection(_ description: DDEVProjectDescription) -> some View {
        DetailSectionHeader(title: "Performance")
        DetailRow(label: "Mode", value: description.performanceMode ?? "—")
        if description.mutagenEnabled == true {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Mutagen sync")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 92, alignment: .leading)
                HStack(spacing: 5) {
                    Circle().fill(mutagenColor(description.mutagenStatus)).frame(width: 7, height: 7)
                    Text(description.mutagenStatus ?? "unknown").font(.system(size: 11))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            DetailRow(label: "Mutagen sync", value: "disabled")
        }
    }

    private func mutagenColor(_ status: String?) -> Color {
        switch status?.lowercased() {
        case "ok": .green
        case "paused", "stopped", nil: .secondary
        case "disabled": .secondary
        default: .orange
        }
    }

    @ViewBuilder
    private func containersSection(_ details: ProjectDetails) -> some View {
        DetailSectionHeader(title: "Containers")
        if details.containers.isEmpty {
            Text("No containers — ddev removes a project's containers when it is stopped.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            ForEach(details.containers, id: \.info.name) { container in
                containerRow(container)
            }
        }
    }

    @ViewBuilder
    private func containerRow(_ container: ContainerDetail) -> some View {
        let info = container.info
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Circle().fill(containerColor(info)).frame(width: 7, height: 7)
                Text(info.shortName(project: project.name)).font(.system(size: 11, weight: .medium))
                Text(statusText(info)).font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                if info.restartCount > 0 {
                    Text("\(info.restartCount) restarts")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }
            }
            if let stat = container.stat {
                Text("CPU \(DetailFormat.percent(stat.cpuPercent ?? 0)) · RAM \(stat.memoryUsageText)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 12)
            }
        }
    }

    private func statusText(_ info: ContainerInfo) -> String {
        var parts = [info.status]
        if let health = info.health { parts.append(health) }
        if let uptime = info.uptime { parts.append("up \(DetailFormat.duration(uptime))") }
        return parts.joined(separator: " · ")
    }

    private func containerColor(_ info: ContainerInfo) -> Color {
        guard info.isRunning else { return .secondary }
        switch info.health {
        case "healthy", nil: return .green
        case "starting": return .yellow
        default: return .red
        }
    }

    @ViewBuilder
    private func diskSection(_ details: ProjectDetails) -> some View {
        DetailSectionHeader(title: "Disk usage")
        if details.volumes.isEmpty {
            DetailRow(label: "Volumes", value: "none")
        } else {
            DetailRow(label: "Data", value: DockerSize.format(details.dataBytes))
            if details.cacheBytes > 0 {
                DetailRow(label: "Sync cache", value: DockerSize.format(details.cacheBytes))
            }
            DetailRow(label: "Total", value: DockerSize.format(details.totalBytes))
            ForEach(details.volumes, id: \.name) { volume in
                Text("\(volume.name) · \(volume.sizeText)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func driftSection(_ drift: ImageDrift) -> some View {
        DetailSectionHeader(title: "Images")
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Built on older ddev images (\(drift.outdatedServices.joined(separator: ", ")))")
                    .font(.system(size: 11))
                Text(driftDetail(drift))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("Run `ddev restart` to rebuild on \(drift.expectedTag).")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func driftDetail(_ drift: ImageDrift) -> String {
        drift.outdatedServices
            .map { "\($0): \(drift.tagsByService[$0] ?? "?") → \(drift.expectedTag)" }
            .joined(separator: "\n")
    }
}
