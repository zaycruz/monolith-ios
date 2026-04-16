//
//  MessageRepository.swift
//  Workspace
//

import Foundation

protocol MessageRepository {
    /// Paged/bulk load of messages for a channel.
    func loadMessages(channelID: ChannelID) async throws -> [WorkspaceMessage]

    /// Messages for a DM conversation.
    func loadDMMessages(dmID: DMID) async throws -> [WorkspaceMessage]

    /// Send a new message. `idempotencyKey` is supplied by the client to make
    /// the send safe to retry.
    // TODO(spec-decision): idempotency key format — UUID, ULID, or client-local
    // monotonic? Mock accepts any non-empty string.
    func sendMessage(
        channelID: ChannelID,
        text: String,
        idempotencyKey: String
    ) async throws -> WorkspaceMessage

    /// Add / remove a reaction by symbol.
    func addReaction(messageID: MessageID, symbol: ReactionSymbol) async throws
    func removeReaction(messageID: MessageID, symbol: ReactionSymbol) async throws
}
