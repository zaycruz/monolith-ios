//
//  SignInView.swift
//  byollm-assistantOS
//
//  Signed-out entry screen. Uses Clerk's prebuilt ClerkKitUI `AuthView`
//  presented in a sheet, matching the Clerk iOS quickstart pattern.
//  The surrounding frame is styled with Monolith theme tokens so the
//  pre-sheet state matches the workspace aesthetic.
//

import SwiftUI
import ClerkKit
import ClerkKitUI

struct SignInView: View {
    @State private var isPresentingAuth: Bool = false

    var body: some View {
        ZStack {
            MonolithTheme.Colors.bgBase
                .ignoresSafeArea()

            VStack(spacing: MonolithTheme.Spacing.xxl) {
                Spacer()

                // Slit mark — vertical brand bar. ALWAYS snow per brand spec;
                // blue/violet/teal are reserved for the footer gradient accent
                // bar and must not appear on functional UI.
                RoundedRectangle(cornerRadius: MonolithTheme.Radius.xs)
                    .fill(MonolithTheme.Colors.textPrimary)
                    .frame(width: 3, height: 56)

                VStack(spacing: MonolithTheme.Spacing.sm) {
                    Text("Monolith")
                        .font(MonolithFont.mono(size: 28, weight: .bold))
                        .foregroundStyle(MonolithTheme.Colors.textPrimary)

                    Text("Sign in to your workspace")
                        .font(MonolithFont.sans(size: 15, weight: .regular))
                        .foregroundStyle(MonolithTheme.Colors.textTertiary)
                }

                Spacer()

                // Primary CTA matches the `.invite-cta` pattern in
                // `design/mockups-v0.3.html`: snow background, void text,
                // JetBrains Mono bold, letter-spaced.
                Button {
                    isPresentingAuth = true
                } label: {
                    Text("Continue")
                        .font(MonolithFont.mono(size: 12, weight: .bold))
                        .tracking(0.72) // 0.06em at 12pt
                        .foregroundStyle(MonolithTheme.Colors.bgBase)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MonolithTheme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: MonolithTheme.Radius.md)
                                .fill(MonolithTheme.Colors.textPrimary)
                        )
                }
                .padding(.horizontal, MonolithTheme.Spacing.xl)
                .padding(.bottom, MonolithTheme.Spacing.xxl)
            }
        }
        .sheet(isPresented: $isPresentingAuth) {
            AuthView()
        }
    }
}

#Preview("SignInView") {
    SignInView()
        .preferredColorScheme(.dark)
}
