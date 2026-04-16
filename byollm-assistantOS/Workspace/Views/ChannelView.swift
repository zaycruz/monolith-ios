//
//  ChannelView.swift
//  Workspace
//
//  Screen 02 — channel conversation view.
//  v0.3 layout:
//  - GlassNavBar with back, title (#name), subtitle (member + agent count)
//  - Members stack bar (small avatars)
//  - DayMark separator
//  - MessageRows
//  - Typing indicator
//  - Glass composer
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
    var onBack: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    init(
        channelID: ChannelID,
        conversationRepo: ConversationRepository,
        messageRepo: MessageRepository,
        realtimeRepo: RealtimeRepository,
        onOpenThread: ((ThreadID) -> Void)? = nil,
        onBack: (() -> Void)? = nil
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
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            memberStackBar
            messagesList
            ComposerView(
                text: $viewModel.composerText,
                placeholder: "Message #\(viewModel.channel?.name ?? "")",
                onSend: { Task { await viewModel.send() } }
            )
        }
        .background(MonolithTheme.Colors.bgBase.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .task { await viewModel.load() }
        .task { await viewModel.subscribe() }
    }

    private var navBar: some View {
        GlassNavBar(
            leading: {
                GlassNavBackButton(onTap: {
                    if let onBack = onBack { onBack() }
                    else { dismiss() }
                })
            },
            title: {
                GlassNavTitle(
                    title: "#\(viewModel.channel?.name ?? "")",
                    subtitle: subtitle
                )
            },
            trailing: {
                HStack(spacing: 12) {
                    navIconButton("magnifyingglass", label: "Search")
                    navIconButton("info.circle", label: "Info")
                }
            }
        )
    }

    private func navIconButton(_ systemImage: String, label: String) -> some View {
        Button(action: {}) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(MonolithTheme.Colors.textSecondary)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var subtitle: String {
        let count = viewModel.channel?.memberCount ?? 0
        let agents = estimatedAgentCount()
        return "\(count) members · \(agents) agents"
    }

    /// Cheap heuristic for mock fixtures: count unique agent authors in
    /// the loaded messages and fall back to "1 agent" if empty.
    private func estimatedAgentCount() -> Int {
        let set = Set(viewModel.messages.compactMap { msg -> String? in
            if case .agent(let a) = msg.author.kind { return a.handle }
            return nil
        })
        return max(1, set.count)
    }

    // MARK: members stack bar — small avatars with presence
    private var memberStackBar: some View {
        HStack(spacing: -8) {
            ForEach(Array(stackMembers.prefix(6))) { member in
                MemberAvatarWithPresence(member: member, size: .sm, showPresence: false)
                    .overlay(
                        Circle().stroke(MonolithTheme.Palette.void, lineWidth: 1.5)
                            .opacity(member.isAgent ? 0 : 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: MonolithTheme.AvatarSize.sm.agentCornerRadius)
                            .stroke(MonolithTheme.Palette.void, lineWidth: 1.5)
                            .opacity(member.isAgent ? 1 : 0)
                    )
            }
            Spacer()
            Text("\(viewModel.channel?.memberCount ?? 0)")
                .font(MonolithFont.sans(size: 12))
                .foregroundColor(MonolithTheme.Colors.textTertiary)
        }
        .padding(.horizontal, MonolithTheme.Spacing.xl)
        .padding(.vertical, MonolithTheme.Spacing.sm)
    }

    /// Stack members = authors of the first N messages deduplicated.
    private var stackMembers: [Member] {
        var seen = Set<String>()
        var result: [Member] = []
        for msg in viewModel.messages {
            if !seen.contains(msg.author.id) {
                result.append(msg.author)
                seen.insert(msg.author.id)
            }
            if result.count >= 6 { break }
        }
        return result
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
                WorkspaceTypingIndicator(name: "dispatch")
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
