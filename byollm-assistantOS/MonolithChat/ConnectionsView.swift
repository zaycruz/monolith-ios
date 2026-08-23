//
//  ConnectionsView.swift
//  byollm-assistantOS
//
//  Connections screen + Add-connection bottom sheet.
//

import SwiftUI

struct ConnectionsView: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode

    var body: some View {
        VStack(spacing: 0) {
            SettingsNavBar(title: "Connections", mode: mode, onBack: { store.closeConnections() }, trailing: AnyView(
                Button(action: { store.openAddConn() }) {
                    Image(systemName: ChatIcon.plus)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(ChatTheme.text(mode))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            ))

            ScrollView {
                VStack(spacing: 10) {
                    let connected = store.connections.filter { $0.connected }
                    if connected.isEmpty {
                        VStack(spacing: 6) {
                            Text("No connections yet")
                                .font(ChatFont.sans(14, weight: .bold))
                                .foregroundColor(ChatTheme.text(mode))
                            Text("Tap + to connect an app. Connected apps are available as tools to the model in every chat.")
                                .font(ChatFont.sans(12.5))
                                .lineSpacing(4)
                                .foregroundColor(ChatTheme.sub(mode))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 48)
                    } else {
                        ForEach(connected) { cn in
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(ChatTheme.surface(mode))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ChatTheme.line(mode), lineWidth: 1))
                                    Text(cn.initial)
                                        .font(ChatFont.sans(13, weight: .bold))
                                        .foregroundColor(ChatTheme.text(mode))
                                }
                                .frame(width: 34, height: 34)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(cn.name)
                                        .font(ChatFont.sans(14, weight: .bold))
                                        .foregroundColor(ChatTheme.text(mode))
                                    HStack(spacing: 6) {
                                        Circle().fill(ChatTheme.online).frame(width: 6, height: 6)
                                        Text("Connected · \(cn.account)")
                                            .font(ChatFont.sans(11.5))
                                            .foregroundColor(ChatTheme.sub(mode))
                                    }
                                }
                                Spacer()
                                Button(action: { store.toggleConnection(cn.id) }) {
                                    Text("Disconnect")
                                        .font(ChatFont.sans(12, weight: .bold))
                                        .foregroundColor(ChatTheme.sub(mode))
                                        .padding(.horizontal, 13)
                                        .padding(.vertical, 7)
                                        .overlay(Capsule().stroke(ChatTheme.line2(mode), lineWidth: 1))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 13)
                            .background(ChatTheme.card(mode))
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(ChatTheme.line2(mode), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Add connection sheet
struct AddConnectionSheet: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(ChatTheme.line2(mode)).frame(width: 36, height: 4)
                .padding(.bottom, 14)

            Text("Add a connection")
                .font(ChatFont.sans(16, weight: .bold))
                .tracking(-0.4)
                .foregroundColor(ChatTheme.text(mode))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("The model can read from and act on connected apps.")
                .font(ChatFont.sans(12))
                .foregroundColor(ChatTheme.sub(mode))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)

            let available = store.connections.filter { !$0.connected }
            VStack(spacing: 6) {
                if available.isEmpty {
                    Text("All available apps are connected.")
                        .font(ChatFont.sans(12.5))
                        .foregroundColor(ChatTheme.sub(mode))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    ForEach(available) { av in
                        Button(action: { store.toggleConnection(av.id); store.closeAddConn() }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(ChatTheme.surface(mode))
                                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(ChatTheme.line(mode), lineWidth: 1))
                                    Text(av.initial)
                                        .font(ChatFont.sans(12.5, weight: .bold))
                                        .foregroundColor(ChatTheme.text(mode))
                                }
                                .frame(width: 32, height: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(av.name)
                                        .font(ChatFont.sans(14, weight: .bold))
                                        .foregroundColor(ChatTheme.text(mode))
                                    Text(av.desc)
                                        .font(ChatFont.sans(11.5))
                                        .foregroundColor(ChatTheme.sub(mode))
                                }
                                Spacer()
                                Text("Connect")
                                    .font(ChatFont.sans(12, weight: .bold))
                                    .foregroundColor(ChatTheme.text(mode))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .background(ChatTheme.card(mode))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ChatTheme.line2(mode), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 28)
        .background(ChatTheme.bg(mode))
        .clipShape(RoundedCorner(radius: 22, corners: [.topLeft, .topRight]))
        .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: -8)
    }
}
