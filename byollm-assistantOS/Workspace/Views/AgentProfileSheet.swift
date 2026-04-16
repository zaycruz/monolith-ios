//
//  AgentProfileSheet.swift
//  Workspace
//
//  Screen 04 — Agent detail. Rebuilt from the v0.2 profile sheet to the
//  v0.3 layout (kept the `AgentProfileSheet` name to avoid touching the
//  shell wiring; the contents are effectively AgentDetailView now).
//
//  Layout:
//  - Glass nav (back + title "agent detail" + ellipsis)
//  - Hero: 56pt avatar centered, name (JBM 20pt semibold), role sub,
//    green-tinted running · healthy pill
//  - Glass tab selector (Overview / Tools / Logs / Config)
//  - KV rows for Instance + Model blocks
//  - Tools list (36pt icon + 2-letter abbrev + origin + status;
//    supabase.mcp shows amber warn)
//  - Three action buttons (Open terminal, Message dispatch,
//    Stop agent — danger variant)
//

import SwiftUI

@MainActor
final class AgentDetailViewModel: ObservableObject {
    @Published var agent: Agent?
    @Published var errorMessage: String?
    @Published var selectedTab: Tab = .overview

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case tools    = "Tools"
        case logs     = "Logs"
        case config   = "Config"
    }

    let agentID: AgentID
    private let agentRepo: AgentRepository

    init(agentID: AgentID, agentRepo: AgentRepository) {
        self.agentID = agentID
        self.agentRepo = agentRepo
    }

    func load() async {
        do {
            self.agent = try await agentRepo.loadAgent(agentID)
        } catch {
            self.errorMessage = "\(error)"
        }
    }
}

/// Retained name `AgentProfileSheet` for shell compatibility; the type
/// behaves like an AgentDetailView per v0.3 spec.
struct AgentProfileSheet: View {
    @StateObject private var viewModel: AgentDetailViewModel
    var onClose: (() -> Void)?

