//
//  SettingsView.swift
//  byollm-assistantOS
//
//  Settings — appearance, model, connections, vLLM servers, about.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode

    var body: some View {
        VStack(spacing: 0) {
            SettingsNavBar(title: "Settings", mode: mode, onBack: { store.closeSettings() })

            ScrollView {
                VStack(spacing: 22) {
                    // Appearance
                    SettingsSection(title: "Appearance", mode: mode) {
                        HStack(spacing: 0) {
                            SegmentButton(label: "Light", selected: !store.isDark, mode: mode) { store.isDark = false }
                            SegmentButton(label: "Dark", selected: store.isDark, mode: mode) { store.isDark = true }
                        }
                        .padding(3)
                        .background(ChatTheme.surface(mode))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ChatTheme.line(mode), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Model
                    SettingsSection(title: "Model", mode: mode) {
                        Button(action: { store.openSheet() }) {
                            SettingsCardRow(title: store.activeModelShort, subtitle: store.models.first(where: { $0.name == store.activeModel })?.meta ?? "", mode: mode)
                        }
                        .buttonStyle(.plain)
                    }

                    // Connections
                    SettingsSection(title: "Connections", mode: mode) {
                        Button(action: { store.openConnections() }) {
                            SettingsCardRow(title: "Connected apps", subtitle: store.connSummary, mode: mode)
                        }
                        .buttonStyle(.plain)
                    }

                    // vLLM servers
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("VLLM SERVERS")
                                .font(ChatFont.sans(11.5, weight: .bold))
                                .tracking(1)
                                .foregroundColor(ChatTheme.sub(mode))
                            Spacer()
                            Button(action: { store.toggleAddServer() }) {
                                Text(store.addOpen ? "Cancel" : "+ Add server")
                                    .font(ChatFont.sans(12, weight: .bold))
                                    .foregroundColor(ChatTheme.text(mode))
                            }
                            .buttonStyle(.plain)
                        }

                        ForEach(store.servers) { s in
                            ServerCard(server: s, mode: mode, store: store)
                        }

                        if store.addOpen {
                            AddServerForm(store: store, mode: mode)
                        }
                    }

                    // About
                    SettingsSection(title: "About", mode: mode) {
                        VStack(spacing: 0) {
                            AboutRow(label: "Version", value: "1.0.0 (42)", mode: mode)
                            Divider().background(ChatTheme.line(mode))
                            AboutRow(label: "Privacy", value: "On-device only", mode: mode)
                        }
                        .background(ChatTheme.card(mode))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(ChatTheme.line2(mode), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Nav bar
struct SettingsNavBar: View {
    var title: String
    var mode: ChatTheme.Mode
    var onBack: () -> Void
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onBack) {
                Image(systemName: ChatIcon.back)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(ChatTheme.text(mode))
                    .frame(width: 44, height: 44)
                    .padding(.leading, 4)
            }
            .buttonStyle(.plain)
            Text(title)
                .font(ChatFont.sans(17, weight: .bold))
                .tracking(-0.4)
                .foregroundColor(ChatTheme.text(mode))
            Spacer()
            if let trailing = trailing { trailing }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Section wrapper
struct SettingsSection<Content: View>: View {
    var title: String
    var mode: ChatTheme.Mode
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(ChatFont.sans(11.5, weight: .bold))
                .tracking(1)
                .foregroundColor(ChatTheme.sub(mode))
            content
        }
    }
}

// MARK: - Card row with chevron
struct SettingsCardRow: View {
    var title: String
    var subtitle: String
    var mode: ChatTheme.Mode

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ChatFont.sans(14, weight: .bold))
                    .foregroundColor(ChatTheme.text(mode))
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(ChatFont.sans(11.5))
                        .foregroundColor(ChatTheme.sub(mode))
                }
            }
            Spacer()
            Image(systemName: ChatIcon.chevronRight)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(ChatTheme.sub(mode))
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .background(ChatTheme.card(mode))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(ChatTheme.line2(mode), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }
}

