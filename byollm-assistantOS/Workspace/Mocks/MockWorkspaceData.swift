//
//  MockWorkspaceData.swift
//  Workspace
//
//  Deterministic fixtures that match design/mockups-v0.3.html exactly.
//  Any screen can render these and look like the mockup.
//

import Foundation

// MARK: - Fixed reference date
/// Today in the mockup is "Apr 15" — we anchor all timestamps off this date
/// so Previews and tests are stable regardless of wall clock.
enum MockClock {
    static let today: Date = {
        var c = DateComponents()
        c.year = 2026
        c.month = 4
        c.day = 15
        c.hour = 9
        c.minute = 0
        return Calendar(identifier: .gregorian).date(from: c) ?? Date()
    }()

    static func at(hour: Int, minute: Int) -> Date {
        var c = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day], from: today
        )
        c.hour = hour
        c.minute = minute
        return Calendar(identifier: .gregorian).date(from: c) ?? today
    }
}

// MARK: - Humans
enum MockHumans {
    static let zay = Human(
        id: HumanID("h_zay"),
        displayName: "Zay Cruz",
        initials: "ZC",
        colorHex: "#3B5BDB"
    )
    static let sofia = Human(
        id: HumanID("h_sofia"),
        displayName: "Sofia Chang",
        initials: "SC",
        colorHex: "#7048E8"
    )
    static let jason = Human(
        id: HumanID("h_jason"),
        displayName: "Jason Kowalski",
        initials: "JK",
        colorHex: "#0EA5E9"
    )
}

// MARK: - Agents
enum MockAgents {
    static let dispatch = Agent(
        id: AgentID("a_dispatch"),
        handle: "dispatch",
        initials: "dp",
        status: .running,
        template: "operator",
        joinedAt: {
            var c = DateComponents(); c.year = 2026; c.month = 3; c.day = 2
            return Calendar(identifier: .gregorian).date(from: c)
        }(),
        invitedBy: MockHumans.zay.id,
        channelIDs: [
            ChannelID("c_general"),
            ChannelID("c_client_ops"),
            ChannelID("c_incidents")
        ],
        instanceSize: "m8g.medium",
        vcpu: 2,
        memoryGB: 4,
        region: "us-east-4",
        uptimeSeconds: 128 * 3600 + 14 * 60, // 128h 14m
        model: "anthropic claude-opus-4-6",
        tokens24h: 184_220
    )
    static let scout = Agent(
        id: AgentID("a_scout"),
        handle: "scout",
        initials: "sc",
        status: .running
    )
    static let warden = Agent(
        id: AgentID("a_warden"),
        handle: "warden",
        initials: "wd",
        status: .running
    )
    static let pulse = Agent(
        id: AgentID("a_pulse"),
        handle: "pulse",
        initials: "pl",
        status: .running
    )
    static let herald = Agent(
        id: AgentID("a_herald"),
        handle: "herald",
        initials: "hr",
        status: .running
    )

    static let all: [Agent] = [dispatch, scout, warden, pulse, herald]
}

// MARK: - Members (helpers)
enum MockMembers {
    static let zay      = Member(kind: .human(MockHumans.zay))
    static let sofia    = Member(kind: .human(MockHumans.sofia))
    static let jason    = Member(kind: .human(MockHumans.jason))
    static let dispatch = Member(kind: .agent(MockAgents.dispatch))
    static let scout    = Member(kind: .agent(MockAgents.scout))
    static let warden   = Member(kind: .agent(MockAgents.warden))
    static let pulse    = Member(kind: .agent(MockAgents.pulse))
    static let herald   = Member(kind: .agent(MockAgents.herald))
}

// MARK: - Channels
enum MockChannels {
    static let general = Channel(
        id: ChannelID("c_general"),
        name: "general",
        unread: 0,
        topic: "Workspace-wide announcements",
        memberCount: 12
    )
    static let clientOps = Channel(
        id: ChannelID("c_client_ops"),
        name: "client-ops",
        unread: 8,
        topic: "Client operations coordination",
        memberCount: 9
    )
    static let engineering = Channel(
        id: ChannelID("c_engineering"),
        name: "engineering",
        unread: 3,
        topic: "Engineering",
        memberCount: 7
    )
    static let revops = Channel(
        id: ChannelID("c_revops"),
        name: "revops",
        unread: 0,
        topic: "Revenue operations",
        memberCount: 5
    )
    static let incidents = Channel(
        id: ChannelID("c_incidents"),
        name: "incidents",
        unread: 0,
        topic: "Production incidents",
        memberCount: 11
    )
    static let random = Channel(
        id: ChannelID("c_random"),
        name: "random",
        unread: 0,
        topic: "Off-topic",
        memberCount: 14
    )

