//
//  ChannelView.swift
//  Workspace
//
//  Screen 02 — channel conversation view. DayMark + MessageRows + Composer.
//

import SwiftUI

@MainActor
final class ChannelViewModel: ObservableObject {
    @Published var channel: Channel?
    @Published var messages: [WorkspaceMessage] = []
    @Published var composerText: String = ""
    @Published var errorMessage: String?

    let channelID: ChannelID
    private let conversationRepo: ConversationRepository
    private let messageRepo: MessageRepository
    private let realtimeRepo: RealtimeRepository

    init(
        channelID: ChannelID,
        conversationRepo: ConversationRepository,
        messageRepo: MessageRepository,
        realtimeRepo: RealtimeRepository
    ) {
        self.channelID = channelID
        self.conversationRepo = conversationRepo
        self.messageRepo = messageRepo
        self.realtimeRepo = realtimeRepo
    }

    func load() async {
        do {
            self.channel = try await conversationRepo.loadChannel(channelID)
            self.messages = try await messageRepo.loadMessages(channelID: channelID)
        } catch {
            self.errorMessage = "\(error)"
        }
    }

    func subscribe() async {
        for await event in realtimeRepo.events(forChannel: channelID) {
            switch event {
            case .messageCreated(let cid, let msg) where cid == channelID:
                self.messages.append(msg)
            default:
                break
            }
        }
    }

    func send() async {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        composerText = ""
        do {
            _ = try await messageRepo.sendMessage(
                channelID: channelID,
                text: text,
                idempotencyKey: UUID().uuidString
            )
        } catch {
            self.errorMessage = "\(error)"
        }
    }
}

struct ChannelView: View {
    @StateObject private var viewModel: ChannelViewModel
    var onOpenThread: ((ThreadID) -> Void)?

    init(
        channelID: ChannelID,
        conversationRepo: ConversationRepository,
        messageRepo: MessageRepository,
        realtimeRepo: RealtimeRepository,
        onOpenThread: ((ThreadID) -> Void)? = nil
    ) {
        self._viewModel = StateObject(
            wrappedValue: ChannelViewModel(
                channelID: channelID,
                conversationRepo: conversationRepo,
                messageRepo: messageRepo,
                realtimeRepo: realtimeRepo
            )
        )
        self.onOpenThread = onOpenThread
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            messagesList
            ComposerView(
                text: $viewModel.composerText,
                placeholder: "Message #\(viewModel.channel?.name ?? "")",
                onSend: { Task { await viewModel.send() } }
            )
        }
        .background(MonolithTheme.Colors.bgBase.ignoresSafeArea())
        .task { await viewModel.load() }
        .task { await viewModel.subscribe() }
    }

    private var header: some View {
        HStack(spacing: MonolithTheme.Spacing.sm) {
            Text("#")
                .font(MonolithFont.mono(size: 16, weight: .medium))
                .foregroundColor(MonolithTheme.Colors.textTertiary)
            Text(viewModel.channel?.name ?? "")
                .font(MonolithFont.sans(size: 16, weight: .bold))
                .foregroundColor(MonolithTheme.Colors.textPrimary)
            Spacer()
            if let count = viewModel.channel?.memberCount {
                Text("\(count)")
                    .font(MonolithFont.mono(size: 11))
                    .foregroundColor(MonolithTheme.Colors.textTertiary)
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

    private var messagesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !viewModel.messages.isEmpty {
                    DayMark(date: viewModel.messages[0].timestamp)
                        .padding(.horizontal, MonolithTheme.Spacing.lg)
                }
                ForEach(viewModel.messages) { msg in
                    MessageRow(message: msg, onOpenThread: onOpenThread)
                }
            }
            .padding(.bottom, MonolithTheme.Spacing.md)
        }
    }
}

#Preview("ChannelView — #client-ops") {
    let rt = MockRealtimeRepository()
    return ChannelView(
        channelID: MockChannels.clientOps.id,
        conversationRepo: MockConversationRepository(),
        messageRepo: MockMessageRepository(realtime: rt),
        realtimeRepo: rt
    )
}
