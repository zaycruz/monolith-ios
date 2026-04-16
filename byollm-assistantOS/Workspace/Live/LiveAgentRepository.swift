//
//  LiveAgentRepository.swift
//  Workspace
//
//  `AgentRepository` implementation backed by the Raava Fleet control
//  plane. Pass 2 swaps ONLY this repo to live — workspace, conversation,
//  message, realtime, and notification stay on mocks.
//
//  Fleet API endpoints consumed:
//    GET /api/containers                       — list agents (one per container)
//    GET /api/containers/{id}                  — single agent detail
//    GET /api/containers/{id}/agent            — runtime agent metadata (pid/uptime/stack)
//
//  Naming note: in the Fleet model, each agent runs inside exactly one
//  container, and the workspace `AgentID` carries the container id.
//  So `loadAgent(AgentID("c_abc"))` issues `/api/containers/c_abc`.
//
//  `invite(_:)` is not yet exposed by the control plane, so it throws
//  `FleetAPIError.unsupported`. A future pass will add launch support.
//

import Foundation

// MARK: - Wire models
//
// These mirror the JSON shape from `routers/containers.py::_format_container`
// and `routers/agents.py::get_agent`. Keep them private so the domain
// `Agent` struct remains the only public shape.
//
// The client's JSONDecoder uses `.convertFromSnakeCase`, so these
// properties are camelCase here but map to snake_case keys on the wire.

private struct FleetContainerList: Decodable {
    let containers: [FleetContainer]
}

private struct FleetContainer: Decodable {
    let id: String
    let agentName: String?
    let agentRole: String?
    let model: String?
    let status: String?
    let instanceType: String?
    let memoryLimit: String?
    let cpuLimit: String?
    let createdAt: String?
    // Region is not in the current Fleet payload; kept optional so adding it
    // later is a non-breaking change.
    let region: String?
}

private struct FleetAgentInfo: Decodable {
    let pid: Int?
    let status: String?
    let uptime: String?
    let command: String?
    let stack: String?
}

// MARK: - Repository

final class LiveAgentRepository: AgentRepository {

    private let client: LiveFleetClient

    init(client: LiveFleetClient) {
        self.client = client
    }

    func listAgents() async throws -> [Agent] {
        let response = try await client.get(
            "/api/containers",
            as: FleetContainerList.self
        )
        return response.containers.map { Self.agent(from: $0, runtime: nil) }
    }

    func loadAgent(_ id: AgentID) async throws -> Agent {
        // Fetch container metadata + runtime agent info in parallel. The
        // runtime call is best-effort: if it fails or the agent process
        // isn't running, we still return the base profile.
        async let containerTask = client.get(
            "/api/containers/\(id.value)",
            as: FleetContainer.self
        )
        async let runtimeTask: FleetAgentInfo? = {
            do {
                return try await client.get(
                    "/api/containers/\(id.value)/agent",
                    as: FleetAgentInfo.self
                )
            } catch {
                return nil
            }
        }()

        let container = try await containerTask
        let runtime = await runtimeTask
        return Self.agent(from: container, runtime: runtime)
    }

    func invite(_ spec: AgentInviteSpec) async throws -> Agent {
        // TODO(workspace-api): Fleet control plane does not yet expose a
        // tenant-safe agent-launch endpoint for mobile. Until it does we
        // surface this clearly instead of silently falling back to a mock.
        throw FleetAPIError.unsupported("agent launch is not yet available over the Fleet API")
    }

    // MARK: - Mapping

