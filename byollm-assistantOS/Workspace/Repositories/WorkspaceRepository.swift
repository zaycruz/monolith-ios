//
//  WorkspaceRepository.swift
//  Workspace
//

import Foundation

protocol WorkspaceRepository {
    /// Fetch the current user's primary workspace (channels + DMs).
    func loadCurrentWorkspace() async throws -> Workspace

    /// Workspaces the user has access to (for a switcher UI).
    func listWorkspaces() async throws -> [Workspace]
}
