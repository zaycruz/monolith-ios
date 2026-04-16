//
//  MockNotificationRepository.swift
//  Workspace
//

import Foundation

final class MockNotificationRepository: NotificationRepository {

    private var unread: [WorkspaceNotification] = [
        WorkspaceNotification(
            id: "n_1",
            title: "#client-ops",
            body: "dispatch: Overnight triage for IWP…",
            timestamp: MockClock.at(hour: 8, minute: 42)
        ),
        WorkspaceNotification(
            id: "n_2",
            title: "#engineering",
            body: "herald: Deploy pipeline green for release-1.14.",
            timestamp: MockClock.at(hour: 9, minute: 3)
        )
    ]

    // Per-channel high-water marks.
    private var channelHighWater: [ChannelID: Date] = [:]

    init() {}

    func loadUnread() async throws -> [WorkspaceNotification] {
        return unread
    }

    func markChannelRead(_ id: ChannelID) async throws {
        channelHighWater[id] = Date()
    }

    func markAllRead() async throws {
        unread = []
    }
}
