//
//  NotificationRepository.swift
//  Workspace
//

import Foundation

protocol NotificationRepository {
    func loadUnread() async throws -> [WorkspaceNotification]

    // TODO(spec-decision): read receipts policy — per-message, per-channel
    // high-water mark, or none? Mock uses per-channel high-water mark.
    func markChannelRead(_ id: ChannelID) async throws
    func markAllRead() async throws
}
