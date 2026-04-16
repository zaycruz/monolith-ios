//
//  WorkspaceApp.swift
//  Workspace
//
//  Preview/entry shell for the Monolith workspace. NOT marked @main —
//  the existing byollm_assistantOSApp owns the @main attribute. When the
//  user wires this into a separate target, re-add `@main` to `struct
//  WorkspaceApp: App`.
//

import SwiftUI

/// Navigation routes managed by the per-tab NavigationStacks inside
/// `WorkspaceTabShell`.
enum WorkspaceRoute: Hashable {
    case channel(ChannelID)
    case dm(DMID)
    case thread(ThreadID)
}

/// Root view used by `AuthGatedRootView` once Clerk reports a signed-in
/// user. Delegates to `WorkspaceTabShell`, which owns tab selection and
/// a NavigationStack per tab.
struct WorkspaceRootView: View {

    private let workspaceRepo: WorkspaceRepository
    private let conversationRepo: ConversationRepository
    private let messageRepo: MessageRepository
    private let realtimeRepo: RealtimeRepository
    private let agentRepo: AgentRepository
    private let notificationRepo: NotificationRepository
    private let activityRepo: ActivityRepository

    init(
        workspaceRepo: WorkspaceRepository,
        conversationRepo: ConversationRepository,
        messageRepo: MessageRepository,
        realtimeRepo: RealtimeRepository,
        agentRepo: AgentRepository,
        notificationRepo: NotificationRepository,
        activityRepo: ActivityRepository
    ) {
        self.workspaceRepo = workspaceRepo
        self.conversationRepo = conversationRepo
        self.messageRepo = messageRepo
        self.realtimeRepo = realtimeRepo
        self.agentRepo = agentRepo
        self.notificationRepo = notificationRepo
        self.activityRepo = activityRepo
    }

    /// Convenience init that wires up mocks so the whole thing renders
    /// without external state.
    init() {
        let rt = MockRealtimeRepository()
        self.init(
            workspaceRepo: MockWorkspaceRepository(),
            conversationRepo: MockConversationRepository(),
            messageRepo: MockMessageRepository(realtime: rt),
            realtimeRepo: rt,
            agentRepo: MockAgentRepository(),
            notificationRepo: MockNotificationRepository(),
            activityRepo: MockActivityRepository()
        )
    }

    var body: some View {
        WorkspaceTabShell(
            workspaceRepo: workspaceRepo,
            conversationRepo: conversationRepo,
            messageRepo: messageRepo,
            realtimeRepo: realtimeRepo,
            agentRepo: agentRepo,
            notificationRepo: notificationRepo,
            activityRepo: activityRepo
        )
    }
}

// MARK: - Preview entry point
// IMPORTANT: No @main here. The existing byollm_assistantOSApp owns @main.
// When this module is moved to its own target, add `@main` to this struct.
struct WorkspaceApp: App {
    init() {}

    var body: some Scene {
        WindowGroup {
            WorkspaceRootView()
        }
    }
}

// AgentID conforms to Identifiable via its underlying struct definition,
// so we can pass it directly to `.sheet(item:)`.

#Preview("WorkspaceRootView") {
    WorkspaceRootView()
}
