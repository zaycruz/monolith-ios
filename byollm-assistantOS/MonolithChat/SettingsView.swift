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

    private var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsNavBar(title: "Settings", mode: mode, onBack: { store.closeSettings() })

            ScrollView {
                VStack(spacing: 22) {
                    // Appearance
                    SettingsSection(title: "Appearance", mode: mode) {
                        Picker("Appearance", selection: $store.isDark) {
                            Label("Light", systemImage: "sun.max").tag(false)
                            Label("Dark", systemImage: "moon").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Appearance")
                    }

                    // Model
                    SettingsSection(title: "Model", mode: mode) {
                        Button(action: { store.openSheet() }) {
                            SettingsCardRow(title: store.activeModelShort, subtitle: store.models.first(where: { $0.name == store.activeModel })?.meta ?? "", mode: mode)
                        }.buttonStyle(.touch)
                    }

                    // Connections
                    SettingsSection(title: "Connections", mode: mode) {
                        Button(action: { store.openConnections() }) {
                            SettingsCardRow(title: "Connected apps", subtitle: store.connSummary, mode: mode)
                        }.buttonStyle(.touch)
                    }

                    // AI servers
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("AI SERVERS")
                                .font(ChatFont.sans(11.5, weight: .bold))
                                .tracking(1)
                                .foregroundColor(ChatTheme.sub(mode))
                            Spacer()
                            Button(
                                action: {
                                    if store.addOpen {
                                        store.cancelServerForm()
                                    } else {
                                        store.beginAddingServer()
                                    }
                                }
                            ) {
                                Text(store.addOpen ? "Cancel" : "Add server")
                                    .font(ChatFont.sans(13, weight: .bold))
                                    .foregroundColor(ChatTheme.text(mode))
                            }
                            .buttonStyle(.touch)
                            .accessibilityHint(
                                store.addOpen
                                    ? "Closes the server form"
                                    : "Opens the form to add a local AI server"
                            )
                        }

                        if store.servers.isEmpty, !store.addOpen {
                            Text("Add your local AI server to start chatting.")
                                .font(ChatFont.sans(13))
                                .foregroundColor(ChatTheme.sub(mode))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                        }

                        ForEach(store.servers) { server in
                            ServerCard(server: server, mode: mode, store: store)
                        }

                        if store.addOpen {
                            AddServerForm(store: store, mode: mode)
                        }
                    }

                    // About
                    SettingsSection(title: "About", mode: mode) {
                        VStack(spacing: 0) {
                            AboutRow(label: "Version", value: versionLabel, mode: mode)
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
                .frame(maxWidth: 700)
            }
            .scrollDismissesKeyboard(.interactively)
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
            }.buttonStyle(.touch)
            Text(title)
                .font(ChatFont.sans(17, weight: .bold))
                .tracking(-0.4)
                .foregroundColor(ChatTheme.text(mode))
            Spacer()
            if let trailing = trailing { trailing }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(ChatTheme.line(mode)),
            alignment: .bottom
        )
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
        .background(ChatTheme.card(mode).opacity(mode == .dark ? 0.78 : 0.86))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ChatTheme.line2(mode), lineWidth: 0.75)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Server card
struct ServerCard: View {
    var server: LLMServer
    var mode: ChatTheme.Mode
    @ObservedObject var store: AppStore
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { store.selectServer(server.id) }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(
                                server.active ? ChatTheme.text(mode) : ChatTheme.line2(mode),
                                lineWidth: 2
                            )
                            .frame(width: 20, height: 20)
                        if server.active {
                            Circle()
                                .fill(ChatTheme.text(mode))
                                .frame(width: 10, height: 10)
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(server.name)
                                .font(ChatFont.sans(14, weight: .bold))
                                .foregroundColor(ChatTheme.text(mode))
                            if server.active {
                                Text("Active")
                                    .font(ChatFont.sans(10.5, weight: .bold))
                                    .foregroundColor(ChatTheme.bg(mode))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(ChatTheme.text(mode))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(server.url)
                            .font(ChatFont.mono(11.5))
                            .foregroundColor(ChatTheme.sub(mode))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
            }
            .buttonStyle(.touch)
            .accessibilityLabel("\(server.name), \(server.active ? "active server" : "inactive server")")
            .accessibilityHint("Selects this server")

            HStack(spacing: 8) {
                HStack(spacing: 7) {
                    StatusDot(status: server.status, size: 7)
                    Text(server.status.label)
                        .font(ChatFont.sans(12, weight: .semibold))
                        .foregroundColor(ChatTheme.text(mode))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Connection status: \(server.status.label)")

                Spacer()

                Button(action: { store.beginEditingServer(server.id) }) {
                    Label("Edit", systemImage: "pencil")
                        .font(ChatFont.sans(12, weight: .bold))
                        .foregroundColor(ChatTheme.text(mode))
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.touch)
                .accessibilityLabel("Edit \(server.name)")

                Button(action: { store.testServer(server.id) }) {
                    Text(server.status == .testing ? "Testing…" : "Test")
                        .font(ChatFont.sans(12, weight: .bold))
                        .foregroundColor(ChatTheme.text(mode))
                        .padding(.horizontal, 12)
                        .overlay(Capsule().stroke(ChatTheme.line2(mode), lineWidth: 1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.touch)
                .disabled(server.status == .testing)
                .accessibilityLabel("Test \(server.name) connection")

                Button(action: { showingDeleteConfirmation = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ChatTheme.offline)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.touch)
                .accessibilityLabel("Delete \(server.name)")
                .accessibilityHint("Asks for confirmation before deleting this server")
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 4)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(ChatTheme.line(mode)),
                alignment: .top
            )
        }
        .background(ChatTheme.card(mode))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    server.active ? ChatTheme.text(mode) : ChatTheme.line2(mode),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .confirmationDialog(
            "Delete \(server.name)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Server", role: .destructive) {
                store.deleteServer(server.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the server from Monolith. You can add it again later.")
        }
    }
}

// MARK: - Add server form
struct AddServerForm: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(store.serverFormTitle)
                    .font(ChatFont.sans(15, weight: .bold))
                    .foregroundColor(ChatTheme.text(mode))
                Text("Use an OpenAI-compatible server address.")
                    .font(ChatFont.sans(12))
                    .foregroundColor(ChatTheme.sub(mode))
            }

