//
//  AuthGatedRootView.swift
//  byollm-assistantOS
//
//  Routes between the signed-out `SignInView` and the signed-in
//  `WorkspaceRootView`. While Clerk is still loading its initial
//  client/environment state, a brief splash is shown so there is no
//  flash of the sign-in screen for already-authenticated users.
//

import SwiftUI
import ClerkKit

struct AuthGatedRootView: View {
    @Environment(Clerk.self) private var clerk

    var body: some View {
        Group {
            if clerk.isLoaded {
                if clerk.user != nil {
                    // Signed-in: build the live-agent / mock-everything-else
                    // repo set. The factory pulls tokens lazily from Clerk,
                    // so this closure runs once per sign-in and the tokens
                    // themselves are never held here.
                    let repos = LiveRepositoryFactory.signedIn()
                    WorkspaceRootView(
                        workspaceRepo: repos.workspaceRepo,
                        conversationRepo: repos.conversationRepo,
                        messageRepo: repos.messageRepo,
                        realtimeRepo: repos.realtimeRepo,
                        agentRepo: repos.agentRepo,
                        notificationRepo: repos.notificationRepo,
                        activityRepo: repos.activityRepo
                    )
                } else {
                    SignInView()
                }
            } else {
                AuthSplashView()
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// Shown while Clerk is loading its initial state. Void background
/// with the brand slit mark so there is no white flash on cold start.
private struct AuthSplashView: View {
    var body: some View {
        ZStack {
            MonolithTheme.Colors.bgBase
                .ignoresSafeArea()

            // Brand slit is always snow — blue/violet/teal are reserved for
            // the footer gradient accent bar only, not functional UI.
            RoundedRectangle(cornerRadius: MonolithTheme.Radius.xs)
                .fill(MonolithTheme.Colors.textPrimary)
                .frame(width: 3, height: 56)
        }
    }
}
