//
//  YouTabView.swift
//  Workspace
//
//  Tab screen — local profile. Reads the device-local personalization
//  profile (name / nickname) from `PersonalizationStore` and shows a
//  settings placeholder. No account or credentialing — the app is
//  single-user and personal.
//

import SwiftUI

struct YouTabView: View {
    @State private var settings = PersonalizationStore().load()

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: MonolithTheme.Spacing.xl) {
                    profileCard
                    settingsSection
                    Spacer().frame(height: MonolithTheme.Spacing.xxxl)
                }
                .padding(.top, MonolithTheme.Spacing.lg)
            }
        }
        .background(MonolithTheme.Colors.bgBase.ignoresSafeArea())
    }

    // MARK: header — large IBM Plex Sans title matching the v0.3 Activity/DMs pattern
    private var header: some View {
        HStack {
            Text("You")
                .font(MonolithFont.sans(size: 28, weight: .semibold))
                .foregroundColor(MonolithTheme.Colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.top, MonolithTheme.Spacing.lg)
        .padding(.bottom, MonolithTheme.Spacing.sm)
    }

    // MARK: profile card — avatar + name + nickname
    private var profileCard: some View {
        HStack(alignment: .center, spacing: MonolithTheme.Spacing.lg) {
            avatar
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(MonolithFont.sans(size: 18, weight: .bold))
                    .foregroundColor(MonolithTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(MonolithFont.mono(size: 12))
                    .foregroundColor(MonolithTheme.Colors.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, MonolithTheme.Spacing.lg)
    }

    /// Human-circle avatar with initials, matching the brand rule that
    /// humans render as circles (agents square, with slit).
    private var avatar: some View {
        Circle()
            .fill(MonolithTheme.Colors.bgElevated)
            .overlay(
                Text(initials)
                    .font(MonolithFont.sans(size: 20, weight: .medium))
                    .foregroundColor(MonolithTheme.Colors.textPrimary)
            )
            .overlay(
                Circle().stroke(MonolithTheme.Colors.borderStrong, lineWidth: 1)
            )
            .frame(width: 56, height: 56)
    }

    // MARK: settings placeholder
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SETTINGS")
                .font(MonolithFont.sans(size: 11, weight: .semibold))
                .tracking(0.3)
                .foregroundColor(MonolithTheme.Colors.textTertiary)
                .padding(.horizontal, MonolithTheme.Spacing.lg)
                .padding(.bottom, MonolithTheme.Spacing.sm)
            settingsRow(label: "More settings", value: "coming soon")
        }
    }

    private func settingsRow(label: String, value: String) -> some View {
        HStack(spacing: MonolithTheme.Spacing.md) {
            Text(label)
                .font(MonolithFont.sans(size: 15))
                .foregroundColor(MonolithTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(MonolithFont.sans(size: 12))
                .foregroundColor(MonolithTheme.Colors.textMuted)
        }
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.vertical, MonolithTheme.Spacing.md)
        .background(Color.white.opacity(0.02))
    }

    // MARK: local profile facades
    private var displayName: String {
        if !settings.fullName.isEmpty { return settings.fullName }
        if !settings.nickname.isEmpty { return settings.nickname }
        return "You"
    }

    private var subtitle: String {
        if !settings.nickname.isEmpty { return settings.nickname }
        return "Local profile"
    }

    private var initials: String {
        let words = settings.fullName.split(separator: " ")
        let f = words.first?.first.map(String.init) ?? ""
        let l = words.dropFirst().first?.first.map(String.init) ?? ""
        let combined = (f + l).uppercased()
        if !combined.isEmpty { return combined }
        if let n = settings.nickname.first { return String(n).uppercased() }
        return "·"
    }
}
