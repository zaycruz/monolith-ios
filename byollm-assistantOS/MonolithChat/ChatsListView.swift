//
//  ChatsListView.swift
//  byollm-assistantOS
//
//  Chats list — search + grouped by date.
//

import SwiftUI

struct ChatsListView: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode

    var body: some View {
        VStack(spacing: 0) {
            SettingsNavBar(title: "Chats", mode: mode, onBack: { store.closeChats() }, trailing: AnyView(
                Button(action: { store.newChat() }) {
                    Image(systemName: ChatIcon.new)
                        .font(.system(size: 21))
                        .foregroundColor(ChatTheme.text(mode))
                        .frame(width: 44, height: 44)
                }.buttonStyle(.touch)
            ))

            // Search
            HStack(spacing: 8) {
                Image(systemName: ChatIcon.search)
                    .font(.system(size: 15))
                    .foregroundColor(ChatTheme.sub(mode))
                TextField("Search your chats", text: $store.chatQuery)
                    .font(ChatFont.sans(.callout))
                    .foregroundColor(ChatTheme.text(mode))
                    .submitLabel(.search)
                    .textInputAutocapitalization(.never)
                if !store.chatQuery.isEmpty {
                    Button(action: { store.chatQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ChatTheme.sub(mode))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(ChatTheme.surface(mode))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(ChatTheme.line(mode), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .frame(maxWidth: 700)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(store.filteredChatGroups, id: \.label) { group in
                        Text(group.label.uppercased())
                            .font(ChatFont.sans(.caption, weight: .bold))
                            .tracking(1)
                            .foregroundColor(ChatTheme.sub(mode))
                            .padding(.horizontal, 2)
                            .padding(.top, 12)
                            .padding(.bottom, 6)
                        ForEach(group.items) { c in
                            let isGenerating = store.isGenerating(chatID: c.id)
                            let isReady = store.isChatReadyForAttention(chatID: c.id)

                            Button(action: { store.openChat(c.id) }) {
                                HStack(spacing: 12) {
                                    Image(systemName: ChatIcon.chat)
                                        .font(.system(size: 17))
                                        .foregroundColor(ChatTheme.sub(mode))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.title)
                                            .font(ChatFont.sans(.callout, weight: .semibold))
                                            .foregroundColor(ChatTheme.text(mode))
                                            .lineLimit(1)
                                        Text(c.time)
                                            .font(ChatFont.sans(.caption))
                                            .foregroundColor(ChatTheme.sub(mode))
                                    }
                                    Spacer()
                                    if isGenerating {
                                        ConversationActivityIndicator(state: .working, mode: mode)
                                    } else if isReady {
                                        ConversationActivityIndicator(state: .ready, mode: mode)
                                    } else {
                                        Image(systemName: ChatIcon.chevronRight)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(ChatTheme.sub(mode))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 13)
                                .background(c.id == store.activeChatId ? ChatTheme.surface(mode) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.touch)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(c.title)
                            .accessibilityValue(isGenerating ? "Working" : isReady ? "Ready" : c.time)
                        }
                    }

                    if !store.chatQuery.trimmingCharacters(in: .whitespaces).isEmpty && store.filteredChatGroups.isEmpty {
                        ContentUnavailableView.search(text: store.chatQuery)
                            .padding(.top, 40)
                    } else if store.filteredChatGroups.isEmpty {
                        ContentUnavailableView(
                            "No chats yet",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("Start a new chat and it will appear here.")
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: 700)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}
