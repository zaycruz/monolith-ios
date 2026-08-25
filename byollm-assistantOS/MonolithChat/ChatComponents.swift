//
//  ChatComponents.swift
//  byollm-assistantOS
//
//  Shared building blocks: the Monolith emblem mark, SF-symbol icon
//  helpers matching the design's icon set, and the assistant avatar.
//

import SwiftUI
import Foundation


// MARK: - Monolith emblem (4-segment geometric mark)
/// Four angular segments arranged around a central void, matching the
/// brand emblem. Drawn natively — no SVG parsing.
struct LogoMark: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        // One segment: a right-pointing chevron/arrow wedge.
        // Rotated to 4 orientations (0°, 90°, 180°, 270°).
        for i in 0..<4 {
            let seg = wedge(center: .zero, r: r)
            let angle = Angle(degrees: Double(i) * 90)
            let t = CGAffineTransform(translationX: c.x, y: c.y)
                .rotated(by: CGFloat(angle.radians))
            p.addPath(seg.applying(t))
        }
        return p
    }

    /// A single angular segment pointing +x, centred at `center`.
    private func wedge(center: CGPoint, r: CGFloat) -> Path {
        var p = Path()
        let outer = r
        let inner = r * 0.42
        let half = r * 0.52
        p.move(to: CGPoint(x: center.x + inner, y: center.y - half))
        p.addLine(to: CGPoint(x: center.x + outer, y: center.y))
        p.addLine(to: CGPoint(x: center.x + inner, y: center.y + half))
        p.addLine(to: CGPoint(x: center.x + inner * 0.4, y: center.y + half * 0.4))
        p.addLine(to: CGPoint(x: center.x + inner * 0.4, y: center.y - half * 0.4))
        p.closeSubpath()
        return p
    }
}

// MARK: - Icon helper
/// SF Symbol names matching the design's icon set.
enum ChatIcon {
    static let new = "square.and.pencil"
    static let search = "magnifyingglass"
    static let chat = "bubble.left"
    static let files = "folder"
    static let settings = "gearshape"
    static let upload = "square.and.arrow.up"
    static let plus = "plus"
    static let chevronRight = "chevron.right"
    static let chevronDown = "chevron.down"
    static let back = "chevron.left"
    static let check = "checkmark"
    static let github = "chevron.left.forwardslash.chevron.right"
}

// MARK: - Assistant avatar (emblem in rounded square)
struct AssistantAvatar: View {
    var mode: ChatTheme.Mode
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(ChatTheme.surface(mode))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ChatTheme.line(mode), lineWidth: 1))
            LogoMark()
                .fill(ChatTheme.text(mode))
                .frame(width: size * 0.46, height: size * 0.46)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Status dot
struct StatusDot: View {
    var status: ServerStatus
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(status.dotColor)
            .frame(width: size, height: size)
            .modifier(PulseModifier(active: status == .testing))
    }
}

struct PulseModifier: ViewModifier {
    var active: Bool
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .opacity(active ? (pulse ? 0.35 : 1) : 1)
            .animation(active ? .easeInOut(duration: 0.5).repeatForever() : .default, value: pulse)
            .onAppear { pulse = active }
    }
}

enum ConversationActivityState {
    case working
    case ready
}

struct ConversationActivityIndicator: View {
    let state: ConversationActivityState
    let mode: ChatTheme.Mode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch state {
            case .working where reduceMotion:
                Circle()
                    .stroke(ChatTheme.sub(mode), lineWidth: 1.5)
                    .frame(width: 11, height: 11)
            case .working:
                ProgressView()
                    .controlSize(.small)
                    .tint(ChatTheme.sub(mode))
            case .ready:
                Circle()
                    .fill(ChatTheme.online)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }
}

// MARK: - Touch interaction
struct TouchButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(
                .easeOut(duration: reduceMotion ? 0 : 0.12),
                value: configuration.isPressed
            )
    }
}

extension ButtonStyle where Self == TouchButtonStyle {
    static var touch: TouchButtonStyle { TouchButtonStyle() }
}

// MARK: - Assistant prose
struct MarkdownText: View {
    let content: String

    private var sections: [String] {
        content
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                if section == "---" || section == "⸻" {
                    Divider()
                } else if let attributed = try? AttributedString(
                    markdown: section.replacingOccurrences(of: "\n", with: "  \n")
                ) {
                    Text(attributed)
                } else {
                    Text(section)
                }
            }
        }
    }
}

// MARK: - Model selector
struct ModelSelectorButton: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode

    var body: some View {
        Button(action: { store.openSheet() }) {
            HStack(spacing: 7) {
                StatusDot(status: store.activeServer?.status ?? .unknown, size: 7)
                Text(store.activeModelShort)
                    .font(ChatFont.sans(.subheadline, weight: .bold))
                    .foregroundColor(ChatTheme.text(mode))
                    .lineLimit(1)
                Image(systemName: ChatIcon.chevronDown)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(ChatTheme.sub(mode))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .buttonStyle(.touch)
        .monolithGlass(mode: mode, cornerRadius: 22, interactive: true)
        .accessibilityLabel("Model \(store.activeModelShort)")
        .accessibilityValue(store.activeServer?.status.label ?? "No server")
        .accessibilityHint("Opens the model picker")
    }
}