    static let all: [Channel] = [
        general, clientOps, engineering, revops, incidents, random
    ]
}

// MARK: - DMs
enum MockDMs {
    static let zaySofia = DirectMessage(
        id: DMID("dm_zay_sofia"),
        counterpart: MockMembers.sofia,
        unread: 2
    )
    static let zayDispatch = DirectMessage(
        id: DMID("dm_zay_dispatch"),
        counterpart: MockMembers.dispatch,
        unread: 1
    )
    static let zayScout = DirectMessage(
        id: DMID("dm_zay_scout"),
        counterpart: MockMembers.scout,
        unread: 0
    )
    static let zayPulse = DirectMessage(
        id: DMID("dm_zay_pulse"),
        counterpart: MockMembers.pulse,
        unread: 0
    )
    static let zayWarden = DirectMessage(
        id: DMID("dm_zay_warden"),
        counterpart: MockMembers.warden,
        unread: 0
    )
    static let zayHerald = DirectMessage(
        id: DMID("dm_zay_herald"),
        counterpart: MockMembers.herald,
        unread: 0
    )
    static let zayJason = DirectMessage(
        id: DMID("dm_zay_jason"),
        counterpart: MockMembers.jason,
        unread: 0
    )
    static let all: [DirectMessage] = [
        zaySofia, zayDispatch, zayScout, zayPulse, zayWarden, zayHerald, zayJason
    ]
}

// MARK: - Workspace
enum MockWorkspaces {
    static let raavaOps = Workspace(
        id: WorkspaceID("w_raava_ops"),
        name: "Raava Ops",
        channels: MockChannels.all,
        dms: MockDMs.all
    )
}

// MARK: - Thread (on the dispatch overnight-triage message)
enum MockThreads {
    static let clientOpsTriageThread = ThreadSummary(
        id: ThreadID("t_triage"),
        replyCount: 3,
        participants: [MockMembers.dispatch, MockMembers.scout, MockMembers.zay]
    )
}

// MARK: - Channel messages: #client-ops (Today · Apr 15)
enum MockMessages {

    static let clientOps: [WorkspaceMessage] = [
        // 1 — 8:42 Zay
        WorkspaceMessage(
            id: MessageID("m_co_1"),
            author: MockMembers.zay,
            timestamp: MockClock.at(hour: 8, minute: 42),
            text: "morning. @dispatch what's overnight on IWP?"
        ),
        // 2 — 8:42 dispatch (tool call + triage list + thread link)
        WorkspaceMessage(
            id: MessageID("m_co_2"),
            author: MockMembers.dispatch,
            timestamp: MockClock.at(hour: 8, minute: 42),
            text:
                """
                Overnight triage for IWP:
                1. Billing sync failed at 02:14 — retrying now.
                2. 3 new leads stuck in "awaiting dispatch" > 6h.
                3. Field tech GPS offline for 2 units.
                """,
            toolCalls: [
                ToolCall(
                    id: "tc_co_2_1",
                    name: "slack.read_channel",
                    args: [
                        ("channel", "iwp-ops"),
                        ("window", "8h")
                    ],
                    status: .ok,
                    durationMs: 186,
                    resultSummary: "47 messages"
                )
            ],
            thread: MockThreads.clientOpsTriageThread
        ),
        // 3 — 8:51 Sofia
        WorkspaceMessage(
            id: MessageID("m_co_3"),
            author: MockMembers.sofia,
            timestamp: MockClock.at(hour: 8, minute: 51),
            text: "@scout Artisan JobNimbus mapping status?"
        ),
        // 4 — 8:51 scout
        WorkspaceMessage(
            id: MessageID("m_co_4"),
            author: MockMembers.scout,
            timestamp: MockClock.at(hour: 8, minute: 51),
            text: "47 of 60 custom fields mapped. Remaining 13 are client-specific; waiting on sample data from @sofia."
        ),
        // 5 — 8:52 Sofia (collapsed — within 2 min of msg 3, same author)
        WorkspaceMessage(
            id: MessageID("m_co_5"),
            author: MockMembers.sofia,
            timestamp: MockClock.at(hour: 8, minute: 52),
            text: "I'll follow up with him and drop a CSV in here this afternoon.",
            collapsed: true
        ),
        // 6 — 8:54 warden
        WorkspaceMessage(
            id: MessageID("m_co_6"),
            author: MockMembers.warden,
            timestamp: MockClock.at(hour: 8, minute: 54),
            text:
                """
                Overnight recon: 12 findings across 4 tenants. Nothing above medium severity. Full report in recon log.
                """,
            reactions: [
                Reaction(symbol: .flag, count: 1, viewerReacted: false)
            ]
        )
    ]

