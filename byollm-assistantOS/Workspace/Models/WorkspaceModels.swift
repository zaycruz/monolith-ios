//
//  WorkspaceModels.swift
//  Workspace
//
//  Domain models for the Monolith workspace.
//  Mirrors the shape of the Monolith Mobile Workspace API spec; mock
//  repositories produce these, view code consumes them.
//

import Foundation
import SwiftUI

// MARK: - IDs
// Typed IDs so the compiler keeps channel/workspace/etc. distinct at call sites.
struct WorkspaceID: Hashable, Codable, Identifiable {
    let value: String
    var id: String { value }
    init(_ value: String) { self.value = value }
}

struct ChannelID: Hashable, Codable, Identifiable {
    let value: String
    var id: String { value }
    init(_ value: String) { self.value = value }
}

struct DMID: Hashable, Codable, Identifiable {
    let value: String
    var id: String { value }
    init(_ value: String) { self.value = value }
}

struct MessageID: Hashable, Codable, Identifiable {
    let value: String
    var id: String { value }
    init(_ value: String) { self.value = value }
}

struct ThreadID: Hashable, Codable, Identifiable {
    let value: String
    var id: String { value }
    init(_ value: String) { self.value = value }
}

struct AgentID: Hashable, Codable, Identifiable {
    let value: String
    var id: String { value }
    init(_ value: String) { self.value = value }
}

struct HumanID: Hashable, Codable, Identifiable {
    let value: String
    var id: String { value }
    init(_ value: String) { self.value = value }
}

// MARK: - Member
/// Humans and agents are different *kinds*, not a boolean.
/// Views branch on `MemberKind` to render the right avatar and name treatment.
enum MemberKind: Equatable {
    case human(Human)
    case agent(Agent)
}

struct Member: Identifiable, Equatable {
    let kind: MemberKind

    var id: String {
        switch kind {
        case .human(let h): return "human:\(h.id.value)"
        case .agent(let a): return "agent:\(a.id.value)"
        }
    }

    var displayName: String {
        switch kind {
        case .human(let h): return h.displayName
        case .agent(let a): return a.handle
        }
    }

    var initials: String {
        switch kind {
        case .human(let h): return h.initials
        case .agent(let a): return a.initials
        }
    }

    var isAgent: Bool {
        if case .agent = kind { return true }
        return false
    }
}

// MARK: - Human
struct Human: Identifiable, Equatable {
    let id: HumanID
    let displayName: String
    let initials: String
    /// Hex color string for the avatar fill.
    let colorHex: String

    init(id: HumanID, displayName: String, initials: String, colorHex: String) {
        self.id = id
        self.displayName = displayName
        self.initials = initials
        self.colorHex = colorHex
    }
}

// MARK: - Agent
enum AgentStatus: String, Codable, Equatable {
    case running
    case idle
    case error
}

struct Agent: Identifiable, Equatable {
    let id: AgentID
    let handle: String          // e.g. "dispatch"
    let initials: String        // e.g. "dp"
    let status: AgentStatus
    let template: String?       // e.g. "researcher"
    let joinedAt: Date?
    let invitedBy: HumanID?
    let channelIDs: [ChannelID]
    let instanceSize: String?   // e.g. "m8g.medium"
    let vcpu: Int?
    let memoryGB: Int?
    let region: String?         // e.g. "us-east-4"
    let uptimeSeconds: Int?
    let model: String?          // e.g. "anthropic claude-opus-4-6"
    let tokens24h: Int?

    init(
        id: AgentID,
        handle: String,
        initials: String,
        status: AgentStatus,
        template: String? = nil,
        joinedAt: Date? = nil,
        invitedBy: HumanID? = nil,
        channelIDs: [ChannelID] = [],
        instanceSize: String? = nil,
        vcpu: Int? = nil,
        memoryGB: Int? = nil,
        region: String? = nil,
        uptimeSeconds: Int? = nil,
        model: String? = nil,
        tokens24h: Int? = nil
    ) {
        self.id = id
        self.handle = handle
        self.initials = initials
        self.status = status
        self.template = template
        self.joinedAt = joinedAt
        self.invitedBy = invitedBy
        self.channelIDs = channelIDs
        self.instanceSize = instanceSize
        self.vcpu = vcpu
        self.memoryGB = memoryGB
        self.region = region
        self.uptimeSeconds = uptimeSeconds
        self.model = model
        self.tokens24h = tokens24h
    }
}

