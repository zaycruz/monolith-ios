//
//  MockWorkspaceRepository.swift
//  Workspace
//

import Foundation

final class MockWorkspaceRepository: WorkspaceRepository {
    init() {}

    func loadCurrentWorkspace() async throws -> Workspace {
        return MockWorkspaces.raavaOps
    }

    func listWorkspaces() async throws -> [Workspace] {
        return [MockWorkspaces.raavaOps]
    }
}
