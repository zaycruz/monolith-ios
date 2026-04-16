//
//  InviteAgentSheet.swift
//  Workspace
//
//  Screen 06 — Launch a new agent (aka LaunchAgentSheet). Name retained
//  to avoid touching the shell wiring.
//
//  v0.3 layout:
//  - Glass nav with ✕ dismiss, title "Launch agent" (centered, mono)
//  - Hero: large title "Spin up a new agent." + subtitle description
//  - TEMPLATE 2×2 glass-card grid (selected = inner fill + border)
//  - SIZE list with Graviton4 m8g naming + pricing
//  - NAME input: glass field with `agent /` prefix + BlinkingCursor
//  - Snow-white CTA "Launch agent"
//

import SwiftUI

@MainActor
final class LaunchAgentViewModel: ObservableObject {
    @Published var template: String = "researcher"
    @Published var instanceSize: String = "m8g.medium"
    @Published var selectedChannelIDs: Set<ChannelID>
    @Published var name: String = ""
    @Published var submitting: Bool = false
    @Published var errorMessage: String?

    var channels: [Channel]
    private let agentRepo: AgentRepository

    init(
        channels: [Channel],
        defaultChannelIDs: Set<ChannelID>,
        agentRepo: AgentRepository
    ) {
        self.channels = channels
        self.selectedChannelIDs = defaultChannelIDs
        self.agentRepo = agentRepo
    }

    func submit() async -> Agent? {
        submitting = true
        defer { submitting = false }
        let spec = AgentInviteSpec(
            template: template,
            instanceSize: instanceSize,
            channelIDs: Array(selectedChannelIDs),
            name: name.isEmpty ? nil : name
        )
        do {
            return try await agentRepo.invite(spec)
        } catch {
            errorMessage = "\(error)"
            return nil
        }
    }
}

/// Kept the `InviteAgentSheet` name so the existing shell can present it
/// without touching WorkspaceTabShell. Behaves like LaunchAgentSheet.
struct InviteAgentSheet: View {
    @StateObject private var viewModel: LaunchAgentViewModel
    @FocusState private var nameFocused: Bool
    var onClose: (() -> Void)?
    var onInvited: ((Agent) -> Void)?

