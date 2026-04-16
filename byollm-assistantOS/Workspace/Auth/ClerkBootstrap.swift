//
//  ClerkBootstrap.swift
//  byollm-assistantOS
//
//  Configures the Clerk iOS SDK at app launch. Called exactly once
//  from byollm_assistantOSApp.init() before the first View is built.
//
//  `Clerk.configure(publishableKey:)` is a static call that builds and
//  stores the shared instance and automatically kicks off the initial
//  client/environment refresh — no explicit `load()` is required.
//

import Foundation
import ClerkKit

enum ClerkBootstrap {
    /// Configures `Clerk.shared` with the project's publishable key.
    /// Safe to call once from the App init; subsequent calls are a no-op
    /// at the SDK level.
    @MainActor
    static func configure() {
        Clerk.configure(publishableKey: MonolithConfig.clerkPublishableKey)
    }
}
