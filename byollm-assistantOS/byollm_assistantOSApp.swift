//
//  byollm_assistantOSApp.swift
//  byollm-assistantOS
//
//  Created by master on 11/16/25.
//

import SwiftUI
import ClerkKit

@main
struct byollm_assistantOSApp: App {
    init() {
        ClerkBootstrap.configure()
    }

    var body: some Scene {
        WindowGroup {
            AuthGatedRootView()
                .environment(Clerk.shared)
        }
    }
}