    init(
        agentID: AgentID,
        agentRepo: AgentRepository,
        onClose: (() -> Void)? = nil
    ) {
        self._viewModel = StateObject(
            wrappedValue: AgentDetailViewModel(
                agentID: agentID,
                agentRepo: agentRepo
            )
        )
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            if let agent = viewModel.agent {
                ScrollView {
                    VStack(spacing: MonolithTheme.Spacing.xl) {
                        hero(agent)
                        tabSelector
                        content(for: agent)
                        actionButtons(agent)
                        Spacer().frame(height: MonolithTheme.Spacing.xxl)
                    }
                    .padding(.horizontal, MonolithTheme.Spacing.lg)
                    .padding(.top, MonolithTheme.Spacing.lg)
                }
            } else {
                Spacer()
            }
        }
        .background(MonolithTheme.Colors.bgBase.ignoresSafeArea())
        .task { await viewModel.load() }
    }

    // MARK: nav
    private var navBar: some View {
        GlassNavBar(
            leading: {
                GlassNavCloseButton(onTap: { onClose?() })
            },
            title: {
                GlassNavTitle(title: "agent detail", titleIsMono: true)
            },
            trailing: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(MonolithTheme.Colors.textSecondary)
                    .frame(width: 36, height: 36)
            }
        )
    }

    // MARK: hero
    private func hero(_ agent: Agent) -> some View {
        VStack(spacing: MonolithTheme.Spacing.md) {
            AvatarWithPresence(agent: agent, size: .xxl)
            VStack(spacing: 4) {
                Text(agent.handle)
                    .font(MonolithFont.mono(size: 20, weight: .semibold))
                    .foregroundColor(MonolithTheme.Colors.textPrimary)
                Text(roleLabel(for: agent))
                    .font(MonolithFont.sans(size: 13))
                    .foregroundColor(MonolithTheme.Colors.textTertiary)
            }
            AgentStatusPill(status: agent.status, label: statusLabel(for: agent.status))
        }
        .frame(maxWidth: .infinity)
    }

    private func roleLabel(for agent: Agent) -> String {
        switch agent.template {
        case "researcher": return "researcher"
        case "engineer":   return "engineer"
        case "operator":   return "operator · ops desk"
        default:           return agent.template ?? "agent"
        }
    }

    private func statusLabel(for status: AgentStatus) -> String {
        switch status {
        case .running: return "running · healthy"
        case .idle:    return "idle · standby"
        case .error:   return "error"
        }
    }

    // MARK: tab selector
    private var tabSelector: some View {
        HStack(spacing: 4) {
            ForEach(AgentDetailViewModel.Tab.allCases, id: \.self) { tab in
                let selected = viewModel.selectedTab == tab
                Button(action: { viewModel.selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(MonolithFont.sans(size: 13, weight: .medium))
                        .foregroundColor(selected
                                         ? MonolithTheme.Colors.textPrimary
                                         : MonolithTheme.Colors.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(selected ? Color.white.opacity(0.06) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .background(MonolithTheme.Glass.bg)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(MonolithTheme.Glass.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: tab content
    @ViewBuilder
    private func content(for agent: Agent) -> some View {
        switch viewModel.selectedTab {
        case .overview:
            VStack(spacing: MonolithTheme.Spacing.lg) {
                instanceBlock(agent)
                modelBlock(agent)
                toolsList(agent)
            }
        case .tools:
            toolsList(agent)
        case .logs:
            placeholderBlock("Logs coming soon.")
        case .config:
            placeholderBlock("Config coming soon.")
        }
    }

    private func placeholderBlock(_ label: String) -> some View {
        Text(label)
            .font(MonolithFont.sans(size: 13))
            .foregroundColor(MonolithTheme.Colors.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 120)
    }

    // MARK: KV blocks
    private func instanceBlock(_ agent: Agent) -> some View {
        kvSection("Instance", rows: [
            ("host", agent.instanceSize ?? "—"),
            ("vcpu · memory", "\(agent.vcpu ?? 0) · \(agent.memoryGB ?? 0) gb"),
            ("region", agent.region ?? "—"),
            ("uptime", agent.uptimeSeconds.map(Self.formatUptime) ?? "—")
        ])
    }

    private func modelBlock(_ agent: Agent) -> some View {
        kvSection("Model", rows: [
            ("provider", agent.model ?? "—"),
            ("tokens 24h", agent.tokens24h.map {
                Self.numberFormatter.string(from: NSNumber(value: $0)) ?? "\($0)"
            } ?? "—")
        ])
    }

    private func kvSection(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: MonolithTheme.Spacing.sm) {
            Text(title.uppercased())
                .font(MonolithFont.sans(size: 11, weight: .semibold))
                .tracking(0.3)
                .foregroundColor(MonolithTheme.Colors.textTertiary)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, pair in
                    HStack(alignment: .firstTextBaseline) {
                        Text(pair.0)
                            .font(MonolithFont.sans(size: 13))
                            .foregroundColor(MonolithTheme.Colors.textTertiary)
                        Spacer()
                        Text(pair.1)
                            .font(MonolithFont.mono(size: 13))
                            .foregroundColor(MonolithTheme.Colors.textPrimary)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, MonolithTheme.Spacing.md)
                    .padding(.vertical, MonolithTheme.Spacing.sm)
                    if idx < rows.count - 1 {
                        Rectangle()
                            .fill(MonolithTheme.Glass.border)
                            .frame(height: 1)
                            .padding(.horizontal, MonolithTheme.Spacing.md)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .background(MonolithTheme.Glass.bg)
            .overlay(
                RoundedRectangle(cornerRadius: MonolithTheme.Radius.md)
                    .stroke(MonolithTheme.Glass.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.md))
        }
    }

    // MARK: tools list
    private func toolsList(_ agent: Agent) -> some View {
        VStack(alignment: .leading, spacing: MonolithTheme.Spacing.sm) {
            Text("TOOLS")
                .font(MonolithFont.sans(size: 11, weight: .semibold))
                .tracking(0.3)
                .foregroundColor(MonolithTheme.Colors.textTertiary)
            VStack(spacing: 0) {
                ForEach(agent.connectedTools) { tool in
                    toolRow(tool)
                    if tool.id != agent.connectedTools.last?.id {
                        Rectangle()
                            .fill(MonolithTheme.Glass.border)
                            .frame(height: 1)
                            .padding(.leading, 64)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .background(MonolithTheme.Glass.bg)
            .overlay(
                RoundedRectangle(cornerRadius: MonolithTheme.Radius.md)
                    .stroke(MonolithTheme.Glass.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.md))
        }
    }

    private func toolRow(_ tool: AgentTool) -> some View {
        HStack(spacing: MonolithTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(MonolithTheme.Glass.border, lineWidth: 1)
                    )
                Text(tool.abbreviation)
                    .font(MonolithFont.mono(size: 13, weight: .semibold))
                    .foregroundColor(MonolithTheme.Colors.textPrimary)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(MonolithFont.mono(size: 14, weight: .medium))
                    .foregroundColor(MonolithTheme.Colors.textPrimary)
                Text(tool.origin)
                    .font(MonolithFont.sans(size: 12))
                    .foregroundColor(MonolithTheme.Colors.textTertiary)
            }
            Spacer()
            statusChip(tool.status)
        }
        .padding(.horizontal, MonolithTheme.Spacing.md)
        .padding(.vertical, MonolithTheme.Spacing.sm)
        .frame(minHeight: 56)
    }

    private func statusChip(_ status: AgentToolStatus) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case .ok:    return ("ok", MonolithTheme.Colors.statusRunning)
            case .warn:  return ("warn", MonolithTheme.Colors.statusWarning)
            case .error: return ("err", MonolithTheme.Colors.statusError)
            }
        }()
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(MonolithFont.mono(size: 11, weight: .medium))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
        .clipShape(Capsule())
    }

    // MARK: action buttons
    private func actionButtons(_ agent: Agent) -> some View {
        VStack(spacing: MonolithTheme.Spacing.sm) {
            actionButton(label: "Open terminal", systemImage: "terminal", variant: .secondary)
            actionButton(label: "Message \(agent.handle)", systemImage: "bubble.left.and.bubble.right", variant: .primary)
            actionButton(label: "Stop agent", systemImage: "stop.circle", variant: .danger)
        }
    }

    private enum ActionVariant { case primary, secondary, danger }

    @ViewBuilder
    private func actionButton(label: String, systemImage: String, variant: ActionVariant) -> some View {
        Button(action: {}) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                Text(label)
                    .font(
                        variant == .primary
                            ? MonolithFont.sans(size: 14, weight: .semibold)
                            : MonolithFont.sans(size: 14, weight: .medium)
                    )
            }
            .foregroundColor(foreground(variant))
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(background(variant))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(border(variant), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func foreground(_ v: ActionVariant) -> Color {
        switch v {
        case .primary:   return MonolithTheme.Palette.void
        case .secondary: return MonolithTheme.Colors.textPrimary
        case .danger:    return MonolithTheme.Colors.statusError
        }
    }

    @ViewBuilder
    private func background(_ v: ActionVariant) -> some View {
        switch v {
        case .primary:
            MonolithTheme.Colors.textPrimary
        case .secondary:
            Color.white.opacity(0.04)
        case .danger:
            MonolithTheme.Colors.statusError.opacity(0.1)
        }
    }

    private func border(_ v: ActionVariant) -> Color {
        switch v {
        case .primary:   return Color.clear
        case .secondary: return MonolithTheme.Glass.border
        case .danger:    return MonolithTheme.Colors.statusError.opacity(0.3)
        }
    }

    // MARK: helpers
    private static let numberFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        return nf
    }()

    private static func formatUptime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return "\(h)h \(m)m"
    }
}

#Preview("AgentDetailView — dispatch") {
    AgentProfileSheet(
        agentID: MockAgents.dispatch.id,
        agentRepo: MockAgentRepository()
    )
}