// MARK: - Workspace
struct Workspace: Identifiable, Equatable {
    let id: WorkspaceID
    let name: String
    let channels: [Channel]
    let dms: [DirectMessage]

    init(id: WorkspaceID, name: String, channels: [Channel], dms: [DirectMessage]) {
        self.id = id
        self.name = name
        self.channels = channels
        self.dms = dms
    }
}

// MARK: - Channel
struct Channel: Identifiable, Equatable {
    let id: ChannelID
    let name: String        // e.g. "client-ops" (no "#")
    let unread: Int
    let topic: String?
    let memberCount: Int

    init(id: ChannelID, name: String, unread: Int, topic: String? = nil, memberCount: Int = 0) {
        self.id = id
        self.name = name
        self.unread = unread
        self.topic = topic
        self.memberCount = memberCount
    }
}

// MARK: - Direct Message
struct DirectMessage: Identifiable, Equatable {
    let id: DMID
    let counterpart: Member
    let unread: Int

    init(id: DMID, counterpart: Member, unread: Int) {
        self.id = id
        self.counterpart = counterpart
        self.unread = unread
    }
}

// MARK: - Message
struct WorkspaceMessage: Identifiable, Equatable {
    let id: MessageID
    let author: Member
    let timestamp: Date
    let text: String
    /// Rendered BEFORE the text body, inline in the message row.
    let toolCalls: [ToolCall]
    let reactions: [Reaction]
    let thread: ThreadSummary?
    /// True if this message is a follow-up from the same author within a short
    /// window (renders without avatar / header). Computed by the repo, not the view.
    let collapsed: Bool

    init(
        id: MessageID,
        author: Member,
        timestamp: Date,
        text: String,
        toolCalls: [ToolCall] = [],
        reactions: [Reaction] = [],
        thread: ThreadSummary? = nil,
        collapsed: Bool = false
    ) {
        self.id = id
        self.author = author
        self.timestamp = timestamp
        self.text = text
        self.toolCalls = toolCalls
        self.reactions = reactions
        self.thread = thread
        self.collapsed = collapsed
    }
}

// MARK: - ToolCall
enum ToolCallStatus: String, Equatable {
    case ok
    case err
    case running
}

struct ToolCall: Identifiable, Equatable {
    let id: String
    let name: String            // e.g. "slack.read_channel"
    /// Ordered arg list. Using [(String, String)] for stable display; Dict would reorder.
    let args: [(String, String)]
    let status: ToolCallStatus
    let durationMs: Int?
    let resultSummary: String?

    init(
        id: String,
        name: String,
        args: [(String, String)],
        status: ToolCallStatus,
        durationMs: Int? = nil,
        resultSummary: String? = nil
    ) {
        self.id = id
        self.name = name
        self.args = args
        self.status = status
        self.durationMs = durationMs
        self.resultSummary = resultSummary
    }

    static func == (lhs: ToolCall, rhs: ToolCall) -> Bool {
        guard lhs.id == rhs.id,
              lhs.name == rhs.name,
              lhs.status == rhs.status,
              lhs.durationMs == rhs.durationMs,
              lhs.resultSummary == rhs.resultSummary,
              lhs.args.count == rhs.args.count
        else { return false }
        for (a, b) in zip(lhs.args, rhs.args) where a != b { return false }
        return true
    }
}

// MARK: - Reaction
/// Reactions are *symbol-based glyphs*, not emoji.
enum ReactionSymbol: String, CaseIterable, Equatable {
    case ack   = "✓"
    case flag  = "!"
    case ask   = "?"
    case veto  = "✗"
    case retry = "↻"
    case plus  = "+"
}

