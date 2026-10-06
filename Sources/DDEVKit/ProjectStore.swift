import Foundation
import Observation

@MainActor
@Observable
public final class ProjectStore {
    public private(set) var projects: [DDEVProject] = []
    public private(set) var busyProjects: Set<String> = []
    public private(set) var isRefreshing = false
    public private(set) var engine: EngineState = .down(reason: "not probed yet")
    public private(set) var engineKind: ContainerEngineKind = .unknown("")
    public private(set) var log: [String] = []
    public var lastError: String?

    private let service: DDEVService
    private let engineProbe: EngineProbe
    private let containerEngine: ContainerEngineController
    private let logLimit = 50
    private let logDefaultsKey = "ddevManager.actionLog"
    private let defaults: UserDefaults

    public init(
        service: DDEVService,
        engineProbe: EngineProbe,
        containerEngine: ContainerEngineController,
        defaults: UserDefaults = .standard
    ) {
        self.service = service
        self.engineProbe = engineProbe
        self.containerEngine = containerEngine
        self.defaults = defaults
        self.log = defaults.stringArray(forKey: logDefaultsKey) ?? []
    }

    /// Whether the panel can offer a working "Start …" button for the detected backend
    /// (Colima, Docker Desktop, OrbStack, Rancher Desktop, or a best-effort Colima fallback).
    public var canStartEngine: Bool { containerEngine.canStart(kind: engineKind) }
    public var engineKindDisplayName: String { engineKind.displayName }

    public func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        engine = await engineProbe.probe()
        engineKind = await containerEngine.detectKind()
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

    public func startEngine() async {
        let kind = engineKind
        await perform("__engine__", label: "start \(kind.displayName)") { try await containerEngine.start(kind: kind) }
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