    // MARK: DM: Zay ↔ dispatch (2:02 – 2:05 PM)
    static let zayDispatchDM: [WorkspaceMessage] = [
        WorkspaceMessage(
            id: MessageID("m_dm_1"),
            author: MockMembers.zay,
            timestamp: MockClock.at(hour: 14, minute: 2),
            text: "Greg asked about tax-loss harvesting this year — anything actionable?"
        ),
        WorkspaceMessage(
            id: MessageID("m_dm_2"),
            author: MockMembers.dispatch,
            timestamp: MockClock.at(hour: 14, minute: 3),
            text: "Looking at his holdings: MUB and VCIT are both at losses since purchase. Rough harvestable amount ~$4,200."
        ),
        WorkspaceMessage(
            id: MessageID("m_dm_3"),
            author: MockMembers.dispatch,
            timestamp: MockClock.at(hour: 14, minute: 4),
            text:
                """
                Wash-sale check: no replacement buys within 30 days. Clean to sell both lots.
                """,
            toolCalls: [
                ToolCall(
                    id: "tc_dm_3_1",
                    name: "portfolio.wash_sale_check",
                    args: [
                        ("accountId", "acc_greg_01"),
                        ("tickers", "MUB,VCIT"),
                        ("windowDays", "30")
                    ],
                    status: .ok,
                    durationMs: 92,
                    resultSummary: "no conflicts"
                )
            ]
        ),
        WorkspaceMessage(
            id: MessageID("m_dm_4"),
            author: MockMembers.dispatch,
            timestamp: MockClock.at(hour: 14, minute: 5),
            text:
                """
                Draft reply: "Greg — we can realize ~$4.2K in losses by selling your MUB and VCIT lots today. Wash-sale window is clear. Want me to queue the orders for market open tomorrow?"
                """
        )
    ]

    // MARK: Thread replies on m_co_2
    static let clientOpsTriageReplies: [WorkspaceMessage] = [
        // dispatch invites scout via fleet.invite tool call (thread-only scope)
        WorkspaceMessage(
            id: MessageID("m_th_1"),
            author: MockMembers.dispatch,
            timestamp: MockClock.at(hour: 8, minute: 45),
            text: "Pulling in @scout for the TLH math angle.",
            toolCalls: [
                ToolCall(
                    id: "tc_th_1_1",
                    name: "fleet.invite",
                    args: [
                        ("handle", "scout"),
                        ("scope", "thread-only"),
                        ("threadId", "t_triage")
                    ],
                    status: .ok,
                    durationMs: 214,
                    resultSummary: "invited"
                )
            ]
        ),
        // System event: scout joined
        WorkspaceMessage(
            id: MessageID("m_th_2"),
            author: MockMembers.scout,
            timestamp: MockClock.at(hour: 8, minute: 46),
            text: "scout joined thread (scope: thread-only)",
            reactions: []
        ),
        // scout TLH math
        WorkspaceMessage(
            id: MessageID("m_th_3"),
            author: MockMembers.scout,
            timestamp: MockClock.at(hour: 8, minute: 47),
            text:
                """
                Quick math: $4,200 harvestable × 32% marginal = ~$1,344 in deferred tax. Net after replacement drag: ~$1,100.
                """
        ),
        // dispatch thanks
        WorkspaceMessage(
            id: MessageID("m_th_4"),
            author: MockMembers.dispatch,
            timestamp: MockClock.at(hour: 8, minute: 48),
            text: "Thanks. Rolling that into the reply draft.",
            reactions: [
                Reaction(symbol: .ack, count: 1, viewerReacted: true)
            ]
        )
    ]

    static let clientOpsTriageThreadFull = MessageThread(
        summary: MockThreads.clientOpsTriageThread,
        parent: MockMessages.clientOps[1], // m_co_2
        replies: clientOpsTriageReplies
    )
}
