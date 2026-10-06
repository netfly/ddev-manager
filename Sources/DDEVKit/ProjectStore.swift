import Foundation
import Observation

@MainActor
@Observable
public final class ProjectStore {
    public private(set) var projects: [DDEVProject] = []
    public private(set) var busyProjects: Set<String> = []
    public private(set) var isRefreshing = false
    public private(set) var engine: EngineState = .down(reason: "not probed yet")
    public var lastError: String?

    private let service: DDEVService
    private let engineProbe: EngineProbe

    public init(service: DDEVService, engineProbe: EngineProbe) {
        self.service = service
        self.engineProbe = engineProbe
    }

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

    public func start(_ name: String) async { await perform(name) { try await service.start(name) } }
    public func stop(_ name: String) async { await perform(name) { try await service.stop(name) } }
    public func restart(_ name: String) async { await perform(name) { try await service.restart(name) } }

    public func poweroffAll() async {
        await perform("__all__") { try await service.poweroff() }
    }

    public func isBusy(_ name: String) -> Bool { busyProjects.contains(name) }

    private func perform(_ name: String, _ action: () async throws -> Void) async {
        busyProjects.insert(name)
        defer { busyProjects.remove(name) }
        do {
            try await action()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        await refresh()
    }
}
