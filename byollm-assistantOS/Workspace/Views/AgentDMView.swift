//
//  AgentDMView.swift
//  Workspace
//
//  Screen 03 — 1:1 DM with an agent. v0.3 layout:
//  - GlassNavBar with back, avatar + title (agent handle in JBM) +
//    subtitle (running · m8g.medium · 128h uptime)
//  - DayMark + MessageRows (with multi-tool stacking supported by the
//    existing WorkspaceMessage.toolCalls: [ToolCall])
//  - Glass composer without @ mention button (it's 1:1, no @ needed)
//

import SwiftUI

@MainActor
final class AgentDMViewModel: ObservableObject {
    @Published var dm: DirectMessage?
    @Published var messages: [WorkspaceMessage] = []
    @Published var composerText: String = ""
    @Published var errorMessage: String?

    let dmID: DMID
    private let conversationRepo: ConversationRepository
    private let messageRepo: MessageRepository

    init(
        dmID: DMID,
        conversationRepo: ConversationRepository,
        messageRepo: MessageRepository
    ) {
        self.dmID = dmID
        self.conversationRepo = conversationRepo
        self.messageRepo = messageRepo
    }

    func load() async {
        do {
            self.dm = try await conversationRepo.loadDM(dmID)
            self.messages = try await messageRepo.loadDMMessages(dmID: dmID)
        } catch {
            self.errorMessage = "\(error)"
        }
    }
}

struct AgentDMView: View {
    @StateObject private var viewModel: AgentDMViewModel
    var onOpenAgent: ((AgentID) -> Void)?
    var onBack: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    init(
        dmID: DMID,
        conversationRepo: ConversationRepository,
        messageRepo: MessageRepository,
        onOpenAgent: ((AgentID) -> Void)? = nil,
        onBack: (() -> Void)? = nil
    ) {
        self._viewModel = StateObject(
            wrappedValue: AgentDMViewModel(
                dmID: dmID,
                conversationRepo: conversationRepo,
                messageRepo: messageRepo
            )
        )
        self.onOpenAgent = onOpenAgent
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            messagesList
            ComposerView(
                text: $viewModel.composerText,
                placeholder: composerPlaceholder,
                showMentionButton: false
            )
        }
        .background(MonolithTheme.Colors.bgBase.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .task { await viewModel.load() }
    }

    // MARK: nav
    private var navBar: some View {
        GlassNavBar(
            leading: {
                GlassNavBackButton(onTap: {
                    if let onBack = onBack { onBack() }
                    else { dismiss() }
                })
            },
            title: { titleContent },
            trailing: {
                if case .agent(let a) = viewModel.dm?.counterpart.kind {
                    Button(action: { onOpenAgent?(a.id) }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(MonolithTheme.Colors.textSecondary)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Agent info")
                }
            }
        )
    }

    @ViewBuilder
    private var titleContent: some View {
        HStack(spacing: MonolithTheme.Spacing.sm) {
            counterpartAvatar
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.dm?.counterpart.displayName ?? "")
                    .font(counterpartIsAgent
                          ? MonolithFont.mono(size: 17, weight: .semibold)
                          : MonolithFont.sans(size: 17, weight: .semibold))
                    .foregroundColor(MonolithTheme.Colors.textPrimary)
                    .lineLimit(1)
                if counterpartIsAgent,
                   case .agent(let a) = viewModel.dm?.counterpart.kind {
                    Text(statusSubtitle(for: a))
                        .font(MonolithFont.mono(size: 11))
                        .foregroundColor(MonolithTheme.Colors.textTertiary)
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private var counterpartAvatar: some View {
        switch viewModel.dm?.counterpart.kind {
        case .human(let h):
            AvatarWithPresence(human: h, size: .md)
        case .agent(let a):
            AvatarWithPresence(agent: a, size: .md)
        case .none:
            Color.clear.frame(width: 28, height: 28)
        }
    }

    private var counterpartIsAgent: Bool {
        viewModel.dm?.counterpart.isAgent ?? false
    }

    private var composerPlaceholder: String {
        if let name = viewModel.dm?.counterpart.displayName {
            return "Message @\(name)"
        }
        return "Message…"
    }

    private func statusSubtitle(for agent: Agent) -> String {
        switch agent.status {
        case .running:
            let size = agent.instanceSize ?? "m8g.medium"
            let uptime = agent.uptimeSeconds.map { formatUptime($0) } ?? "—"
            return "running · \(size) · \(uptime)"
        case .idle:  return "idle · standby"
        case .error: return "error · check logs"
        }
    }

    private func formatUptime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return "\(h)h\(m > 0 ? " \(m)m" : "")"
    }

    // MARK: body list
    private var messagesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !viewModel.messages.isEmpty {
                    DayMark(date: viewModel.messages[0].timestamp)
                        .padding(.horizontal, MonolithTheme.Spacing.lg)
                }
                ForEach(viewModel.messages) { msg in
                    MessageRow(message: msg) { _ in
                        // Threads not surfaced on DMs in v0.3.
                    } onToggleReaction: { _ in }
                }
            }
            .padding(.bottom, MonolithTheme.Spacing.md)
        }
    }
}

#Preview("AgentDMView — Zay × dispatch") {
    AgentDMView(
        dmID: MockDMs.zayDispatch.id,
        conversationRepo: MockConversationRepository(),
        messageRepo: MockMessageRepository()
    )
}
