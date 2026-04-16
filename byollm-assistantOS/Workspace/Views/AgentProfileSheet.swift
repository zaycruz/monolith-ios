//
//  AgentProfileSheet.swift
//  Workspace
//
//  Screen 05 — agent profile sheet. Opens from a message author or a DM header.
//

import SwiftUI

@MainActor
final class AgentProfileViewModel: ObservableObject {
    @Published var agent: Agent?
    @Published var errorMessage: String?

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

struct AgentProfileSheet: View {
    @StateObject private var viewModel: AgentProfileViewModel
    var onClose: (() -> Void)?

    init(
        agentID: AgentID,
        agentRepo: AgentRepository,
        onClose: (() -> Void)? = nil
    ) {
        self._viewModel = StateObject(
            wrappedValue: AgentProfileViewModel(
                agentID: agentID,
                agentRepo: agentRepo
            )
        )
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let agent = viewModel.agent {
                ScrollView {
                    VStack(alignment: .leading, spacing: MonolithTheme.Spacing.xl) {
                        identityBlock(agent)
                        metaBlock(agent)
                        runtimeBlock(agent)
                        modelBlock(agent)
                    }
                    .padding(MonolithTheme.Spacing.lg)
                }
            } else {
                Spacer()
            }
        }
        .background(MonolithTheme.Colors.bgBase.ignoresSafeArea())
        .task { await viewModel.load() }
    }

    // MARK: header
    private var header: some View {
        HStack {
            Text("AGENT PROFILE")
                .font(MonolithFont.mono(size: 11, weight: .medium))
                .tracking(0.6)
                .foregroundColor(MonolithTheme.Colors.textTertiary)
            Spacer()
            Button(action: { onClose?() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(MonolithTheme.Colors.textTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.leading, MonolithTheme.Spacing.lg)
        .padding(.trailing, MonolithTheme.Spacing.xs)
        .frame(minHeight: 44)
        .background(MonolithTheme.Colors.bgSurface)
        .overlay(
            Rectangle().fill(MonolithTheme.Colors.borderSoft).frame(height: 1),
            alignment: .bottom
        )
    }

    private func identityBlock(_ agent: Agent) -> some View {
        HStack(spacing: MonolithTheme.Spacing.lg) {
            AgentAvatar(agent: agent, size: .xxl)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(agent.handle)
                        .font(MonolithFont.mono(size: 20, weight: .bold))
                        .foregroundColor(MonolithTheme.Colors.textPrimary)
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
                Text(statusLabel(for: agent.status))
                    .font(MonolithFont.mono(size: 11))
                    .foregroundColor(statusColor(for: agent.status))
            }
            Spacer()
        }
    }

    private func metaBlock(_ agent: Agent) -> some View {
        VStack(alignment: .leading, spacing: MonolithTheme.Spacing.sm) {
            sectionTitle("MEMBERSHIP")
            if let joined = agent.joinedAt {
                kv("joined", Self.dateFormatter.string(from: joined))
            }
            if agent.invitedBy != nil {
                kv("invited by", "Zay Cruz")
            }
            kv("channels", "\(agent.channelIDs.count)")
        }
    }

    private func runtimeBlock(_ agent: Agent) -> some View {
        VStack(alignment: .leading, spacing: MonolithTheme.Spacing.sm) {
            sectionTitle("RUNTIME")
            if let size = agent.instanceSize { kv("instance", size) }
            if let vcpu = agent.vcpu { kv("vcpu", "\(vcpu)") }
            if let mem = agent.memoryGB { kv("memory", "\(mem) gb") }
            if let region = agent.region { kv("region", region) }
            if let uptime = agent.uptimeSeconds { kv("uptime", Self.formatUptime(uptime)) }
        }
    }

    private func modelBlock(_ agent: Agent) -> some View {
        VStack(alignment: .leading, spacing: MonolithTheme.Spacing.sm) {
            sectionTitle("MODEL")
            if let model = agent.model { kv("provider/model", model) }
            if let tokens = agent.tokens24h {
                kv("tokens 24h", Self.numberFormatter.string(from: NSNumber(value: tokens)) ?? "\(tokens)")
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(MonolithFont.mono(size: 10, weight: .medium))
            .tracking(0.6)
            .foregroundColor(MonolithTheme.Colors.textTertiary)
    }

    private func kv(_ k: String, _ v: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(k)
                .font(MonolithFont.mono(size: 12))
                .foregroundColor(MonolithTheme.Colors.textTertiary)
            Spacer()
            Text(v)
                .font(MonolithFont.mono(size: 12))
                .foregroundColor(MonolithTheme.Colors.textPrimary)
        }
        .padding(.vertical, 2)
    }

    private func statusLabel(for status: AgentStatus) -> String {
        switch status {
        case .running: return "● running"
        case .idle:    return "○ idle"
        case .error:   return "! error"
        }
    }

    private func statusColor(for status: AgentStatus) -> Color {
        switch status {
        case .running: return MonolithTheme.Colors.statusRunning
        case .idle:    return MonolithTheme.Colors.statusIdle
        case .error:   return MonolithTheme.Colors.statusError
        }
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM dd yyyy"
        return df
    }()

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

#Preview("AgentProfileSheet — dispatch") {
    AgentProfileSheet(
        agentID: MockAgents.dispatch.id,
        agentRepo: MockAgentRepository()
    )
}
