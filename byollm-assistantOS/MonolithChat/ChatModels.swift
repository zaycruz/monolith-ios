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

    var id: String {
        switch self {
        case .text(let t): return "t-\(t.hashValue)"
        case .code(let lang, let t): return "c-\(lang)-\(t.hashValue)"
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
    /// parsed from this so partial code fences never get corrupted.
    var rawStream: String = ""
    var streaming: Bool = false
}

struct Chat: Identifiable, Equatable {
    let id: Int
    var title: String
    var time: String
    var messages: [ThreadMessage] = []
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
}

// MARK: - Model

struct ChatModel: Identifiable, Equatable {
    var id: String { name }
    var name: String
    var meta: String
}

// MARK: - Connection

struct AppConnection: Identifiable, Equatable {
    let id: String
    var name: String
    var desc: String
    var account: String
    var connected: Bool

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
