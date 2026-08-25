//
//  ProjectsView.swift
//  byollm-assistantOS
//
//  Projects list, New Project form, and Project Detail.
//

import SwiftUI

// MARK: - Projects list
struct ProjectsView: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode

    var body: some View {
        VStack(spacing: 0) {
            SettingsNavBar(title: "Projects", mode: mode, onBack: { store.closeProjects() }, trailing: AnyView(
                Button(action: { store.openNewProject() }) {
                    Image(systemName: ChatIcon.plus)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(ChatTheme.text(mode))
                        .frame(width: 44, height: 44)
                }.buttonStyle(.touch)
            ))

            ScrollView {
                Group {
                    if store.projects.isEmpty {
                        ContentUnavailableView {
                            Label("No projects yet", systemImage: "folder")
                        } description: {
                            Text("Create a project to group chats, instructions, and a repository.")
                        } actions: {
                            Button("Create Project") { store.openNewProject() }
                                .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 72)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.projects) { p in
                                Button(action: { store.openProject(p.id) }) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(spacing: 10) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(ChatTheme.surface(mode))
                                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(ChatTheme.line(mode), lineWidth: 1))
                                                Image(systemName: ChatIcon.files)
                                                    .font(.system(size: 17))
                                                    .foregroundColor(ChatTheme.text(mode).opacity(0.7))
                                            }
                                            .frame(width: 34, height: 34)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(p.name)
                                                    .font(ChatFont.sans(14.5, weight: .bold))
                                                    .foregroundColor(ChatTheme.text(mode))
                                                Text("\(p.chatIds.count) chats · updated \(p.updated)")
                                                    .font(ChatFont.sans(11.5))
                                                    .foregroundColor(ChatTheme.sub(mode))
                                            }
                                            Spacer()
                                            Image(systemName: ChatIcon.chevronRight)
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(ChatTheme.sub(mode))
                                        }
                                        Text(p.desc)
                                            .font(ChatFont.sans(12.5))
                                            .lineSpacing(4)
                                            .foregroundColor(ChatTheme.sub(mode))
                                    }
                                    .padding(15)
                                    .background(ChatTheme.card(mode).opacity(mode == .dark ? 0.78 : 0.86))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(ChatTheme.line2(mode), lineWidth: 0.75)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                                .buttonStyle(.touch)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: 700)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