// MARK: - Appearance segment button
struct SegmentButton: View {
    var label: String
    var selected: Bool
    var mode: ChatTheme.Mode
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(ChatFont.sans(13, weight: .bold))
                .foregroundColor(selected ? ChatTheme.text(mode) : ChatTheme.sub(mode))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(selected ? ChatTheme.card(mode) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .shadow(color: selected ? Color.black.opacity(0.12) : .clear, radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Server card
struct ServerCard: View {
    var server: LLMServer
    var mode: ChatTheme.Mode
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(spacing: 10) {
            Button(action: { store.selectServer(server.id) }) {
                HStack(spacing: 11) {
                    ZStack {
                        Circle().stroke(server.active ? ChatTheme.text(mode) : ChatTheme.line2(mode), lineWidth: 2)
                            .frame(width: 18, height: 18)
                        if server.active {
                            Circle().fill(ChatTheme.text(mode)).frame(width: 9, height: 9)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.name)
                            .font(ChatFont.sans(14, weight: .bold))
                            .foregroundColor(ChatTheme.text(mode))
                        Text(server.url)
                            .font(ChatFont.mono(11.5))
                            .foregroundColor(ChatTheme.sub(mode))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            HStack {
                HStack(spacing: 7) {
                    StatusDot(status: server.status, size: 7)
                    Text(server.status.label)
                        .font(ChatFont.sans(12, weight: .semibold))
                        .foregroundColor(server.status.dotColor)
                }
                Spacer()
                Button(action: { store.testServer(server.id) }) {
                    Text("Test connection")
                        .font(ChatFont.sans(12, weight: .bold))
                        .foregroundColor(ChatTheme.text(mode))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .overlay(Capsule().stroke(ChatTheme.line2(mode), lineWidth: 1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
            .overlay(Rectangle().frame(height: 1).foregroundColor(ChatTheme.line(mode)), alignment: .top)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(ChatTheme.card(mode))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(server.active ? ChatTheme.text(mode) : ChatTheme.line2(mode), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }
}

// MARK: - Add server form
struct AddServerForm: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("New server")
                .font(ChatFont.sans(13, weight: .bold))
                .foregroundColor(ChatTheme.text(mode))

            TextField("Name (e.g. Homelab 4090)", text: $store.addName)
                .font(ChatFont.sans(13.5))
                .foregroundColor(ChatTheme.text(mode))
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(ChatTheme.card(mode))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(ChatTheme.line2(mode), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            TextField("http://192.168.1.42:8000/v1", text: $store.addUrl)
                .font(ChatFont.mono(13))
                .foregroundColor(ChatTheme.text(mode))
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(ChatTheme.card(mode))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(ChatTheme.line2(mode), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text("OpenAI-compatible base URL of your vLLM server, including /v1.")
                .font(ChatFont.sans(11))
                .foregroundColor(ChatTheme.sub(mode))

            if store.addStatus == .ok || store.addStatus == .fail {
                HStack(spacing: 7) {
                    Circle().fill(store.addStatus == .ok ? ChatTheme.online : ChatTheme.offline).frame(width: 7, height: 7)
                    Text(store.addStatus == .ok ? "Connection OK" : "Could not reach server")
                        .font(ChatFont.sans(12, weight: .bold))
                        .foregroundColor(store.addStatus == .ok ? ChatTheme.online : ChatTheme.offline)
                }
            }

            HStack(spacing: 8) {
                Button(action: { store.testAddServer() }) {
                    Text(store.addStatus == .testing ? "Testing…" : "Test connection")
                        .font(ChatFont.sans(13, weight: .bold))
                        .foregroundColor(ChatTheme.text(mode))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(ChatTheme.card(mode))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(ChatTheme.line2(mode), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)

                Button(action: { store.saveServer() }) {
                    Text("Save server")
                        .font(ChatFont.sans(13, weight: .bold))
                        .foregroundColor(store.canSaveServer ? ChatTheme.bg(mode) : ChatTheme.sub(mode))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(store.canSaveServer ? ChatTheme.text(mode) : ChatTheme.line2(mode))
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
                .disabled(!store.canSaveServer)
            }
        }
        .padding(15)
        .background(ChatTheme.surface(mode))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(style: StrokeStyle(lineWidth: 1, dash: [5])).foregroundColor(ChatTheme.line2(mode)))
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }
}

// MARK: - About row
struct AboutRow: View {
    var label: String
    var value: String
    var mode: ChatTheme.Mode

    var body: some View {
        HStack {
            Text(label)
                .font(ChatFont.sans(13.5, weight: .semibold))
                .foregroundColor(ChatTheme.text(mode))
            Spacer()
            Text(value)
                .font(ChatFont.sans(13.5))
                .foregroundColor(ChatTheme.sub(mode))
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
    }
}
