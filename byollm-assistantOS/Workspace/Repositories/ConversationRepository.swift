//
//  ConversationRepository.swift
//  Workspace
//

import Foundation

protocol ConversationRepository {
    func loadChannel(_ id: ChannelID) async throws -> Channel
    func loadDM(_ id: DMID) async throws -> DirectMessage
    func loadThread(_ id: ThreadID) async throws -> MessageThread
}