// MARK: - New Project
struct NewProjectView: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode
    @State private var repoPickerOpen = false

    var body: some View {
        VStack(spacing: 0) {
            SettingsNavBar(title: "New project", mode: mode, onBack: { store.closeNewProject() })

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NAME")
                            .font(ChatFont.sans(11.5, weight: .bold))
                            .tracking(1)
                            .foregroundColor(ChatTheme.sub(mode))
                        TextField("e.g. Billing agent v2", text: $store.npName)
                            .font(ChatFont.sans(14))
                            .foregroundColor(ChatTheme.text(mode))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .background(ChatTheme.card(mode))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ChatTheme.line2(mode), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Text("DESCRIPTION")
                                .font(ChatFont.sans(11.5, weight: .bold))
                                .tracking(1)
                                .foregroundColor(ChatTheme.sub(mode))
                            Text("(optional)")
                                .font(ChatFont.sans(11.5, weight: .semibold))
                                .foregroundColor(ChatTheme.sub(mode))
                        }
                        TextField("What is this project about?", text: $store.npDesc)
                            .font(ChatFont.sans(14))
                            .foregroundColor(ChatTheme.text(mode))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .background(ChatTheme.card(mode))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ChatTheme.line2(mode), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Knowledge
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LINKED REPOSITORY")
                            .font(ChatFont.sans(11.5, weight: .bold))
                            .tracking(1)
                            .foregroundColor(ChatTheme.sub(mode))

                        if !store.repositoryConnections.isEmpty {
                            Menu {
                                ForEach(store.repositoryConnections) { connection in
                                    Button(action: { store.selectRepositoryConnection(connection.id) }) {
                                        if connection.id == store.selectedRepositoryConnectionID {
                                            Label(connection.name, systemImage: "checkmark")
                                        } else {
                                            Text(connection.name)
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text("Provider")
                                        .foregroundColor(ChatTheme.sub(mode))
                                    Spacer()
                                    Text(selectedRepositoryConnectionName)
                                        .foregroundColor(ChatTheme.text(mode))
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundColor(ChatTheme.sub(mode))
                                }
                                .font(ChatFont.sans(12.5, weight: .semibold))
                                .padding(.horizontal, 15)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.touch)
                        }

                        Button(action: {
                            if store.repositoryConnected {
                                store.refreshGitHubRepositories()
                                repoPickerOpen = true
                            } else {
                                store.openAddConn()
                            }
                        }) {
                            HStack(spacing: 11) {
                                Image(systemName: selectedRepositoryIcon)
                                    .font(.system(size: 17))
                                    .foregroundColor(ChatTheme.text(mode).opacity(0.75))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Connected repositories")
                                        .font(ChatFont.sans(13.5, weight: .bold))
                                        .foregroundColor(ChatTheme.text(mode))
                                    Text(repositoryDetail)
                                        .font(ChatFont.sans(11.5))
                                        .foregroundColor(ChatTheme.sub(mode))
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(store.npRepo == nil ? "Choose" : "Linked")
                                    .font(ChatFont.sans(10.5, weight: .bold))
                                    .foregroundColor(ChatTheme.sub(mode))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .overlay(Capsule().stroke(ChatTheme.line2(mode), lineWidth: 1))
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 13)
                        }
                        .buttonStyle(.touch)
                    }
                    .background(ChatTheme.card(mode))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(ChatTheme.line2(mode), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 13))

                    // Create
                    Button(action: { store.createProject() }) {
                        Text("Create project")
                            .font(ChatFont.sans(14, weight: .bold))
                            .foregroundColor(store.npName.trimmingCharacters(in: .whitespaces).isEmpty ? ChatTheme.sub(mode) : ChatTheme.bg(mode))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(store.npName.trimmingCharacters(in: .whitespaces).isEmpty ? ChatTheme.line2(mode) : ChatTheme.text(mode))
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                    }.buttonStyle(.touch)
                    .disabled(store.npName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
                .frame(maxWidth: 700)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $repoPickerOpen) {
            RepositoryPickerView(store: store, mode: mode)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var repositoryDetail: String {
        if let repository = store.npRepo { return repository }
        if store.repositoryConnected {
            return "Links repository metadata; workspace sync is not enabled yet."
        }
        return "Connect a repository plugin from this app to choose a repository."
    }

    private var selectedRepositoryConnectionName: String {
        store.repositoryConnections.first(where: {
            $0.id == store.selectedRepositoryConnectionID
        })?.name ?? "Choose a plugin"
    }

    private var selectedRepositoryIcon: String {
        store.selectedRepositoryConnectionID == "github" ? ChatIcon.github : "externaldrive.connected.to.line.below"
    }
}

private struct RepositoryPickerView: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch store.repositoryLoadState {
                case .loading where store.githubRepositories.isEmpty:
                    ProgressView("Loading repositories…")
                case .failed(let message):
                    ContentUnavailableView(
                        "Repositories unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                default:
                    if store.githubRepositories.isEmpty {
                        ContentUnavailableView(
                            "No repositories found",
                            systemImage: "externaldrive.connected.to.line.below",
                            description: Text("The selected connection plugin did not return any repositories.")
                        )
                    } else {
                        List(store.githubRepositories) { repository in
                            Button(action: {
                                store.selectRepository(repository.fullName)
                                dismiss()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: repository.isPrivate ? "lock.fill" : "book.closed")
                                        .foregroundColor(ChatTheme.sub(mode))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(repository.fullName)
                                            .font(ChatFont.sans(13, weight: .semibold))
                                            .foregroundColor(ChatTheme.text(mode))
                                        Text(repository.defaultBranch.isEmpty ? "Default branch unavailable" : repository.defaultBranch)
                                            .font(ChatFont.mono(10.5))
                                            .foregroundColor(ChatTheme.sub(mode))
                                    }
                                    Spacer()
                                    if store.npRepo == repository.fullName {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(ChatTheme.online)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle(store.repositoryConnections.first(where: {
                $0.id == store.selectedRepositoryConnectionID
            })?.name ?? "Repository")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Refresh") { store.refreshGitHubRepositories() }
                        .disabled(store.repositoryLoadState == .loading)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Project Detail
struct ProjectDetailView: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode

    var body: some View {
        VStack(spacing: 0) {
            SettingsNavBar(title: store.activeProject?.name ?? "Project", mode: mode, onBack: { store.closeProject() })

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(store.activeProject?.desc ?? "")
                        .font(ChatFont.sans(13))
                        .lineSpacing(5)
                        .foregroundColor(ChatTheme.sub(mode))

                    Button(action: { store.newChat(inProject: store.activeProject?.id) }) {
                        Label("New chat in project", systemImage: "plus")
                            .font(ChatFont.sans(13.5, weight: .bold))
                        .foregroundColor(ChatTheme.bg(mode))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(ChatTheme.text(mode))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.touch)

                    // Linked metadata
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PROJECT LINKS")
                            .font(ChatFont.sans(11.5, weight: .bold))
                            .tracking(1)
                            .foregroundColor(ChatTheme.sub(mode))
                        VStack(spacing: 0) {
                            KnowledgeRow(icon: ChatIcon.files, label: "Instructions", value: "Set", mode: mode)
                            Divider().background(ChatTheme.line(mode))
                            KnowledgeRow(icon: ChatIcon.upload, label: "Files", value: "\(store.activeProject?.files ?? 0) attached", mode: mode)
                            Divider().background(ChatTheme.line(mode))
                            KnowledgeRow(
                                icon: "link",
                                label: repositoryLabel,
                                value: store.activeProject?.repo ?? "Not linked",
                                mode: mode,
                                mono: true
                            )
                        }
                        .background(ChatTheme.card(mode))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(ChatTheme.line2(mode), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                    }

                    // Chats
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CHATS")
                            .font(ChatFont.sans(11.5, weight: .bold))
                            .tracking(1)
                            .foregroundColor(ChatTheme.sub(mode))
                        VStack(spacing: 2) {
                            ForEach(projectChats) { c in
                                Button(action: { store.openChat(c.id) }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: ChatIcon.chat)
                                            .font(.system(size: 16))
                                            .foregroundColor(ChatTheme.sub(mode))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(c.title)
                                                .font(ChatFont.sans(13.5, weight: .semibold))
                                                .foregroundColor(ChatTheme.text(mode))
                                                .lineLimit(1)
                                            Text(c.time)
                                                .font(ChatFont.sans(11))
                                                .foregroundColor(ChatTheme.sub(mode))
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 12)
                                    .clipShape(RoundedRectangle(cornerRadius: 11))
                                }.buttonStyle(.touch)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 24)
                .frame(maxWidth: 700)
            }
        }
    }

    private var projectChats: [Chat] {
        guard let proj = store.activeProject else { return [] }
        return proj.chatIds.compactMap { id in store.chats.first(where: { $0.id == id }) }
    }

    private var repositoryLabel: String {
        guard let connectionID = store.activeProject?.repositoryConnectionID else {
            return "Repository"
        }
        let project = store.activeProject
        let name = project?.repositoryConnectionName ?? connectionID
        guard project?.repositoryServerID == store.activeServer?.id,
              project?.repositoryServerURL == store.activeServer.flatMap({
                  try? NetworkManager.shared.normalizeServerAddress($0.url)
              }) else {
            return "\(name) repository (other server)"
        }
        return "\(name) repository"
    }
}

struct KnowledgeRow: View {
    var icon: String
    var label: String
    var value: String
    var mode: ChatTheme.Mode
    var mono: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(ChatTheme.text(mode).opacity(0.6))
            Text(label)
                .font(ChatFont.sans(13, weight: .semibold))
                .foregroundColor(ChatTheme.text(mode))
            Spacer()
            Text(value)
                .font(mono ? ChatFont.mono(11.5) : ChatFont.sans(11.5))
                .foregroundColor(ChatTheme.sub(mode))
                .lineLimit(1)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
    }
}
