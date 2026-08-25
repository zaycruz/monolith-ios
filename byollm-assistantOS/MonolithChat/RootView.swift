//
//  RootView.swift
//  byollm-assistantOS
//
//  Root router — renders the active screen plus the drawer, model sheet,
//  connections sheet, and new-project overlay. Drawer and sheets slide
//  over the base screen, matching the design's overlay behavior.
//

import SwiftUI
import UIKit

struct RootView: View {
    @StateObject private var store = AppStore()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var mode: ChatTheme.Mode { store.mode }

    var body: some View {
        ZStack {
            MonolithBackdrop(mode: mode)

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

            // Add connection sheet
            if store.addConnOpen {
                sheetBackdrop { store.dismissAddConnection() }
                VStack {
                    Spacer()
                    AddConnectionSheet(store: store, mode: mode)
                }
                .transition(.move(edge: .bottom))
                .zIndex(9)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.30, extraBounce: 0.02), value: store.drawer)
        .animation(reduceMotion ? nil : .snappy(duration: 0.30, extraBounce: 0.02), value: store.addConnOpen)
        .animation(reduceMotion ? nil : .snappy(duration: 0.30, extraBounce: 0.02), value: store.newProjOpen)
        .simultaneousGesture(drawerGesture)
        .onChange(of: store.drawer) { _, isOpen in
            if isOpen {
                dismissAppKeyboard()
                store.dismissReasoning()
            }
        }
        .sheet(isPresented: $store.modelSheet) {
            ModelSheet(store: store, mode: mode)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
                .presentationBackground(.ultraThinMaterial)
        }
        .accessibilityAction(.escape) {
            if store.addConnOpen {
                store.dismissAddConnection()
            } else if store.drawer {
                store.closeDrawer()
            } else if store.newProjOpen {
                store.closeNewProject()
            }
        }
        .preferredColorScheme(store.isDark ? .dark : .light)
    }

    private var drawerGesture: some Gesture {
        DragGesture(minimumDistance: 16, coordinateSpace: .global)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) * 1.35 else { return }

                if store.drawer {
                    if horizontal < -64 { store.closeDrawer() }
                } else if value.startLocation.x <= 28,
                          horizontal > 64,
                          !store.modelSheet,
                          !store.addConnOpen,
                          !store.newProjOpen {
                    store.openDrawer()
                }
            }
    }

    private func sheetBackdrop(_ onTap: @escaping () -> Void) -> some View {
        ChatTheme.scrim(mode)
            .ignoresSafeArea()
            .onTapGesture {
                dismissAppKeyboard()
                store.dismissReasoning()
                onTap()
            }
            .zIndex(8)
    }
}

@MainActor
func dismissAppKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

#Preview {
    RootView()
}