    /// Map a Fleet container payload (plus optional runtime info) into the
    /// workspace `Agent` shape. Field mapping is *not* 1:1 — several
    /// fields need a small transform:
    ///
    /// - `agent_name` → `handle` (falls back to `id` if missing)
    /// - handle → `initials` (first two letters, lowercased)
    /// - `status` string → `AgentStatus` enum
    /// - `instance_type` → `instanceSize`; vcpu/memoryGB derived from it
    /// - `created_at` ISO-8601 string → `joinedAt` Date
    /// - runtime `uptime` ("1h 23m" / "01:23:45") → `uptimeSeconds` Int
    /// - `tokens24h` is not yet emitted by the Fleet API — left nil.
    private static func agent(
        from c: FleetContainer,
        runtime: FleetAgentInfo?
    ) -> Agent {
        let handle = c.agentName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? c.id
        let initials = String(handle.lowercased().prefix(2))

        return Agent(
            id: AgentID(c.id),
            handle: handle,
            initials: initials,
            status: parseStatus(c.status, runtime: runtime),
            template: c.agentRole,
            joinedAt: parseDate(c.createdAt),
            invitedBy: nil,
            channelIDs: [],
            instanceSize: c.instanceType?.nonEmpty,
            vcpu: vcpu(for: c.instanceType),
            memoryGB: memoryGB(from: c.memoryLimit),
            region: c.region?.nonEmpty,
            uptimeSeconds: parseUptime(runtime?.uptime),
            model: c.model?.nonEmpty,
            tokens24h: nil
        )
    }

    private static func parseStatus(_ raw: String?, runtime: FleetAgentInfo?) -> AgentStatus {
        switch (raw ?? "").lowercased() {
        case "error", "failed": return .error
        case "running", "active":
            // Container running but the agent process may still be stopped.
            if let rt = runtime?.status?.lowercased(), rt == "stopped" {
                return .idle
            }
            return .running
        default:
            return .idle
        }
    }

    private static func parseDate(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: s)
    }

    /// Parse Fleet's uptime strings. The Fleet API returns either
    /// `"1d 2h 15m"` (from `_format_uptime_seconds`) or the raw `ps -o
    /// etime=` output like `"01:23:45"` / `"2-03:04:05"`.
    private static func parseUptime(_ raw: String?) -> Int? {
        guard let raw, !raw.isEmpty else { return nil }
        let s = raw.trimmingCharacters(in: .whitespaces)

        // "Nd Nh Nm" style
        if s.contains("d") || s.contains("h") || s.contains("m") {
            var total = 0
            let parts = s.split(separator: " ")
            for p in parts {
                let str = String(p)
                if str.hasSuffix("d"), let n = Int(str.dropLast()) { total += n * 86400 }
                else if str.hasSuffix("h"), let n = Int(str.dropLast()) { total += n * 3600 }
                else if str.hasSuffix("m"), let n = Int(str.dropLast()) { total += n * 60 }
                else if str.hasSuffix("s"), let n = Int(str.dropLast()) { total += n }
            }
            return total > 0 ? total : nil
        }

        // "D-HH:MM:SS" or "HH:MM:SS" or "MM:SS"
        var days = 0
        var rest = s
        if let dashIdx = rest.firstIndex(of: "-") {
            days = Int(rest[..<dashIdx]) ?? 0
            rest = String(rest[rest.index(after: dashIdx)...])
        }
        let segs = rest.split(separator: ":").map { Int($0) ?? 0 }
        switch segs.count {
        case 3: return days * 86400 + segs[0] * 3600 + segs[1] * 60 + segs[2]
        case 2: return days * 86400 + segs[0] * 60 + segs[1]
        default: return nil
        }
    }

    private static func vcpu(for instanceType: String?) -> Int? {
        guard let t = instanceType?.lowercased() else { return nil }
        if t.hasSuffix(".small")  { return 1 }
        if t.hasSuffix(".medium") { return 2 }
        if t.hasSuffix(".large")  { return 4 }
        if t.hasSuffix(".xlarge") { return 8 }
        return nil
    }

    /// `memory_limit` on the wire is a string like `"4096MB"` or `"8GB"`.
    private static func memoryGB(from limit: String?) -> Int? {
        guard let raw = limit?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
            return nil
        }
        let lower = raw.lowercased()
        let digits = lower.filter { "0123456789.".contains($0) }
        guard let value = Double(digits) else { return nil }
        if lower.contains("gb") { return Int(value.rounded()) }
        if lower.contains("mb") { return Int((value / 1024.0).rounded()) }
        return nil
    }
}

private extension String {
    /// `self` when non-empty, else `nil`. Handy for treating API "" as absent.
    var nonEmpty: String? { isEmpty ? nil : self }
}
