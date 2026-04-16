//
//  DMsTabView.swift
//  Workspace
//
//  Tab screen — dedicated list of direct messages, one row per DM with
//  member + unread count. Tapping an agent DM opens AgentDMView; human
//  DMs render as rows but taps are a no-op (mock has no human DM view).
//

import SwiftUI

@MainActor
final class DMsTabViewModel: ObservableObject {
    @Published var dms: [DirectMessage] = []
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
            let ws = try await workspaceRepo.loadCurrentWorkspace()
            self.dms = ws.dms
        } catch {
            self.errorMessage = "\(error)"
        }
    }
}

struct DMsTabView: View {
    @StateObject private var viewModel: DMsTabViewModel
    var onOpenDM: ((DMID) -> Void)?

    init(
        workspaceRepo: WorkspaceRepository,
        onOpenDM: ((DMID) -> Void)? = nil
    ) {
        self._viewModel = StateObject(
            wrappedValue: DMsTabViewModel(workspaceRepo: workspaceRepo)
        )
        self.onOpenDM = onOpenDM
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.dms) { dm in
                        row(dm)
                        Rectangle()
                            .fill(MonolithTheme.Colors.borderSoft)
                            .frame(height: 1)
                            .padding(.leading, MonolithTheme.Spacing.lg + 32 + MonolithTheme.Spacing.md)
                    }
                }
                .padding(.top, MonolithTheme.Spacing.sm)
            }
        }
        .background(MonolithTheme.Colors.bgBase.ignoresSafeArea())
        .task {
            if viewModel.dms.isEmpty {
                await viewModel.load()
            }
        }
    }

    // MARK: header
    private var header: some View {
        HStack(spacing: MonolithTheme.Spacing.sm) {
            Text("DIRECT MESSAGES")
                .font(MonolithFont.mono(size: 12, weight: .bold))
                .tracking(0.72)
                .foregroundColor(MonolithTheme.Colors.textPrimary)
            Spacer()
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

    // MARK: row
    @ViewBuilder
    private func row(_ dm: DirectMessage) -> some View {
        if dm.counterpart.isAgent {
            Button(action: { onOpenDM?(dm.id) }) {
                rowContent(dm)
            }
            .buttonStyle(.plain)
        } else {
            // Human DM — render but tap is a no-op (no human DM view yet).
            rowContent(dm)
        }
    }

    private func rowContent(_ dm: DirectMessage) -> some View {
        HStack(spacing: MonolithTheme.Spacing.md) {
            switch dm.counterpart.kind {
            case .human(let h): HumanAvatar(human: h, size: .lg)
            case .agent(let a): AgentAvatar(agent: a, size: .lg)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(dm.counterpart.displayName)
                        .font(dm.counterpart.isAgent
                              ? MonolithFont.mono(size: 14, weight: .medium)
                              : MonolithFont.sans(size: 15, weight: .medium))
                        .foregroundColor(MonolithTheme.Colors.textPrimary)
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
                }
                Text(preview(for: dm))
                    .font(MonolithFont.sans(size: 13))
                    .foregroundColor(MonolithTheme.Colors.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            if dm.unread > 0 { unreadBadge(dm.unread) }
        }
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.vertical, MonolithTheme.Spacing.md)
        .contentShape(Rectangle())
    }

    /// Preview copy — for agent DMs the mock has fixtures; everything else
    /// falls back to a muted hint.
    private func preview(for dm: DirectMessage) -> String {
        switch dm.counterpart.kind {
        case .agent(let a):
            switch a.handle {
            case "dispatch": return "drafted TLH reply for Greg — ready for your review"
            case "scout":    return "JobNimbus mapping paused — awaiting sample data"
            case "warden":   return "overnight recon complete, no critical findings"
            case "pulse":    return "standby — no active task"
            case "herald":   return "deploy pipeline green for release-1.14"
            default:         return "no recent message"
            }
        case .human:
            return "tap coming soon"
        }
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
}

#Preview("DMsTabView") {
    DMsTabView(workspaceRepo: MockWorkspaceRepository())
}
