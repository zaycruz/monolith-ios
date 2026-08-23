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

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                // Search
                HStack(spacing: 8) {
                    Image(systemName: ChatIcon.search)
                        .font(.system(size: 15))
                        .foregroundColor(ChatTheme.sub(mode))
                    Text("Search chats")
                        .font(ChatFont.sans(13))
                        .foregroundColor(ChatTheme.sub(mode))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(ChatTheme.surface(mode))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(ChatTheme.line(mode), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

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
                        ForEach(store.chats) { c in
                            Button(action: { store.openChatFromDrawer(c.id) }) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(c.title)
                                        .font(ChatFont.sans(13.5, weight: .semibold))
                                        .foregroundColor(ChatTheme.text(mode))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    Text(c.time)
                                        .font(ChatFont.sans(11))
                                        .foregroundColor(ChatTheme.sub(mode))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 11)
                                .background(c.id == store.activeChatId ? ChatTheme.surface(mode) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }

                // Bottom: server + settings
                VStack(spacing: 0) {
                    Button(action: { store.openSettingsFromDrawer() }) {
                        HStack(spacing: 10) {
                            StatusDot(status: store.activeServer?.status ?? .unknown)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.activeServer?.name ?? "No server")
                                    .font(ChatFont.sans(12.5, weight: .bold))
                                    .foregroundColor(ChatTheme.text(mode))
                                    .lineLimit(1)
                                Text(store.activeServer?.url ?? "")
                                    .font(ChatFont.mono(10.5))
                                    .foregroundColor(ChatTheme.sub(mode))
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    }
                    .buttonStyle(.plain)

                    Button(action: { store.openSettingsFromDrawer() }) {
                        HStack(spacing: 10) {
                            Image(systemName: ChatIcon.settings)
                                .font(.system(size: 19))
                                .foregroundColor(ChatTheme.text(mode).opacity(0.7))
                            Text("Settings")
                                .font(ChatFont.sans(13.5, weight: .bold))
                                .foregroundColor(ChatTheme.text(mode))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 14)
                    }
                    .buttonStyle(.plain)
                }
                .overlay(Rectangle().frame(height: 1).foregroundColor(ChatTheme.line(mode)), alignment: .top)
            }
            .frame(width: min(UIScreen.main.bounds.width * 0.82, 330))
            .background(ChatTheme.bg(mode))
            .overlay(Rectangle().frame(width: 1).foregroundColor(ChatTheme.line(mode)), alignment: .trailing)
            .shadow(color: Color.black.opacity(0.18), radius: 16, x: 8, y: 0)

            Button(action: { store.closeDrawer() }) {
                ChatTheme.scrim(mode)
            }
            .buttonStyle(.plain)
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
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
