//
//  ConnectionsView.swift
//  byollm-assistantOS
//
//  App-initiated connections verified and brokered by the active server.
//

import SwiftUI

struct ConnectionsView: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode

    var body: some View {
        VStack(spacing: 0) {
            SettingsNavBar(title: "Connections", mode: mode, onBack: { store.closeConnections() }, trailing: AnyView(
                Button(action: { store.refreshConnections() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(ChatTheme.text(mode))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.touch)
                .accessibilityLabel("Refresh connections")
            ))

            ScrollView {
                VStack(spacing: 14) {
                    switch store.connectionLoadState {
                    case .loading where store.connections.isEmpty:
                        connectionStatus(icon: "arrow.triangle.2.circlepath", title: "Checking active server", detail: "Verifying your app-authorized connections.")
                        ProgressView().tint(ChatTheme.text(mode))
                    case .failed(let message):
                        connectionStatus(icon: "exclamationmark.triangle", title: "Connections unavailable", detail: message)
                        retryButton
                    case .idle where store.activeServer == nil:
                        connectionStatus(icon: "server.rack", title: "No active server", detail: "Add a Monolith server before connecting GitHub repositories.")
                    default:
                        if store.connections.isEmpty {
                            connectionStatus(icon: "link", title: "No connections reported", detail: "The active server did not report any configured app connections.")
                            retryButton
                        } else {
                            ForEach(store.connections) { connection in
                                connectionCard(connection)
                            }
                            Text("GitHub sign-in starts on this device. The active Monolith server stores the resulting credential encrypted and exposes only repositories you selected for the GitHub App.")
                                .font(ChatFont.sans(11.5))
                                .lineSpacing(3)
                                .foregroundColor(ChatTheme.sub(mode))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
        }
    }

    private func connectionCard(_ connection: AppConnection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: connection.id == "github" ? ChatIcon.github : "link")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(ChatTheme.text(mode))
                    .frame(width: 42, height: 42)
                    .background(ChatTheme.surface(mode))
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 3) {
                    Text(connection.name)
                        .font(ChatFont.sans(14, weight: .bold))
                        .foregroundColor(ChatTheme.text(mode))
                    Text(connection.connected ? "Connected as \(connection.account)" : "Not connected")
                        .font(ChatFont.sans(11.5, weight: .semibold))
                        .foregroundColor(connection.connected ? ChatTheme.online : ChatTheme.sub(mode))
                }
                Spacer()
                Circle()
                    .fill(connection.connected ? ChatTheme.online : ChatTheme.unknown)
                    .frame(width: 8, height: 8)
            }
            Text(connection.desc)
                .font(ChatFont.sans(12))
                .lineSpacing(3)
                .foregroundColor(ChatTheme.sub(mode))
            if connection.id == "github", connection.installationRequired == true {
                Button("Choose repositories") { store.openAddConn() }
                    .font(ChatFont.sans(11.5, weight: .bold))
                    .foregroundColor(ChatTheme.text(mode))
                    .buttonStyle(.touch)
            } else if connection.id == "github", connection.connected {
                Text("Repository discovery available")
                    .font(ChatFont.sans(11.5, weight: .bold))
                    .foregroundColor(ChatTheme.text(mode).opacity(0.75))
                Button("Manage connection") { store.openAddConn() }
                    .font(ChatFont.sans(11.5, weight: .bold))
                    .foregroundColor(ChatTheme.sub(mode))
                    .buttonStyle(.touch)
            } else if connection.id == "github" {
                Button("Connect GitHub") { store.openAddConn() }
                    .font(ChatFont.sans(12, weight: .bold))
                    .foregroundColor(ChatTheme.text(mode))
                    .buttonStyle(.touch)
            }
        }
        .padding(15)
        .background(ChatTheme.card(mode))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ChatTheme.line2(mode), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func connectionStatus(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 23, weight: .medium))
                .foregroundColor(ChatTheme.sub(mode))
            Text(title)
                .font(ChatFont.sans(15, weight: .bold))
                .foregroundColor(ChatTheme.text(mode))
            Text(detail)
                .font(ChatFont.sans(12.5))
                .lineSpacing(4)
                .foregroundColor(ChatTheme.sub(mode))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 34)
    }

    private var retryButton: some View {
        Button(action: { store.refreshConnections() }) {
            Text("Try again")
                .font(ChatFont.sans(13, weight: .bold))
                .foregroundColor(ChatTheme.bg(mode))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(ChatTheme.text(mode))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.touch)
    }
}

struct AddConnectionSheet: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode
    @Environment(\.openURL) private var openURL
    @State private var confirmDisconnect = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule().fill(ChatTheme.line2(mode)).frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)

            HStack {
                Text("Connect GitHub")
                    .font(ChatFont.sans(16, weight: .bold))
                    .foregroundColor(ChatTheme.text(mode))
                Spacer()
                Button("Close") { store.dismissAddConnection() }
                    .font(ChatFont.sans(12, weight: .bold))
                    .foregroundColor(ChatTheme.text(mode))
                    .buttonStyle(.touch)
            }
            Text("Sign in from this device, then choose which repositories the Monolith GitHub App may read. The gateway encrypts the credential and does not inject it into Pi or Oh My Pi harness processes. High-assurance deployments should isolate the gateway and harnesses with separate OS permissions.")
                .font(ChatFont.sans(12))
                .lineSpacing(4)
                .foregroundColor(ChatTheme.sub(mode))

            switch store.githubAuthorizationState {
            case .authorizing:
                ProgressView("Waiting for GitHub…")
                    .frame(maxWidth: .infinity)
                Button("Cancel") { store.cancelGitHubAuthorization() }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(.touch)
            case .disconnecting:
                ProgressView("Disconnecting…")
                    .frame(maxWidth: .infinity, minHeight: 44)
            case .installationRequired(let url):
                primaryButton("Choose repositories on GitHub") { openURL(url) }
                Button("I've finished setup") {
                    store.refreshConnections()
                    store.closeAddConn()
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.touch)
            case .failed(let message):
                Text(message)
                    .font(ChatFont.sans(11.5))
                    .foregroundColor(ChatTheme.offline)
                primaryButton("Try GitHub again") { store.connectGitHub() }
            case .idle where store.githubConnected:
                primaryButton("Refresh repositories") {
                    store.refreshConnections()
                    store.closeAddConn()
                }
                Button("Disconnect GitHub", role: .destructive) { confirmDisconnect = true }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(.touch)
            default:
                primaryButton("Continue with GitHub") { store.connectGitHub() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 28)
        .background(ChatTheme.bg(mode))
        .clipShape(RoundedCorner(radius: 22, corners: [.topLeft, .topRight]))
        .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: -8)
        .accessibilityAddTraits(.isModal)
        .confirmationDialog("Disconnect GitHub?", isPresented: $confirmDisconnect, titleVisibility: .visible) {
            Button("Disconnect", role: .destructive) { store.disconnectGitHub() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Projects keep their repository labels, but repository browsing will be unavailable until you reconnect.")
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ChatFont.sans(13, weight: .bold))
                .foregroundColor(ChatTheme.bg(mode))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(ChatTheme.text(mode))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.touch)
    }
}