struct Reaction: Identifiable, Equatable {
    var id: String { symbol.rawValue }
    let symbol: ReactionSymbol
    let count: Int
    let viewerReacted: Bool

    init(symbol: ReactionSymbol, count: Int, viewerReacted: Bool = false) {
        self.symbol = symbol
        self.count = count
        self.viewerReacted = viewerReacted
    }
}

// MARK: - Thread
struct ThreadSummary: Equatable {
    let id: ThreadID
    let replyCount: Int
    /// Avatars of participants to stack on the thread link.
    let participants: [Member]

    init(id: ThreadID, replyCount: Int, participants: [Member]) {
        self.id = id
        self.replyCount = replyCount
        self.participants = participants
    }
}

struct MessageThread: Identifiable, Equatable {
    var id: ThreadID { summary.id }
    let summary: ThreadSummary
    let parent: WorkspaceMessage
    let replies: [WorkspaceMessage]

    init(summary: ThreadSummary, parent: WorkspaceMessage, replies: [WorkspaceMessage]) {
        self.summary = summary
        self.parent = parent
        self.replies = replies
    }
}

// MARK: - Realtime events
enum WorkspaceEvent: Equatable {
    case messageCreated(channelID: ChannelID, message: WorkspaceMessage)
    case messageUpdated(channelID: ChannelID, message: WorkspaceMessage)
    case reactionAdded(messageID: MessageID, symbol: ReactionSymbol)
    case reactionRemoved(messageID: MessageID, symbol: ReactionSymbol)
    case agentStatusChanged(agentID: AgentID, status: AgentStatus)
    case threadReply(threadID: ThreadID, message: WorkspaceMessage)
}

// MARK: - Invite spec
struct AgentInviteSpec: Equatable {
    let template: String      // researcher, engineer, operator, blank
    let instanceSize: String  // m8g.small, m8g.medium, m8g.large
    let channelIDs: [ChannelID]
    let name: String?

    init(template: String, instanceSize: String, channelIDs: [ChannelID], name: String? = nil) {
        self.template = template
        self.instanceSize = instanceSize
        self.channelIDs = channelIDs
        self.name = name
    }
}

// MARK: - Activity
/// The kind of event surfaced in the Activity tab. Keep this small and
/// explicit — the UI branches on `kind` to decide how to render the row
/// (glyph, verb phrasing, tappability).
enum ActivityKind: String, Equatable {
    case mention          // actor mentioned the viewer (@you)
    case flag             // actor flagged / raised an alert
    case threadReply      // new reply in a thread the viewer participates in
    case agentCompleted   // agent finished a task / draft
    case agentStatus      // agent status change (e.g. completed recon)
}

/// A single item in the Activity feed.
///
/// `target` is a human-readable label for the origin (e.g. "#client-ops",
/// "thread: morning IWP", "DM: dispatch"). Navigation linkage is optional
/// — a nil `channelID`/`threadID`/`dmID` renders as non-navigable.
struct ActivityEvent: Identifiable, Equatable {
    let id: String
    let kind: ActivityKind
    let actor: Member
    let target: String
    let summary: String
    let timestamp: Date
    let channelID: ChannelID?
    let threadID: ThreadID?
    let dmID: DMID?

    init(
        id: String,
        kind: ActivityKind,
        actor: Member,
        target: String,
        summary: String,
        timestamp: Date,
        channelID: ChannelID? = nil,
        threadID: ThreadID? = nil,
        dmID: DMID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.actor = actor
        self.target = target
        self.summary = summary
        self.timestamp = timestamp
        self.channelID = channelID
        self.threadID = threadID
        self.dmID = dmID
    }
}

// MARK: - Notification
struct WorkspaceNotification: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    let timestamp: Date

    init(id: String, title: String, body: String, timestamp: Date) {
        self.id = id
        self.title = title
        self.body = body
        self.timestamp = timestamp
    }
}
