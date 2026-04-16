//
//  YouTabView.swift
//  Workspace
//
//  Tab screen — signed-in user's profile. Reads the Clerk user via the
//  environment-injected `Clerk` instance, shows initials / display name /
//  email, and a sign-out button that calls `Clerk.shared.signOut()`.
//

import SwiftUI
import ClerkKit

struct YouTabView: View {
    @Environment(Clerk.self) private var clerk

    @State private var signingOut: Bool = false
    @State private var signOutError: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: MonolithTheme.Spacing.xl) {
                    profileCard
                    settingsSection
                    signOutButton
                    if let msg = signOutError {
                        Text(msg)
                            .font(MonolithFont.mono(size: 11))
                            .foregroundColor(MonolithTheme.Colors.statusError)
                            .padding(.horizontal, MonolithTheme.Spacing.lg)
                    }
                    Spacer().frame(height: MonolithTheme.Spacing.xxxl)
                }
                .padding(.top, MonolithTheme.Spacing.lg)
            }
        }
        .background(MonolithTheme.Colors.bgBase.ignoresSafeArea())
    }

    // MARK: header
    private var header: some View {
        HStack(spacing: MonolithTheme.Spacing.sm) {
            Text("YOU")
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

    // MARK: profile card — avatar + name + email
    private var profileCard: some View {
        HStack(alignment: .center, spacing: MonolithTheme.Spacing.lg) {
            avatar
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(MonolithFont.sans(size: 18, weight: .bold))
                    .foregroundColor(MonolithTheme.Colors.textPrimary)
                Text(email)
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
                .font(MonolithFont.mono(size: 10, weight: .medium))
                .tracking(0.6)
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
                .font(MonolithFont.mono(size: 10, weight: .medium))
                .foregroundColor(MonolithTheme.Colors.textMuted)
        }
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.vertical, MonolithTheme.Spacing.md)
        .background(MonolithTheme.Colors.bgSurface)
    }

    // MARK: sign-out
    private var signOutButton: some View {
        Button(action: signOut) {
            Text(signingOut ? "Signing out…" : "Sign out")
                .font(MonolithFont.mono(size: 12, weight: .bold))
                .tracking(0.72)
                .foregroundColor(MonolithTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, MonolithTheme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: MonolithTheme.Radius.md)
                        .stroke(MonolithTheme.Colors.borderStrong, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(signingOut)
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.top, MonolithTheme.Spacing.lg)
    }

    private func signOut() {
        signingOut = true
        signOutError = nil
        Task { @MainActor in
            defer { signingOut = false }
            do {
                try await Clerk.shared.signOut()
            } catch {
                self.signOutError = "Sign out failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: Clerk user facades
    private var displayName: String {
        let first = clerk.user?.firstName ?? ""
        let last = clerk.user?.lastName ?? ""
        let full = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        if !full.isEmpty { return full }
        if let uname = clerk.user?.username, !uname.isEmpty { return uname }
        if !email.isEmpty && email != "—" { return email }
        return "Signed-in user"
    }

    private var email: String {
        clerk.user?.primaryEmailAddress?.emailAddress ?? "—"
    }

    private var initials: String {
        let f = (clerk.user?.firstName ?? "").first.map(String.init) ?? ""
        let l = (clerk.user?.lastName ?? "").first.map(String.init) ?? ""
        let combined = (f + l).uppercased()
        if !combined.isEmpty { return combined }
        if let e = clerk.user?.primaryEmailAddress?.emailAddress,
           let c = e.first {
            return String(c).uppercased()
        }
        return "·"
    }
}
