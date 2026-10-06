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
    private let logLimit = 50
    private let logDefaultsKey = "ddevManager.actionLog"
    private let defaults: UserDefaults

    public init(service: DDEVService, engineProbe: EngineProbe, colima: ColimaController, defaults: UserDefaults = .standard) {
        self.service = service
        self.engineProbe = engineProbe
        self.colima = colima
        self.defaults = defaults
        self.log = defaults.stringArray(forKey: logDefaultsKey) ?? []
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
        defaults.set(log, forKey: logDefaultsKey)
    }
}
