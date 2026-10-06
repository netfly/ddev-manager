import Foundation
import Observation

@MainActor
@Observable
public final class ProjectStore {
    public private(set) var projects: [DDEVProject] = []
    public private(set) var busyProjects: Set<String> = []
    public private(set) var isRefreshing = false
    public private(set) var engine: EngineState = .down(reason: "not probed yet")
    public private(set) var log: [String] = []
    public var lastError: String?

    private let service: DDEVService
    private let engineProbe: EngineProbe
    private let colima: ColimaController
    private let logLimit = 20

    public init(service: DDEVService, engineProbe: EngineProbe, colima: ColimaController) {
        self.service = service
        self.engineProbe = engineProbe
        self.colima = colima
    }

    public var colimaAvailable: Bool { colima.isAvailable }

    public func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        engine = await engineProbe.probe()
        do {
            projects = try await service.list()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func start(_ name: String) async { await perform(name, label: "start \(name)") { try await service.start(name) } }
    public func stop(_ name: String) async { await perform(name, label: "stop \(name)") { try await service.stop(name) } }
    public func restart(_ name: String) async { await perform(name, label: "restart \(name)") { try await service.restart(name) } }

    public func poweroffAll() async {
        await perform("__all__", label: "poweroff") { try await service.poweroff() }
    }

    /// Starts every non-running project, one at a time (ddev serialises anyway;
    /// parallel starts fight over the shared router).
    public func startAllStopped() async {
        let names = projects.filter { !$0.status.isRunning }.map(\.name)
        await perform("__startAll__", label: "start all stopped") {
            for name in names { try await service.start(name) }
        }
    }

    public func startColima() async {
        await perform("__colima__", label: "start colima") { try await colima.start() }
    }

    public func isBusy(_ name: String) -> Bool { busyProjects.contains(name) }

    private func perform(_ name: String, label: String, _ action: () async throws -> Void) async {
        busyProjects.insert(name)
        defer { busyProjects.remove(name) }
        do {
            try await action()
            lastError = nil
            appendLog("✅ \(label) succeeded")
        } catch {
            lastError = error.localizedDescription
            appendLog("❌ \(label) failed: \(error.localizedDescription)")
        }
        await refresh()
    }

    private func appendLog(_ line: String) {
        log.append(line)
        if log.count > logLimit {
            log.removeFirst(log.count - logLimit)
        }
    }
}
