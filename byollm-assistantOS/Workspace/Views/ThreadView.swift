//
//  ThreadView.swift
//  Workspace
//
//  Screen 04 — parent message + replies in a thread. Replies render as
//  MessageRow just like channels.
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
            header
            if let thread = viewModel.thread {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        MessageRow(message: thread.parent)
                        replyDivider(count: thread.summary.replyCount)
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
        .task { await viewModel.load() }
    }

    private var header: some View {
        HStack {
            Text("THREAD")
                .font(MonolithFont.mono(size: 11, weight: .medium))
                .tracking(0.6)
                .foregroundColor(MonolithTheme.Colors.textTertiary)
            Spacer()
            Button(action: { onClose?() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(MonolithTheme.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close thread")
        }
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.vertical, MonolithTheme.Spacing.md)
        .background(MonolithTheme.Colors.bgSurface)
        .overlay(
            Rectangle().fill(MonolithTheme.Colors.borderSoft).frame(height: 1),
            alignment: .bottom
        )
    }

    private func replyDivider(count: Int) -> some View {
        HStack(spacing: MonolithTheme.Spacing.md) {
            Rectangle().fill(MonolithTheme.Colors.borderSoft).frame(height: 1)
            Text("\(count) \(count == 1 ? "REPLY" : "REPLIES")")
                .font(MonolithFont.mono(size: 10, weight: .medium))
                .tracking(0.6)
                .foregroundColor(MonolithTheme.Colors.textTertiary)
            Rectangle().fill(MonolithTheme.Colors.borderSoft).frame(height: 1)
        }
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.vertical, MonolithTheme.Spacing.md)
    }
}

#Preview("ThreadView — triage thread") {
    ThreadView(
        threadID: MockThreads.clientOpsTriageThread.id,
        conversationRepo: MockConversationRepository()
    )
}
