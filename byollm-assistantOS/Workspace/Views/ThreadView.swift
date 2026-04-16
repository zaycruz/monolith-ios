//
//  ThreadView.swift
//  Workspace
//
//  Screen 05 — parent message + replies in a thread. v0.3 layout:
//  - GlassNavBar with back, title "Thread", subtitle "3 replies · 2 agents"
//  - Parent block pinned at top: grey bg (white @ 2%), header line
//    "Parent — from #channel · 8:42 AM", then the MessageRow itself
//  - Reply divider with agent-avatar stamp ("scout joined thread")
//  - Reply rows as MessageRows, supporting multi-agent participation
//  - Glass composer "Reply in thread…"
//

import SwiftUI

@MainActor
final class ThreadViewModel: ObservableObject {
    @Published var thread: MessageThread?
    @Published var composerText: String = ""
    @Published var errorMessage: String?

    let threadID: ThreadID
    private let conversationRepo: ConversationRepository

    init(threadID: ThreadID, conversationRepo: ConversationRepository) {
        self.threadID = threadID
        self.conversationRepo = conversationRepo
    }

    func load() async {
        do {
            self.thread = try await conversationRepo.loadThread(threadID)
        } catch {
            self.errorMessage = "\(error)"
        }
    }
}

struct ThreadView: View {
    @StateObject private var viewModel: ThreadViewModel
    var onClose: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    init(
        threadID: ThreadID,
        conversationRepo: ConversationRepository,
        onClose: (() -> Void)? = nil
    ) {
        self._viewModel = StateObject(
            wrappedValue: ThreadViewModel(
                threadID: threadID,
                conversationRepo: conversationRepo
            )
        )
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            if let thread = viewModel.thread {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        parentBlock(thread)
                        joinDivider(for: thread)
                        ForEach(thread.replies) { reply in
                            MessageRow(message: reply)
                        }
                    }
                    .padding(.bottom, MonolithTheme.Spacing.md)
                }
            } else if let err = viewModel.errorMessage {
                Text(err)
                    .foregroundColor(MonolithTheme.Colors.statusError)
                    .padding()
            } else {
                Spacer()
            }
            ComposerView(
                text: $viewModel.composerText,
                placeholder: "Reply in thread…"
            )
        }
        .background(MonolithTheme.Colors.bgBase.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .task { await viewModel.load() }
    }

    private var navBar: some View {
        GlassNavBar(
            leading: {
                GlassNavBackButton(onTap: {
                    if let onClose = onClose { onClose() }
                    else { dismiss() }
                })
            },
            title: {
                GlassNavTitle(
                    title: "Thread",
                    subtitle: subtitleText
                )
            }
        )
    }

    private var subtitleText: String {
        guard let thread = viewModel.thread else { return "" }
        let replies = thread.summary.replyCount
        let agentCount = Set(thread.replies.compactMap { msg -> String? in
            if case .agent(let a) = msg.author.kind { return a.handle }
            return nil
        }).count
        let replyLabel = replies == 1 ? "1 reply" : "\(replies) replies"
        let agentLabel = agentCount == 1 ? "1 agent" : "\(agentCount) agents"
        return "\(replyLabel) · \(agentLabel)"
    }

    // MARK: parent block — grey pinned block at top
    private func parentBlock(_ thread: MessageThread) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(parentHeaderLabel(for: thread.parent))
                .font(MonolithFont.sans(size: 12, weight: .medium))
                .foregroundColor(MonolithTheme.Colors.textTertiary)
                .padding(.horizontal, MonolithTheme.Spacing.xl)
                .padding(.top, MonolithTheme.Spacing.md)
                .padding(.bottom, MonolithTheme.Spacing.xs)
            MessageRow(message: thread.parent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.02))
        .overlay(
            Rectangle()
                .fill(MonolithTheme.Glass.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func parentHeaderLabel(for message: WorkspaceMessage) -> String {
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        df.amSymbol = "AM"
        df.pmSymbol = "PM"
        let time = df.string(from: message.timestamp)
        return "Parent — from #client-ops · \(time)"
    }

    // MARK: reply join divider
    /// "3 REPLIES" style divider in v0.2 → v0.3 includes an agent-avatar
    /// stamp for multi-agent participation (e.g. "scout joined thread").
    private func joinDivider(for thread: MessageThread) -> some View {
        HStack(spacing: MonolithTheme.Spacing.sm) {
            Rectangle().fill(MonolithTheme.Glass.border).frame(height: 1)
            HStack(spacing: 6) {
                joinAvatar(for: thread)
                Text(joinLabel(for: thread))
                    .font(MonolithFont.sans(size: 12, weight: .medium))
                    .foregroundColor(MonolithTheme.Colors.textTertiary)
            }
            Rectangle().fill(MonolithTheme.Glass.border).frame(height: 1)
        }
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.vertical, MonolithTheme.Spacing.md)
    }

    @ViewBuilder
    private func joinAvatar(for thread: MessageThread) -> some View {
        // Use the first non-parent-author agent reply as the "joined" stamp.
        let parentAuthorID = thread.parent.author.id
        let joiner = thread.replies.first { $0.author.id != parentAuthorID }?.author
            ?? thread.parent.author
        switch joiner.kind {
        case .human(let h): HumanAvatar(human: h, size: .xs)
        case .agent(let a): AgentAvatar(agent: a, size: .xs)
        }
    }

    private func joinLabel(for thread: MessageThread) -> String {
        let count = thread.summary.replyCount
        return count == 1 ? "1 reply" : "\(count) replies"
    }
}

#Preview("ThreadView — triage thread") {
    ThreadView(
        threadID: MockThreads.clientOpsTriageThread.id,
        conversationRepo: MockConversationRepository()
    )
}
