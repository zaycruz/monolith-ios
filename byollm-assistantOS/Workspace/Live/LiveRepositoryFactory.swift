//
//  LiveRepositoryFactory.swift
//  Workspace
//
//  Builds the repository set used by `WorkspaceRootView` for signed-in
//  users. Pass 2 wires ONLY the agent repo to live — everything else
//  (workspace, conversation, message, realtime, notification) stays on
//  mocks until subsequent passes swap them over.
//
//  The Clerk bearer token is fetched lazily per-request via
//  `FleetTokenProvider`, so the factory itself takes no token.
//

import Foundation
import ClerkKit

/// Bundle of all six repositories consumed by `WorkspaceRootView`. Using
/// a value type here keeps the wiring visible at the call site.
struct WorkspaceRepositorySet {
    let workspaceRepo: WorkspaceRepository
    let conversationRepo: ConversationRepository
    let messageRepo: MessageRepository
    let realtimeRepo: RealtimeRepository
    let agentRepo: AgentRepository
    let notificationRepo: NotificationRepository
    let activityRepo: ActivityRepository
}

enum LiveRepositoryFactory {

    /// Build the live-agent / mock-everything-else set used once Clerk
    /// reports a signed-in user. Uses `Clerk.shared.session?.getToken()`
    /// as the bearer source — the token is never logged or cached here.
    static func signedIn() -> WorkspaceRepositorySet {
        let client = LiveFleetClient(
            baseURL: MonolithConfig.fleetAPIBaseURL,
            tokenProvider: {
                // Clerk is @MainActor-bound. Pull the current session on
                // the main actor, then request a fresh JWT. Any failure
                // (no session, SDK error) resolves to nil so the request
                // proceeds unauthenticated — the server will reject it.
                let session = await MainActor.run { Clerk.shared.session }
                guard let session else { return nil }
                return try? await session.getToken()
            }
        )

        let rt = MockRealtimeRepository()
        return WorkspaceRepositorySet(
            workspaceRepo: MockWorkspaceRepository(),
            conversationRepo: MockConversationRepository(),
            messageRepo: MockMessageRepository(realtime: rt),
            realtimeRepo: rt,
            agentRepo: LiveAgentRepository(client: client),
            notificationRepo: MockNotificationRepository(),
            activityRepo: MockActivityRepository()
        )
    }

    /// Fully-mocked set. Used for signed-out state, previews, and tests.
    static func allMocks() -> WorkspaceRepositorySet {
        let rt = MockRealtimeRepository()
        return WorkspaceRepositorySet(
            workspaceRepo: MockWorkspaceRepository(),
            conversationRepo: MockConversationRepository(),
            messageRepo: MockMessageRepository(realtime: rt),
            realtimeRepo: rt,
            agentRepo: MockAgentRepository(),
            notificationRepo: MockNotificationRepository(),
            activityRepo: MockActivityRepository()
        )
    }
}

