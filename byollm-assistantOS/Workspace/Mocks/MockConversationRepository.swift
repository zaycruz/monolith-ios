//
//  MockConversationRepository.swift
//  Workspace
//

import Foundation

enum MockRepositoryError: Error, Equatable {
    // TODO(spec-decision): error taxonomy — how do we categorize not-found vs
    // forbidden vs transient vs policy-denied? Mock uses a small enum below.
    case notFound
    case forbidden
    case transient
}

final class MockConversationRepository: ConversationRepository {
    init() {}

    func loadChannel(_ id: ChannelID) async throws -> Channel {
        guard let channel = MockChannels.all.first(where: { $0.id == id }) else {
            throw MockRepositoryError.notFound
        }
        return channel
    }

    func loadDM(_ id: DMID) async throws -> DirectMessage {
        guard let dm = MockDMs.all.first(where: { $0.id == id }) else {
            throw MockRepositoryError.notFound
        }
        return dm
    }

    func loadThread(_ id: ThreadID) async throws -> MessageThread {
        if id == MockThreads.clientOpsTriageThread.id {
            return MockMessages.clientOpsTriageThreadFull
        }
        throw MockRepositoryError.notFound
    }
}
