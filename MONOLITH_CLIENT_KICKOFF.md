# Monolith iOS Client Kickoff (Workspace-First)

This document defines the immediate client work we can start **before** the new Workspace API is fully implemented.

## Goal

Ship UI and local interaction primitives in parallel with backend API implementation, then swap mock repositories to live endpoints with minimal rework.

---

## 1) What we can build right now (no server dependency)

1. Workspace home shell (channels + DMs + activity tabs)
2. Channel timeline screen
3. Thread panel screen
4. Agent profile sheet
5. Launch/invite agent sheet
6. Composer with mention chips and formatting controls
7. Symbol reaction pills (`✓ ! ? ✗ ↻ +`)
8. Local state store + mock repositories

---

## 2) Required adapter interfaces (stable from day one)

Create protocol-first repositories in iOS so UI remains backend-agnostic:

- `WorkspaceRepository`
- `ConversationRepository`
- `MessageRepository`
- `RealtimeRepository`
- `AgentRepository`
- `NotificationRepository`

Start with `Mock*Repository` implementations and deterministic fixtures.

---

## 3) HTML → SwiftUI translation rules

The provided HTML/CSS is a visual source, not runtime code for iOS. Use it as:

- **Token source:** colors, spacing, typography hierarchy
- **Layout source:** screen structure and information architecture
- **Component source:** avatar variants, tool-call blocks, tab bar, sheets

### Do not do

- Do not embed WebView for core product UI.
- Do not try to parse/execute raw HTML for native screens.

### Do this instead

- Build native SwiftUI components mirroring the HTML structure.
- Map CSS variables to Swift constants in a centralized theme file.

---

## 4) Suggested first file set

- `MonolithTheme.swift` (tokens: color/type/spacing/radius)
- `WorkspaceHomeView.swift`
- `ChannelView.swift`
- `ThreadView.swift`
- `AgentProfileSheet.swift`
- `InviteAgentSheet.swift`
- `MessageRow.swift`
- `ToolCallBlockView.swift`
- `ComposerView.swift`
- `MockWorkspaceData.swift`

---

## 5) Integration checkpoints

Swap to live API in this order:

1. Bootstrap payload
2. Timeline read/write
3. Realtime events
4. Reactions/mentions
5. Agent launch/profile
6. Push token registration + prefs

---

## 6) Definition of done for client kickoff

- All six core screens render with realistic mock data.
- Navigation path matches PRD primary journeys (J1–J6).
- Timeline supports inline tool-call block rendering.
- Mention chip UX + reaction pills function locally.
- No hard dependency on backend shape in view layer.
