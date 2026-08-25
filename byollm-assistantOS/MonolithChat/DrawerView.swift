//
//  DrawerView.swift
//  byollm-assistantOS
//
//  Slide-over history drawer — search, New chat / Chats / Projects,
//  Recents list, server status + Settings.
//

import SwiftUI
import UIKit

struct DrawerView: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode

    private var drawerChats: [Chat] {
        let query = store.chatQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return store.chats
        }
        return store.chats.filter { $0.title.localizedStandardContains(query) }
    }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                // Search
                HStack(spacing: 8) {
                    Image(systemName: ChatIcon.search)
                        .font(.system(size: 15))
                        .foregroundColor(ChatTheme.sub(mode))
                    TextField("Search chats", text: $store.chatQuery)
                        .font(ChatFont.sans(14))
                        .foregroundColor(ChatTheme.text(mode))
                        .submitLabel(.search)
                        .textInputAutocapitalization(.never)
                    if !store.chatQuery.isEmpty {
                        Button(action: { store.chatQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 17))
                                .foregroundColor(ChatTheme.sub(mode))
                        }
                        .buttonStyle(.touch)
                        .accessibilityLabel("Clear search")
                    }
                }
                .frame(minHeight: 48)
                .padding(.leading, 12)
                .padding(.trailing, 4)
                .monolithGlass(mode: mode, cornerRadius: 16, interactive: true)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)
                .accessibilityElement(children: .contain)

                // Nav
                VStack(spacing: 1) {
                    DrawerNavRow(icon: ChatIcon.new, label: "New chat", bold: true, mode: mode) { store.newChatFromDrawer() }
                    DrawerNavRow(icon: ChatIcon.chat, label: "Chats", bold: false, mode: mode) { store.openChats() }
                    DrawerNavRow(icon: ChatIcon.files, label: "Projects", bold: false, mode: mode) { store.openProjects() }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 6)

                // Recents
                Text("RECENTS")
                    .font(ChatFont.sans(11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(ChatTheme.sub(mode))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(drawerChats) { chat in
                            Button(action: { store.openChatFromDrawer(chat.id) }) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(chat.title)
                                        .font(ChatFont.sans(14, weight: .semibold))
                                        .foregroundColor(ChatTheme.text(mode))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    Text(chat.time)
                                        .font(ChatFont.sans(11.5))
                                        .foregroundColor(ChatTheme.sub(mode))
                                }
                                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                                .padding(.horizontal, 10)
                                .background(
                                    chat.id == store.activeChatId
                                        ? ChatTheme.surface(mode)
                                        : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                            }
                            .buttonStyle(.touch)
                        }

                        if drawerChats.isEmpty {
                            Text(
                                store.chatQuery.isEmpty
                                    ? "Your conversations will appear here."
                                    : "No chats match your search."
                            )
                            .font(ChatFont.sans(13))
                            .foregroundColor(ChatTheme.sub(mode))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 28)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .scrollDismissesKeyboard(.interactively)

                // Bottom: server and settings
                Button(action: { store.openSettingsFromDrawer() }) {
                    HStack(spacing: 11) {
                        StatusDot(status: store.activeServer?.status ?? .unknown)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.activeServer?.name ?? "Set up a server")
                                .font(ChatFont.sans(13.5, weight: .bold))
                                .foregroundColor(ChatTheme.text(mode))
                                .lineLimit(1)
                            Text(store.activeServer?.status.label ?? "No server configured")
                                .font(ChatFont.sans(11.5))
                                .foregroundColor(ChatTheme.sub(mode))
                        }
                        Spacer()
                        Image(systemName: ChatIcon.settings)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(ChatTheme.text(mode).opacity(0.72))
                    }
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.touch)
                .accessibilityLabel(
                    "Settings, \(store.activeServer?.name ?? "no server"), \(store.activeServer?.status.label ?? "not configured")"
                )
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(ChatTheme.line(mode)),
                    alignment: .top
                )
            }
                .frame(width: min(proxy.size.width * 0.86, 360))
                .background {
                    ZStack {
                        Rectangle().fill(.regularMaterial)
                        ChatTheme.bg(mode).opacity(mode == .dark ? 0.62 : 0.50)
                    }
                }
                .overlay(
                    Rectangle().frame(width: 0.5).foregroundColor(ChatTheme.glassLine(mode)),
                    alignment: .trailing
                )
                .shadow(color: Color.black.opacity(mode == .dark ? 0.34 : 0.16), radius: 24, x: 10, y: 0)

                Button(action: {
                    dismissAppKeyboard()
                    store.closeDrawer()
                }) {
                    ChatTheme.scrim(mode)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close navigation")
            }
        }
    }
}

struct DrawerNavRow: View {
    var icon: String
    var label: String
    var bold: Bool
    var mode: ChatTheme.Mode
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(ChatTheme.text(mode).opacity(bold ? 1 : 0.8))
                Text(label)
                    .font(ChatFont.sans(13.5, weight: bold ? .bold : .semibold))
                    .foregroundColor(ChatTheme.text(mode))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(minHeight: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.touch)
    }
}