    init(
        channels: [Channel] = MockChannels.all,
        defaultChannelIDs: Set<ChannelID> = [
            MockChannels.general.id,
            MockChannels.clientOps.id
        ],
        agentRepo: AgentRepository,
        onClose: (() -> Void)? = nil,
        onInvited: ((Agent) -> Void)? = nil
    ) {
        self._viewModel = StateObject(
            wrappedValue: LaunchAgentViewModel(
                channels: channels,
                defaultChannelIDs: defaultChannelIDs,
                agentRepo: agentRepo
            )
        )
        self.onClose = onClose
        self.onInvited = onInvited
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView {
                VStack(alignment: .leading, spacing: MonolithTheme.Spacing.xl) {
                    hero
                    templateSection
                    sizeSection
                    nameSection
                    launchButton
                    Spacer().frame(height: MonolithTheme.Spacing.xxl)
                }
                .padding(.horizontal, MonolithTheme.Spacing.lg)
                .padding(.top, MonolithTheme.Spacing.md)
            }
        }
        .background(MonolithTheme.Colors.bgBase.ignoresSafeArea())
    }

    // MARK: nav
    private var navBar: some View {
        GlassNavBar(
            leading: { GlassNavCloseButton(onTap: { onClose?() }) },
            title: {
                GlassNavTitle(title: "Launch agent", titleIsMono: true)
            }
        )
    }

    // MARK: hero
    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Spin up a new agent.")
                .font(MonolithFont.sans(size: 26, weight: .semibold))
                .foregroundColor(MonolithTheme.Colors.textPrimary)
            Text("Choose a template, pick a size, give it a name. Your agent joins the workspace in seconds.")
                .font(MonolithFont.sans(size: 14))
                .foregroundColor(MonolithTheme.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: template grid
    private struct TemplateOption: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let systemImage: String
    }

    private let templates: [TemplateOption] = [
        .init(id: "researcher", title: "researcher", subtitle: "reads, summarizes, investigates", systemImage: "magnifyingglass"),
        .init(id: "engineer",   title: "engineer",   subtitle: "builds, ships, reviews code",     systemImage: "hammer"),
        .init(id: "operator",   title: "operator",   subtitle: "triages, coordinates, reports",   systemImage: "flag"),
        .init(id: "blank",      title: "blank",      subtitle: "starts empty; you scope it",      systemImage: "square.dashed")
    ]

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: MonolithTheme.Spacing.md) {
            sectionTitle("TEMPLATE")
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
                spacing: 10
            ) {
                ForEach(templates) { t in
                    templateCard(t)
                }
            }
        }
    }

    private func templateCard(_ t: TemplateOption) -> some View {
        let selected = viewModel.template == t.id
        return Button(action: { viewModel.template = t.id }) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: t.systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(selected
                                     ? MonolithTheme.Colors.textPrimary
                                     : MonolithTheme.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(selected ? 0.06 : 0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.title)
                        .font(MonolithFont.mono(size: 14, weight: .semibold))
                        .foregroundColor(MonolithTheme.Colors.textPrimary)
                    Text(t.subtitle)
                        .font(MonolithFont.sans(size: 12))
                        .foregroundColor(MonolithTheme.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(MonolithTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .background(selected
                        ? Color.white.opacity(0.06)
                        : MonolithTheme.Glass.bg)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selected
                            ? Color.white.opacity(0.2)
                            : MonolithTheme.Glass.border,
                            lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: size list
    private struct SizeOption: Identifiable {
        let id: String
        let label: String
        let spec: String
        let price: String
    }

    private let sizes: [SizeOption] = [
        .init(id: "m8g.small",  label: "m8g.small",  spec: "Graviton4 · 1 vcpu · 2 gb",  price: "$18/mo"),
        .init(id: "m8g.medium", label: "m8g.medium", spec: "Graviton4 · 2 vcpu · 4 gb",  price: "$36/mo"),
        .init(id: "m8g.large",  label: "m8g.large",  spec: "Graviton4 · 4 vcpu · 8 gb",  price: "$72/mo"),
    ]

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: MonolithTheme.Spacing.sm) {
            sectionTitle("SIZE")
            VStack(spacing: 0) {
                ForEach(sizes) { s in
                    sizeRow(s)
                    if s.id != sizes.last?.id {
                        Rectangle()
                            .fill(MonolithTheme.Glass.border)
                            .frame(height: 1)
                            .padding(.leading, MonolithTheme.Spacing.md)
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

    private func sizeRow(_ s: SizeOption) -> some View {
        let selected = viewModel.instanceSize == s.id
        return Button(action: { viewModel.instanceSize = s.id }) {
            HStack(spacing: MonolithTheme.Spacing.md) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(selected
                                     ? MonolithTheme.Colors.textPrimary
                                     : MonolithTheme.Colors.textMuted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.label)
                        .font(MonolithFont.mono(size: 14, weight: .semibold))
                        .foregroundColor(MonolithTheme.Colors.textPrimary)
                    Text(s.spec)
                        .font(MonolithFont.sans(size: 12))
                        .foregroundColor(MonolithTheme.Colors.textTertiary)
                }
                Spacer()
                Text(s.price)
                    .font(MonolithFont.mono(size: 13))
                    .foregroundColor(MonolithTheme.Colors.textSecondary)
            }
            .padding(MonolithTheme.Spacing.md)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: name field — glass input with `agent /` prefix + cursor
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: MonolithTheme.Spacing.sm) {
            sectionTitle("NAME")
            HStack(spacing: 4) {
                Text("agent /")
                    .font(MonolithFont.mono(size: 15, weight: .medium))
                    .foregroundColor(MonolithTheme.Colors.textTertiary)
                ZStack(alignment: .leading) {
                    if viewModel.name.isEmpty {
                        HStack(spacing: 0) {
                            BlinkingCursor()
                                .padding(.leading, 1)
                        }
                    }
                    TextField("", text: $viewModel.name)
                        .focused($nameFocused)
                        .font(MonolithFont.mono(size: 15))
                        .foregroundColor(MonolithTheme.Colors.textPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .tint(MonolithTheme.Colors.textPrimary)
                }
                Spacer()
            }
            .padding(.horizontal, MonolithTheme.Spacing.md)
            .frame(minHeight: 52)
            .background(.ultraThinMaterial)
            .background(MonolithTheme.Glass.inputFill)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(MonolithTheme.Glass.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .onTapGesture { nameFocused = true }

            Text("Leave blank to auto-generate a handle from the template.")
                .font(MonolithFont.sans(size: 12))
                .foregroundColor(MonolithTheme.Colors.textMuted)
        }
    }

    // MARK: launch CTA
    private var launchButton: some View {
        Button(action: {
            Task {
                if let agent = await viewModel.submit() {
                    onInvited?(agent)
                }
            }
        }) {
            HStack {
                Spacer()
                Text(viewModel.submitting ? "Launching…" : "Launch agent")
                    .font(MonolithFont.sans(size: 15, weight: .semibold))
                    .foregroundColor(MonolithTheme.Palette.void)
                Spacer()
            }
            .frame(minHeight: 52)
            .background(MonolithTheme.Palette.snow)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.submitting)
    }

    // MARK: helpers
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(MonolithFont.sans(size: 11, weight: .semibold))
            .tracking(0.3)
            .foregroundColor(MonolithTheme.Colors.textTertiary)
    }
}

#Preview("LaunchAgentSheet") {
    InviteAgentSheet(agentRepo: MockAgentRepository())
}
