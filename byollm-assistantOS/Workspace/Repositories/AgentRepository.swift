//
//  AgentRepository.swift
//  Workspace
//

import Foundation

protocol AgentRepository {
    // TODO(spec-decision): agent visibility model — do we list *all* agents in
    // the workspace, or only those the caller shares a channel with? Mock lists
    // all workspace agents for now.
    func listAgents() async throws -> [Agent]

    func loadAgent(_ id: AgentID) async throws -> Agent

    // TODO(spec-decision): agent launch naming rule — random adjective+noun,
    // user-chosen, or template-prefixed? Mock derives handle from invite.name
    // when provided, otherwise generates "agent-NNN".
    func invite(_ spec: AgentInviteSpec) async throws -> Agent
}
