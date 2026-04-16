//
//  MockAgentRepository.swift
//  Workspace
//

import Foundation

final class MockAgentRepository: AgentRepository {

    private var agents: [Agent] = MockAgents.all
    private var counter: Int = 0

    init() {}

    func listAgents() async throws -> [Agent] {
        return agents
    }

    func loadAgent(_ id: AgentID) async throws -> Agent {
        guard let a = agents.first(where: { $0.id == id }) else {
            throw MockRepositoryError.notFound
        }
        return a
    }

    func invite(_ spec: AgentInviteSpec) async throws -> Agent {
        counter += 1
        // TODO(spec-decision): agent launch naming rule — mock uses spec.name if
        // provided, otherwise "agent-\(counter padded)".
        let handle = spec.name ?? String(format: "agent-%03d", counter)
        let initials: String = {
            let lower = handle.lowercased()
            return String(lower.prefix(2))
        }()

        let newAgent = Agent(
            id: AgentID("a_\(handle)"),
            handle: handle,
            initials: initials,
            status: .running,
            template: spec.template,
            joinedAt: Date(),
            invitedBy: MockHumans.zay.id,
            channelIDs: spec.channelIDs,
            instanceSize: spec.instanceSize,
            vcpu: Self.vcpu(for: spec.instanceSize),
            memoryGB: Self.memory(for: spec.instanceSize),
            region: "us-east-4",
            uptimeSeconds: 0,
            model: "anthropic claude-opus-4-6",
            tokens24h: 0
        )
        agents.append(newAgent)
        return newAgent
    }

    private static func vcpu(for size: String) -> Int {
        switch size {
        case "m8g.small": return 1
        case "m8g.large": return 4
        default: return 2 // m8g.medium
        }
    }

    private static func memory(for size: String) -> Int {
        switch size {
        case "m8g.small": return 2
        case "m8g.large": return 8
        default: return 4
        }
    }
}