            TextField("Server name", text: $store.addName)
                .font(ChatFont.sans(14))
                .foregroundColor(ChatTheme.text(mode))
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 13)
                .frame(minHeight: 48)
                .background(ChatTheme.card(mode))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ChatTheme.line2(mode), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

            TextField("http://server.local:8000/v1", text: $store.addUrl)
                .font(ChatFont.mono(13))
                .foregroundColor(ChatTheme.text(mode))
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 13)
                .frame(minHeight: 48)
                .background(ChatTheme.card(mode))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            store.serverFormError == nil
                                ? ChatTheme.line2(mode)
                                : ChatTheme.offline,
                            lineWidth: 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: store.addUrl) { _, _ in
                    store.serverFormURLDidChange()
                }

            SecureField("Gateway token (optional on localhost)", text: $store.addToken)
                .font(ChatFont.mono(13))
                .foregroundColor(ChatTheme.text(mode))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 13)
                .frame(minHeight: 48)
                .background(ChatTheme.card(mode))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(ChatTheme.line2(mode), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Gateway token")
                .onChange(of: store.addToken) { _, _ in
                    store.serverFormTokenDidChange()
                }

            if let error = store.serverFormError {
                Text(error)
                    .font(ChatFont.sans(12, weight: .semibold))
                    .foregroundColor(ChatTheme.offline)
                    .accessibilityLabel("Server address error: \(error)")
            } else {
                Text("Include /v1 if needed. Tokens are stored in this device's Keychain.")
                    .font(ChatFont.sans(11.5))
                    .foregroundColor(ChatTheme.sub(mode))
            }

            if store.addStatus == .ok || store.addStatus == .fail {
                HStack(spacing: 7) {
                    Circle()
                        .fill(store.addStatus == .ok ? ChatTheme.online : ChatTheme.offline)
                        .frame(width: 7, height: 7)
                    Text(store.addStatus == .ok ? "Connection ready" : "Could not reach this server")
                        .font(ChatFont.sans(12, weight: .bold))
                        .foregroundColor(ChatTheme.text(mode))
                }
                .accessibilityElement(children: .combine)
            }

            HStack(spacing: 10) {
                Button(action: { store.testAddServer() }) {
                    Text(store.addStatus == .testing ? "Testing…" : "Test connection")
                        .font(ChatFont.sans(13, weight: .bold))
                        .foregroundColor(ChatTheme.text(mode))
                        .frame(maxWidth: .infinity)
                        .background(ChatTheme.card(mode))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ChatTheme.line2(mode), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.touch)
                .disabled(store.addStatus == .testing || store.serverFormError != nil)

                Button(action: { store.saveServer() }) {
                    Text(store.serverFormSaveLabel)
                        .font(ChatFont.sans(13, weight: .bold))
                        .foregroundColor(
                            store.canSaveServer ? ChatTheme.bg(mode) : ChatTheme.sub(mode)
                        )
                        .frame(maxWidth: .infinity)
                        .background(
                            store.canSaveServer ? ChatTheme.text(mode) : ChatTheme.line2(mode)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.touch)
                .disabled(!store.canSaveServer)
            }
        }
        .padding(16)
        .background(ChatTheme.surface(mode))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(ChatTheme.line2(mode), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
