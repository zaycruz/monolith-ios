//
//  WorkspaceHomeView.swift
//  Workspace
//
//  Screen 01 — Workspace home. Shows workspace name, channel list, and DM list.
//

import SwiftUI

@MainActor
final class WorkspaceHomeViewModel: ObservableObject {
    @Published var workspace: Workspace?
    @Published var loading: Bool = false
    @Published var errorMessage: String?

    private let workspaceRepo: WorkspaceRepository

    init(workspaceRepo: WorkspaceRepository) {
        self.workspaceRepo = workspaceRepo
    }

    func load() async {
        loading = true
        defer { loading = false }
        do {
            self.workspace = try await workspaceRepo.loadCurrentWorkspace()
        } catch {
            self.errorMessage = "\(error)"
        }
    }
}

struct WorkspaceHomeView: View {
    @StateObject private var viewModel: WorkspaceHomeViewModel
    var onOpenChannel: ((ChannelID) -> Void)?
    var onOpenDM: ((DMID) -> Void)?
    var onOpenInviteAgent: (() -> Void)?

    init(
        workspaceRepo: WorkspaceRepository,
        onOpenChannel: ((ChannelID) -> Void)? = nil,
        onOpenDM: ((DMID) -> Void)? = nil,
        onOpenInviteAgent: (() -> Void)? = nil
    ) {
        self._viewModel = StateObject(
            wrappedValue: WorkspaceHomeViewModel(workspaceRepo: workspaceRepo)
        )
        self.onOpenChannel = onOpenChannel
        self.onOpenDM = onOpenDM
        self.onOpenInviteAgent = onOpenInviteAgent
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    searchBar
                    shortcutsSection
                    Spacer().frame(height: MonolithTheme.Spacing.sm)
                    sectionHeader("CHANNELS", action: "+") {
                        onOpenInviteAgent?()
                    }
                    channelsSection
                    Spacer().frame(height: MonolithTheme.Spacing.xl)
                    sectionHeader("DIRECT MESSAGES", action: nil) {}
                    dmsSection
                    Spacer().frame(height: MonolithTheme.Spacing.xxxl)
                }
            }
        }
        .background(MonolithTheme.Colors.bgBase.ignoresSafeArea())
        .task {
            if viewModel.workspace == nil {
                await viewModel.load()
            }
        }
    }

    // MARK: header — slit icon + workspace name + chevron, presence line below
    private var header: some View {
        VStack(alignment: .leading, spacing: MonolithTheme.Spacing.xs) {
            HStack(spacing: MonolithTheme.Spacing.sm) {
                // Slit icon: 3x18pt snow-colored rectangle (brand mark)
                Rectangle()
                    .fill(MonolithTheme.Colors.textPrimary)
                    .frame(width: 3, height: 18)
                Text(viewModel.workspace?.name ?? "…")
                    .font(MonolithFont.mono(size: 16, weight: .bold))
                    .foregroundColor(MonolithTheme.Colors.textPrimary)
                Text("\u{25BE}") // ▾
                    .font(MonolithFont.mono(size: 12, weight: .regular))
                    .foregroundColor(MonolithTheme.Colors.textMuted)
                Spacer()
            }
            // Presence line: green dot + "2 teammates · 8 agents running"
            HStack(spacing: MonolithTheme.Spacing.xs) {
                Circle()
                    .fill(MonolithTheme.Colors.statusRunning)
                    .frame(width: 6, height: 6)
                    .shadow(color: MonolithTheme.Colors.statusRunning.opacity(0.6), radius: 2)
                Text("2 teammates \u{00B7} 8 agents running")
                    .font(MonolithFont.mono(size: 10))
                    .foregroundColor(MonolithTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.vertical, MonolithTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MonolithTheme.Colors.bgSurface)
        .overlay(
            Rectangle().fill(MonolithTheme.Colors.bgElevated).frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: search bar — "jump to..."
    private var searchBar: some View {
        HStack(spacing: MonolithTheme.Spacing.sm) {
            Text("jump to...")
                .font(MonolithFont.mono(size: 12))
                .foregroundColor(MonolithTheme.Colors.textMuted)
            Spacer()
        }
        .padding(.horizontal, MonolithTheme.Spacing.md)
        .padding(.vertical, MonolithTheme.Spacing.sm)
        .background(MonolithTheme.Colors.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.md))
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.top, MonolithTheme.Spacing.md)
    }

    // MARK: shortcuts section — Threads, Activity, Drafts & sent
    private var shortcutsSection: some View {
        VStack(spacing: 0) {
            shortcutRow(label: "Threads", count: "3")
            shortcutRow(label: "Activity", count: "12 new")
            shortcutRow(label: "Drafts & sent", count: "2")
        }
        .padding(.top, MonolithTheme.Spacing.md)
    }

    private func shortcutRow(label: String, count: String) -> some View {
        HStack(spacing: MonolithTheme.Spacing.md) {
            Text(label)
                .font(MonolithFont.sans(size: 15))
                .foregroundColor(MonolithTheme.Colors.textSecondary)
            Spacer()
            Text(count)
                .font(MonolithFont.mono(size: 10, weight: .medium))
                .foregroundColor(MonolithTheme.Colors.textTertiary)
        }
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.vertical, MonolithTheme.Spacing.sm)
    }

    // MARK: section header
    private func sectionHeader(
        _ title: String,
        action: String?,
        onAction: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(MonolithFont.mono(size: 10, weight: .medium))
                .tracking(0.6)
                .foregroundColor(MonolithTheme.Colors.textTertiary)
            Spacer()
            if let action = action {
                Button(action: onAction) {
                    Text(action)
                        .font(MonolithFont.mono(size: 14, weight: .medium))
                        .foregroundColor(MonolithTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.top, MonolithTheme.Spacing.lg)
        .padding(.bottom, MonolithTheme.Spacing.sm)
    }

    // MARK: channels
    private var channelsSection: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.workspace?.channels ?? []) { channel in
                channelRow(channel)
            }
        }
    }

    private func channelRow(_ channel: Channel) -> some View {
        Button(action: { onOpenChannel?(channel.id) }) {
            HStack(spacing: MonolithTheme.Spacing.md) {
                Text("#")
                    .font(MonolithFont.mono(size: 16, weight: .medium))
                    .foregroundColor(MonolithTheme.Colors.textTertiary)
                    .frame(width: 20)
                Text(channel.name)
                    .font(MonolithFont.sans(size: 15))
                    .foregroundColor(MonolithTheme.Colors.textSecondary)
                Spacer()
                if channel.unread > 0 {
                    unreadBadge(channel.unread)
                }
            }
            .padding(.horizontal, MonolithTheme.Spacing.lg)
            .padding(.vertical, MonolithTheme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func unreadBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(MonolithFont.mono(size: 10, weight: .bold))
            .foregroundColor(MonolithTheme.Palette.void)
            .frame(minWidth: 20)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(MonolithTheme.Palette.snow)
            .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.pill))
    }

    // MARK: DMs
    private var dmsSection: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.workspace?.dms ?? []) { dm in
                dmRow(dm)
            }
        }
    }

    private func dmRow(_ dm: DirectMessage) -> some View {
        Button(action: { onOpenDM?(dm.id) }) {
            HStack(spacing: MonolithTheme.Spacing.md) {
                switch dm.counterpart.kind {
                case .human(let h): HumanAvatar(human: h, size: .md)
                case .agent(let a): AgentAvatar(agent: a, size: .md)
                }
                Text(dm.counterpart.displayName)
                    .font(dm.counterpart.isAgent
                          ? MonolithFont.mono(size: 14)
                          : MonolithFont.sans(size: 15))
                    .foregroundColor(MonolithTheme.Colors.textSecondary)
                if dm.counterpart.isAgent {
                    Text("AGENT")
                        .font(MonolithFont.mono(size: 9, weight: .medium))
                        .tracking(0.6)
                        .foregroundColor(MonolithTheme.Colors.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: MonolithTheme.Radius.sm)
                                .stroke(MonolithTheme.Colors.borderStrong, lineWidth: 1)
                        )
                }
                Spacer()
                if dm.unread > 0 { unreadBadge(dm.unread) }
            }
            .padding(.horizontal, MonolithTheme.Spacing.lg)
            .padding(.vertical, MonolithTheme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("WorkspaceHomeView") {
    WorkspaceHomeView(workspaceRepo: MockWorkspaceRepository())
}
