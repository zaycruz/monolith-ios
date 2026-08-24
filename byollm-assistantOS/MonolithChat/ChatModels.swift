//
//  ChatModels.swift
//  byollm-assistantOS
//
//  Domain models for the Monolith Chat app.
//

import Foundation
import SwiftUI

// MARK: - Chat

/// One assistant reply block — matches the design's text/code split.
enum MessageBlock: Identifiable, Equatable {
    case text(String)
    case code(lang: String, text: String)
    case tool(ToolCallBlock)

    var id: String {
        switch self {
        case .text(let t): return "t-\(t.hashValue)"
        case .code(let lang, let t): return "c-\(lang)-\(t.hashValue)"
        case .tool(let tool): return "tool-\(tool.id)"
        }
    }
}

enum ToolCallStatus: Equatable {
    case running, succeeded, failed, cancelled
}

struct ToolCallBlock: Identifiable, Equatable {
    let id: String
    var name: String
    var input: String
    var output: String
    var status: ToolCallStatus
}

enum ReasoningEffort: String, CaseIterable, Identifiable {
    case minimal, low, medium, high, xhigh

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minimal: return "Minimal"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .xhigh: return "Extra high"
        }
    }
}

enum MessageRole: Equatable {
    case user
    case assistant
}

struct ThreadMessage: Identifiable, Equatable {
    let id = UUID()
    var role: MessageRole
    /// User text (role == .user).
    var text: String = ""
    /// Assistant blocks (role == .assistant), parsed from rawStream.
    var blocks: [MessageBlock] = []
    /// Raw accumulated assistant text during streaming — blocks are
    /// parsed from this so partial code fences never get corrupted. It is
    /// reset after each inline tool event so text and tools retain order.
    var rawStream: String = ""
    var textSegmentStart = 0
    var streaming: Bool = false
}

struct Chat: Identifiable, Equatable {
    let id: Int
    var agentSessionId = UUID()
    var runtime: AgentRuntime = .pi
    var title: String
    var time: String
    var messages: [ThreadMessage] = []
}


struct AgentRuntime: Identifiable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static let pi = AgentRuntime(rawValue: "pi")
    static let ohMyPi = AgentRuntime(rawValue: "oh-my-pi")

    var id: String { rawValue }

    var title: String {
        switch rawValue {
        case Self.pi.rawValue: return "Pi"
        case Self.ohMyPi.rawValue: return "Oh My Pi"
        default:
            return rawValue
                .split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == "." })
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
    }
}

struct HarnessDescriptor: Identifiable, Equatable, Sendable {
    let runtime: AgentRuntime
    let name: String
    let available: Bool
    let model: String
    let unavailableReason: String?

    var id: String { runtime.rawValue }

    static let builtIns = [
        HarnessDescriptor(runtime: .pi, name: "Pi", available: true, model: "pi-agent", unavailableReason: nil),
        HarnessDescriptor(runtime: .ohMyPi, name: "Oh My Pi", available: true, model: "oh-my-pi", unavailableReason: nil),
    ]
}

// MARK: - Server (vLLM)

enum ServerStatus: Equatable {
    case online, testing, offline, unknown

    var dotColor: SwiftUI.Color {
        switch self {
        case .online: return ChatTheme.online
        case .testing: return ChatTheme.testing
        case .offline: return ChatTheme.offline
        case .unknown: return ChatTheme.unknown
        }
    }

    var label: String {
        switch self {
        case .online: return "Connected"
        case .testing: return "Testing…"
        case .offline: return "Unreachable"
        case .unknown: return "Not tested"
        }
    }
}

struct LLMServer: Identifiable, Equatable {
    let id: Int
    var name: String
    var url: String
    var active: Bool
    var status: ServerStatus
    var apiToken: String? = nil
}

// MARK: - Model

struct ChatModel: Identifiable, Equatable {
    var id: String { name }
    var name: String
    var meta: String
    var runtime: AgentRuntime? = nil
}

// MARK: - Connection

struct AppConnection: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var name: String
    var desc: String
    var account: String
    var connected: Bool
    var installationRequired: Bool? = nil
    var installationURL: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, account, connected
        case desc = "description"
        case installationRequired = "installation_required"
        case installationURL = "installation_url"
    }

    var initial: String { String(name.prefix(1)) }
}

// MARK: - Project

struct ChatProject: Identifiable, Equatable {
    let id: Int
    var name: String
    var desc: String
    var files: Int
    var updated: String
    var chatIds: [Int]
    var repo: String?
}
