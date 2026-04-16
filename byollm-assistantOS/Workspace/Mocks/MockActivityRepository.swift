//
//  MockActivityRepository.swift
//  Workspace
//
//  Deterministic activity feed drawn from MockActivity fixtures.
//

import Foundation

final class MockActivityRepository: ActivityRepository {
    init() {}

    func fetchRecent() async throws -> [ActivityEvent] {
        MockActivity.events.sorted { $0.timestamp > $1.timestamp }
    }
}
