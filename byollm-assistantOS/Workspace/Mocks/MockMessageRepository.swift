//
//  MockMessageRepository.swift
//  Workspace
//

import Foundation

final class MockMessageRepository: MessageRepository {

    private let realtime: MockRealtimeRepository?
    // Local stores for optimistic sends / reaction toggles.
    private var channelStore: [ChannelID: [WorkspaceMessage]] = [:]
    private var dmStore: [DMID: [WorkspaceMessage]] = [:]

    init(realtime: MockRealtimeRepository? = nil) {
        self.realtime = realtime
        // Seed with the fixtures.
        self.channelStore[MockChannels.clientOps.id] = MockMessages.clientOps
        self.dmStore[MockDMs.zayDispatch.id] = MockMessages.zayDispatchDM
    }

    func loadMessages(channelID: ChannelID) async throws -> [WorkspaceMessage] {
        return channelStore[channelID] ?? []
    }

    func loadDMMessages(dmID: DMID) async throws -> [WorkspaceMessage] {
        return dmStore[dmID] ?? []
    }

    func sendMessage(
        channelID: ChannelID,
        text: String,
        idempotencyKey: String
    ) async throws -> WorkspaceMessage {
        // TODO(spec-decision): idempotency key format — mock accepts any
        // non-empty key and simply echoes the message.
        guard !idempotencyKey.isEmpty else {
            throw MockRepositoryError.transient
        }

        let msg = WorkspaceMessage(
            id: MessageID("m_local_\(UUID().uuidString.prefix(8))"),
            author: MockMembers.zay, // viewer is Zay in the mock
            timestamp: Date(),
            text: text
        )
        var msgs = channelStore[channelID] ?? []
        msgs.append(msg)
        channelStore[channelID] = msgs

        realtime?.inject(.messageCreated(channelID: channelID, message: msg))
        return msg
    }

    func addReaction(messageID: MessageID, symbol: ReactionSymbol) async throws {
        realtime?.inject(.reactionAdded(messageID: messageID, symbol: symbol))
    }

    func removeReaction(messageID: MessageID, symbol: ReactionSymbol) async throws {
        realtime?.inject(.reactionRemoved(messageID: messageID, symbol: symbol))
    }
}
