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
                    .font(ChatFont.sans(13.5))
                    .foregroundColor(ChatTheme.text(mode))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(ChatTheme.surface(mode))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(ChatTheme.line(mode), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(store.filteredChatGroups, id: \.label) { group in
                        Text(group.label.uppercased())
                            .font(ChatFont.sans(11, weight: .bold))
                            .tracking(1)
                            .foregroundColor(ChatTheme.sub(mode))
                            .padding(.horizontal, 2)
                            .padding(.top, 12)
                            .padding(.bottom, 6)
                        ForEach(group.items) { c in
                            Button(action: { store.openChat(c.id) }) {
                                HStack(spacing: 12) {
                                    Image(systemName: ChatIcon.chat)
                                        .font(.system(size: 17))
                                        .foregroundColor(ChatTheme.sub(mode))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.title)
                                            .font(ChatFont.sans(14, weight: .semibold))
                                            .foregroundColor(ChatTheme.text(mode))
                                            .lineLimit(1)
                                        Text(c.time)
                                            .font(ChatFont.sans(11.5))
                                            .foregroundColor(ChatTheme.sub(mode))
                                    }
                                    Spacer()
                                    Image(systemName: ChatIcon.chevronRight)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(ChatTheme.sub(mode))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 13)
                                .background(c.id == store.activeChatId ? ChatTheme.surface(mode) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.touch)
                        }
                    }

                    if !store.chatQuery.trimmingCharacters(in: .whitespaces).isEmpty && store.filteredChatGroups.isEmpty {
                        Text("No chats match \"\(store.chatQuery)\"")
                            .font(ChatFont.sans(13))
                            .foregroundColor(ChatTheme.sub(mode))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }
}
