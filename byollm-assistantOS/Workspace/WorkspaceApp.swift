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

/// Navigation routes managed by `WorkspaceRootView`.
enum WorkspaceRoute: Hashable {
    case channel(ChannelID)
    case dm(DMID)
    case thread(ThreadID)
}

/// Root coordinator. Holds one set of mock repositories and a navigation
/// stack, and wires every screen together.
struct WorkspaceRootView: View {

    // One realtime instance shared so sends fan out.
    private let workspaceRepo: WorkspaceRepository
    private let conversationRepo: ConversationRepository
    private let messageRepo: MessageRepository
    private let realtimeRepo: RealtimeRepository
    private let agentRepo: AgentRepository
    private let notificationRepo: NotificationRepository

    @State private var path: [WorkspaceRoute] = []
    @State private var showingInvite: Bool = false
    @State private var showingAgentProfile: AgentID?

    init(
        workspaceRepo: WorkspaceRepository,
        conversationRepo: ConversationRepository,
        messageRepo: MessageRepository,
        realtimeRepo: RealtimeRepository,
        agentRepo: AgentRepository,
        notificationRepo: NotificationRepository
    ) {
        self.workspaceRepo = workspaceRepo
        self.conversationRepo = conversationRepo
        self.messageRepo = messageRepo
        self.realtimeRepo = realtimeRepo
        self.agentRepo = agentRepo
        self.notificationRepo = notificationRepo
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
            notificationRepo: MockNotificationRepository()
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            WorkspaceHomeView(
                workspaceRepo: workspaceRepo,
                onOpenChannel: { path.append(.channel($0)) },
                onOpenDM: { path.append(.dm($0)) },
                onOpenInviteAgent: { showingInvite = true }
            )
            .navigationDestination(for: WorkspaceRoute.self) { route in
                switch route {
                case .channel(let id):
                    ChannelView(
                        channelID: id,
                        conversationRepo: conversationRepo,
                        messageRepo: messageRepo,
                        realtimeRepo: realtimeRepo,
                        onOpenThread: { path.append(.thread($0)) }
                    )
                case .dm(let id):
                    AgentDMView(
                        dmID: id,
                        conversationRepo: conversationRepo,
                        messageRepo: messageRepo,
                        onOpenAgent: { showingAgentProfile = $0 }
                    )
                case .thread(let id):
                    ThreadView(
                        threadID: id,
                        conversationRepo: conversationRepo,
                        onClose: { if !path.isEmpty { path.removeLast() } }
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingInvite) {
            InviteAgentSheet(
                agentRepo: agentRepo,
                onClose: { showingInvite = false },
                onInvited: { _ in showingInvite = false }
            )
        }
        .sheet(item: $showingAgentProfile) { agentID in
            AgentProfileSheet(
                agentID: agentID,
                agentRepo: agentRepo,
                onClose: { showingAgentProfile = nil }
            )
        }
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
