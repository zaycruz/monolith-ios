//
//  AgentDMView.swift
//  Workspace
//
//  Screen 03 — 1:1 DM with an agent. Same layout language as ChannelView
//  but header shows the agent's avatar + AGENT tag + status.
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

    init(
        dmID: DMID,
        conversationRepo: ConversationRepository,
        messageRepo: MessageRepository,
        onOpenAgent: ((AgentID) -> Void)? = nil
    ) {
        self._viewModel = StateObject(
            wrappedValue: AgentDMViewModel(
                dmID: dmID,
                conversationRepo: conversationRepo,
                messageRepo: messageRepo
            )
        )
        self.onOpenAgent = onOpenAgent
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            messagesList
            ComposerView(
                text: $viewModel.composerText,
                placeholder: composerPlaceholder
            )
        }
        .background(MonolithTheme.Colors.bgBase.ignoresSafeArea())
        .task { await viewModel.load() }
    }

    // MARK: header
    private var header: some View {
        HStack(spacing: MonolithTheme.Spacing.md) {
            counterpartAvatar
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(viewModel.dm?.counterpart.displayName ?? "")
                        .font(counterpartIsAgent
                              ? MonolithFont.mono(size: 14, weight: .medium)
                              : MonolithFont.sans(size: 15, weight: .bold))
                        .foregroundColor(MonolithTheme.Colors.textPrimary)
                    if counterpartIsAgent {
                        Text("AGENT")
                            .font(MonolithFont.mono(size: 9, weight: .medium))
                            .tracking(0.6)
                            .foregroundColor(MonolithTheme.Colors.textTertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: MonolithTheme.Radius.sm)
                                    .stroke(MonolithTheme.Colors.borderStrong, lineWidth: 1)
                            )
                    }
                }
                if counterpartIsAgent, case .agent(let a) = viewModel.dm?.counterpart.kind {
                    Text(statusLabel(for: a.status))
                        .font(MonolithFont.mono(size: 10))
                        .foregroundColor(MonolithTheme.Colors.textTertiary)
                }
            }
            Spacer()
            if case .agent(let a) = viewModel.dm?.counterpart.kind {
                Button(action: { onOpenAgent?(a.id) }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(MonolithTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.vertical, MonolithTheme.Spacing.md)
        .background(MonolithTheme.Colors.bgSurface)
        .overlay(
            Rectangle().fill(MonolithTheme.Colors.borderSoft).frame(height: 1),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private var counterpartAvatar: some View {
        switch viewModel.dm?.counterpart.kind {
        case .human(let h): HumanAvatar(human: h, size: .lg)
        case .agent(let a): AgentAvatar(agent: a, size: .lg)
        case .none:         Color.clear.frame(width: 32, height: 32)
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

    private func statusLabel(for status: AgentStatus) -> String {
        switch status {
        case .running: return "running · m8g.medium"
        case .idle:    return "idle"
        case .error:   return "error"
        }
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
                    MessageRow(message: msg)
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
