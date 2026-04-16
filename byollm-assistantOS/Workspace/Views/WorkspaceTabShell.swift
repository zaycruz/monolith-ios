//
//  WorkspaceTabShell.swift
//  Workspace
//
//  Root container that owns tab selection + one NavigationStack per tab.
//  Each tab keeps its own navigation path so switching tabs doesn't lose
//  drill-down state within a tab. Shared sheets (invite agent, agent
//  profile) live at the shell level.
//

import SwiftUI

struct WorkspaceTabShell: View {

    // Repositories, injected from AuthGatedRootView / previews.
    private let workspaceRepo: WorkspaceRepository
    private let conversationRepo: ConversationRepository
    private let messageRepo: MessageRepository
    private let realtimeRepo: RealtimeRepository
    private let agentRepo: AgentRepository
    private let notificationRepo: NotificationRepository
    private let activityRepo: ActivityRepository

    // Tab selection lives here, not in any individual tab view.
    @State private var selectedTab: WorkspaceTab = .home

    // Per-tab navigation paths — each tab keeps its own drill-down stack.
    @State private var homePath: [WorkspaceRoute] = []
    @State private var dmsPath: [WorkspaceRoute] = []
    @State private var activityPath: [WorkspaceRoute] = []

    // Shared sheets — attached at the shell level so any tab can open them.
    @State private var showingInvite: Bool = false
    @State private var showingAgentProfile: AgentID?

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

    var body: some View {
        VStack(spacing: 0) {
            // Active tab content. Keeping this as a switch (rather than a
            // TabView) lets us bring our own bottom bar with the exact
            // typography/tokens already on Home.
            Group {
                switch selectedTab {
                case .home:     homeStack
                case .dms:      dmsStack
                case .activity: activityStack
                case .you:      youStack
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar(selection: $selectedTab)
        }
        .background(MonolithTheme.Colors.bgBase.ignoresSafeArea())
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

    // MARK: - Home tab
    private var homeStack: some View {
        NavigationStack(path: $homePath) {
            WorkspaceHomeView(
                workspaceRepo: workspaceRepo,
                onOpenChannel: { homePath.append(.channel($0)) },
                onOpenDM: { homePath.append(.dm($0)) },
                onOpenInviteAgent: { showingInvite = true }
            )
            .navigationDestination(for: WorkspaceRoute.self) { route in
                destination(route, path: $homePath)
            }
        }
    }

    // MARK: - DMs tab
    private var dmsStack: some View {
        NavigationStack(path: $dmsPath) {
            DMsTabView(
                workspaceRepo: workspaceRepo,
                onOpenDM: { dmsPath.append(.dm($0)) }
            )
            .navigationDestination(for: WorkspaceRoute.self) { route in
                destination(route, path: $dmsPath)
            }
        }
    }

    // MARK: - Activity tab
    private var activityStack: some View {
        NavigationStack(path: $activityPath) {
            ActivityTabView(
                activityRepo: activityRepo,
                onOpenChannel: { activityPath.append(.channel($0)) },
                onOpenThread: { activityPath.append(.thread($0)) },
                onOpenDM: { activityPath.append(.dm($0)) }
            )
            .navigationDestination(for: WorkspaceRoute.self) { route in
                destination(route, path: $activityPath)
            }
        }
    }

    // MARK: - You tab
    private var youStack: some View {
        // You tab has no drill-down destinations today — still wrap in a
        // NavigationStack so future settings screens can push onto it.
        NavigationStack {
            YouTabView()
        }
    }

    // MARK: - Shared destination builder
    @ViewBuilder
    private func destination(
        _ route: WorkspaceRoute,
        path: Binding<[WorkspaceRoute]>
    ) -> some View {
        switch route {
        case .channel(let id):
            ChannelView(
                channelID: id,
                conversationRepo: conversationRepo,
                messageRepo: messageRepo,
                realtimeRepo: realtimeRepo,
                onOpenThread: { path.wrappedValue.append(.thread($0)) }
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
                onClose: {
                    if !path.wrappedValue.isEmpty {
                        path.wrappedValue.removeLast()
                    }
                }
            )
        }
    }
}
