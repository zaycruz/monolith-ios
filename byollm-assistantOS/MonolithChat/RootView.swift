//
//  RootView.swift
//  byollm-assistantOS
//
//  Root router — renders the active screen plus the drawer, model sheet,
//  connections sheet, and new-project overlay. Drawer and sheets slide
//  over the base screen, matching the design's overlay behavior.
//

import SwiftUI

struct RootView: View {
    @StateObject private var store = AppStore()
    @Environment(\.colorScheme) private var systemScheme

    private var mode: ChatTheme.Mode { store.mode }

    var body: some View {
        ZStack {
            ChatTheme.bg(mode).ignoresSafeArea()

            // Base screen
            VStack(spacing: 0) {
                switch store.screen {
                case .home:
                    HomeView(store: store, mode: mode)
                    ComposerView(store: store, mode: mode)
                case .chat:
                    ChatView(store: store, mode: mode)
                    ComposerView(store: store, mode: mode)
                case .settings:
                    SettingsView(store: store, mode: mode)
                case .connections:
                    ConnectionsView(store: store, mode: mode)
                case .chats:
                    ChatsListView(store: store, mode: mode)
                case .projects:
                    ProjectsView(store: store, mode: mode)
                case .project:
                    ProjectDetailView(store: store, mode: mode)
                }
            }

            // Drawer overlay
            if store.drawer {
                DrawerView(store: store, mode: mode)
                    .transition(.move(edge: .leading))
                    .zIndex(8)
            }

            // New project overlay (full screen)
            if store.newProjOpen {
                ChatTheme.bg(mode).ignoresSafeArea()
                NewProjectView(store: store, mode: mode)
                    .transition(.move(edge: .trailing))
                    .zIndex(7)
            }

            // Model sheet
            if store.modelSheet {
                sheetBackdrop { store.closeSheet() }
                VStack {
                    Spacer()
                    ModelSheet(store: store, mode: mode)
                }
                .transition(.move(edge: .bottom))
                .zIndex(9)
            }

            // Add connection sheet
            if store.addConnOpen {
                sheetBackdrop { store.closeAddConn() }
                VStack {
                    Spacer()
                    AddConnectionSheet(store: store, mode: mode)
                }
                .transition(.move(edge: .bottom))
                .zIndex(9)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: store.drawer)
        .animation(.easeInOut(duration: 0.22), value: store.modelSheet)
        .animation(.easeInOut(duration: 0.22), value: store.addConnOpen)
        .animation(.easeInOut(duration: 0.22), value: store.newProjOpen)
        .preferredColorScheme(store.isDark ? .dark : .light)
    }

    private func sheetBackdrop(_ onTap: @escaping () -> Void) -> some View {
        ChatTheme.scrim(mode)
            .ignoresSafeArea()
            .onTapGesture { onTap() }
            .zIndex(8)
    }
}

#Preview {
    RootView()
}
