//
//  ActivityRepository.swift
//  Workspace
//
//  Feed of notable events surfaced in the Activity tab — mentions,
//  alerts, thread replies, agent completions.
//

import Foundation

protocol ActivityRepository {
    /// Fetch the most recent activity events, sorted newest-first.
    func fetchRecent() async throws -> [ActivityEvent]
}
