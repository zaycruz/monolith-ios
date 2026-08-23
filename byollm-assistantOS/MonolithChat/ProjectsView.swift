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
                }
                .buttonStyle(.plain)
            ))

            ScrollView {
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
                            .background(ChatTheme.card(mode))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(ChatTheme.line2(mode), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - New Project
struct NewProjectView: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode

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
                        Text("KNOWLEDGE")
                            .font(ChatFont.sans(11.5, weight: .bold))
                            .tracking(1)
                            .foregroundColor(ChatTheme.sub(mode))

                        if store.npRepo == nil {
                            Button(action: { store.repoPickerOpen.toggle() }) {
                                HStack(spacing: 11) {
                                    Image(systemName: ChatIcon.github)
                                        .font(.system(size: 17))
                                        .foregroundColor(ChatTheme.text(mode).opacity(0.75))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Link a GitHub repository")
                                            .font(ChatFont.sans(13.5, weight: .bold))
                                            .foregroundColor(ChatTheme.text(mode))
                                        Text("Give chats in this project access to your code")
                                            .font(ChatFont.sans(11.5))
                                            .foregroundColor(ChatTheme.sub(mode))
                                    }
                                    Spacer()
                                    Image(systemName: ChatIcon.chevronRight)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(ChatTheme.sub(mode))
                                }
                                .padding(.horizontal, 15)
                                .padding(.vertical, 13)
                            }
                            .buttonStyle(.plain)

                            if store.repoPickerOpen {
                                VStack(spacing: 0) {
                                    ForEach(["monolith/agents", "monolith/api", "monolith/support-tools"], id: \.self) { r in
                                        Button(action: { store.npRepo = r; store.repoPickerOpen = false }) {
                                            HStack {
                                                Text(r)
                                                    .font(ChatFont.mono(13, weight: .semibold))
                                                    .foregroundColor(ChatTheme.text(mode))
                                                Spacer()
                                                Text("Private")
                                                    .font(ChatFont.sans(11))
                                                    .foregroundColor(ChatTheme.sub(mode))
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 11)
                                            .clipShape(RoundedRectangle(cornerRadius: 9))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(6)
                                .overlay(Rectangle().frame(height: 1).foregroundColor(ChatTheme.line(mode)), alignment: .top)
                            }
                        } else {
                            HStack(spacing: 11) {
                                Image(systemName: ChatIcon.github)
                                    .font(.system(size: 17))
                                    .foregroundColor(ChatTheme.text(mode).opacity(0.75))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.npRepo ?? "")
                                        .font(ChatFont.mono(13, weight: .bold))
                                        .foregroundColor(ChatTheme.text(mode))
                                        .lineLimit(1)
                                    Text("Connected")
                                        .font(ChatFont.sans(11, weight: .bold))
                                        .foregroundColor(ChatTheme.online)
                                }
                                Spacer()
                                Button(action: { store.npRepo = nil }) {
                                    Text("Remove")
                                        .font(ChatFont.sans(12, weight: .bold))
                                        .foregroundColor(ChatTheme.sub(mode))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 13)
                        }
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
                    }
                    .buttonStyle(.plain)
                    .disabled(store.npName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
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

                    Button(action: { store.newChat() }) {
                        HStack(spacing: 8) {
                            Text("+ New chat in project")
                                .font(ChatFont.sans(13.5, weight: .bold))
                        }
                        .foregroundColor(ChatTheme.bg(mode))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(ChatTheme.text(mode))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    // Knowledge
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PROJECT KNOWLEDGE")
                            .font(ChatFont.sans(11.5, weight: .bold))
                            .tracking(1)
                            .foregroundColor(ChatTheme.sub(mode))
                        VStack(spacing: 0) {
                            KnowledgeRow(icon: ChatIcon.files, label: "Instructions", value: "Set", mode: mode)
                            Divider().background(ChatTheme.line(mode))
                            KnowledgeRow(icon: ChatIcon.upload, label: "Files", value: "\(store.activeProject?.files ?? 0) attached", mode: mode)
                            Divider().background(ChatTheme.line(mode))
                            KnowledgeRow(icon: ChatIcon.github, label: "GitHub", value: store.activeProject?.repo ?? "Not linked", mode: mode, mono: true)
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
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
        }
    }

    private var projectChats: [Chat] {
        guard let proj = store.activeProject else { return [] }
        return proj.chatIds.compactMap { id in store.chats.first(where: { $0.id == id }) }
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
