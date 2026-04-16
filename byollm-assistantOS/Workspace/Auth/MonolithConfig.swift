//
//  MonolithConfig.swift
//  byollm-assistantOS
//
//  Single source of truth for environment-level configuration
//  (auth keys, API endpoints). Keep this as plain Swift constants —
//  no Info.plist or build-setting indirection.
//

import Foundation

enum MonolithConfig {
    /// Clerk publishable key (live). Frontend API host is derived from
    /// this key by the Clerk SDK.
    static let clerkPublishableKey = "pk_live_Y2xlcmsudGhpc2lzbW9ub2xpdGguY29tJA"

    /// Fleet control-plane REST base URL (reserved for Pass 2 — not used
    /// while the workspace UI is on mocks).
    static let fleetAPIBaseURL = URL(string: "https://api.fleetos.raavasolutions.com")!

    /// Fleet realtime WebSocket base URL (reserved for Pass 2).
    static let fleetWSBaseURL = URL(string: "wss://api.fleetos.raavasolutions.com")!
}
