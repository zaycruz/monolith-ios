# Workspace Module

SwiftUI scaffold for the Monolith mobile workspace. Lives as a sibling module
inside `byollm-assistantOS/` — it does **not** share source with the BYOLLM
chat client files (`ChatView.swift`, `byollm_assistantOSApp.swift`, etc.).

## Adding to the Xcode project

Because we do not edit `project.pbxproj` from scripts, you need to add this
folder to the Xcode target manually once:

1. Open `byollm-assistantOS.xcodeproj` in Xcode.
2. In the Project Navigator, right-click `byollm-assistantOS` (the group, not
   the project).
3. Choose **Add Files to "byollm-assistantOS"…**.
4. Select the `Workspace/` folder.
5. In the dialog:
   - Check **Create groups** (not folder references).
   - Target membership: **byollm-assistantOS**.
   - Leave **Copy items if needed** unchecked (files are already in-tree).
6. Click **Add**.

Clean build folder (`Cmd-Shift-K`) and rebuild.

## Previewing each screen

Every view has a `#Preview` block. Open the file, then open the Canvas
(`Option-Cmd-Return`) or run the preview with `Option-Cmd-P`.

| Screen | File | Preview name |
|---|---|---|
| 01 Workspace home | `Views/WorkspaceHomeView.swift` | `WorkspaceHomeView` |
| 02 Channel | `Views/ChannelView.swift` | `ChannelView — #client-ops` |
| 03 Agent DM | `Views/AgentDMView.swift` | `AgentDMView — Zay × dispatch` |
| 04 Thread | `Views/ThreadView.swift` | `ThreadView — triage thread` |
| 05 Agent profile | `Views/AgentProfileSheet.swift` | `AgentProfileSheet — dispatch` |
| 06 Invite agent | `Views/InviteAgentSheet.swift` | `InviteAgentSheet` |
| Full app flow | `WorkspaceApp.swift` | `WorkspaceRootView` |

Component-level previews exist for `AgentAvatar`, `HumanAvatar`,
`ToolCallBlock`, `ReactionChip`, `ThreadLink`, `DayMark`, `MessageRow`,
`ComposerView`, `TabBar`.

## Running the whole app

`WorkspaceApp` is defined but **not** marked `@main` — the existing
`byollm_assistantOSApp` owns that attribute. To boot the workspace scaffold
as its own app, either:

- add `@main` to `struct WorkspaceApp: App` in `WorkspaceApp.swift` and
  temporarily comment out the `@main` on `byollm_assistantOSApp`, **or**
- create a new Xcode target (recommended) whose entry point is
  `WorkspaceApp` and add `@main` there only.

For day-to-day work just use the previews — they render the full nav stack.

## What is mocked

Nothing hits the network. All data comes from
`Mocks/MockWorkspaceData.swift`, which is deterministic and matches the
design mockup (`design/mockups-v0.3.html`) exactly.

Repositories:

- `MockWorkspaceRepository` — returns the Raava Ops workspace.
- `MockConversationRepository` — channels, DMs, threads.
- `MockMessageRepository` — loads and sends messages; optimistic local
  append; fans new messages out through the realtime repo.
- `MockRealtimeRepository` — multicast `AsyncStream<WorkspaceEvent>`; used
  by `ChannelView` to receive optimistic sends.
- `MockAgentRepository` — lists agents, returns profile, mints new agents
  on invite.
- `MockNotificationRepository` — unread notifications + read state.

## Design tokens

Single source in `Theme/MonolithTheme.swift`:

- Raw palette: `MonolithTheme.Palette.*`
- Semantic: `MonolithTheme.Colors.*` (always use these at call sites)
- Spacing: `MonolithTheme.Spacing.*`
- Radii: `MonolithTheme.Radius.*`
- Avatar sizes: `MonolithTheme.AvatarSize` (xs/sm/md/lg/xxl)
- Typography: `MonolithFont.mono(...)` / `MonolithFont.sans(...)` with
  graceful fallback to `.system(design: .monospaced)` and `.system(design:
  .default)` when JetBrains Mono / IBM Plex Sans are not bundled.

The `Color(hex:)` extension is declared once, in `MonolithTheme.swift`.
Do not redeclare it elsewhere in this module.

## Design rules encoded in code

- `HumanAvatar` is a `Circle`, `AgentAvatar` is a `RoundedRectangle` plus
  a left-edge `Rectangle` (the "slit" — the brand mark).
- Tool calls are rendered by `ToolCallBlock` **inline**, **before** the
  message text, as children of the parent `MessageRow`.
- Agent author names render in JetBrains Mono with an uppercased `AGENT`
  badge to the right.
- Reactions are symbol glyphs (`✓ ! ? ✗ ↻ +`) — never emoji.
- Collapsed messages (same author within 2 min) keep the 32pt avatar slot
  but swap the avatar for a tiny timestamp.

## Open spec decisions (search for `TODO(spec-decision):`)

1. **Agent visibility model** —
   `Repositories/AgentRepository.swift`. Mock lists all workspace agents;
   real impl may scope to channel overlap.
2. **Read receipts policy** —
   `Repositories/NotificationRepository.swift`. Mock uses per-channel
   high-water mark.
3. **Idempotency key format** —
   `Repositories/MessageRepository.swift` +
   `Mocks/MockMessageRepository.swift`. Mock accepts any non-empty string.
4. **Agent launch naming rule** —
   `Repositories/AgentRepository.swift` +
   `Mocks/MockAgentRepository.swift`. Mock uses provided name or
   `agent-NNN`.
5. **Error taxonomy** —
   `Mocks/MockConversationRepository.swift` (`MockRepositoryError`). Three
   cases for now; real impl needs a full classification.

## Things the user still has to do

- Add `Workspace/` to the Xcode target (see top of this file).
- Bundle `JetBrainsMono` and `IBMPlexSans` font files and register them in
  `Info.plist` under `UIAppFonts` if the pixel-perfect typography is
  required. Without them the module falls back gracefully.
- Decide on `@main` strategy before running the app outside previews.

## Running on a physical device

Side-loading to a real iPhone using free personal signing with the Raava
team profile. No TestFlight / App Store Connect is required for this.

1. **Pair + trust the iPhone.** Plug the phone in via USB (or enable Wi-Fi
   sync), open Xcode → **Window → Devices and Simulators**, pick the
   device, and confirm the trust prompt on the phone. Once it shows
   "Connected" with a green dot, you're good.
2. **Set the signing team.** In Xcode open
   `byollm-assistantOS.xcodeproj`, select the **byollm-assistantOS**
   target → **Signing & Capabilities** tab:
   - Team: `RA5ZRTAX47`
   - **Automatically manage signing** — keep checked
   - Bundle Identifier: `openaccesslabs.byollm-assistantOS`
3. **Let Xcode register the device.** On first build for a new phone,
   Xcode will auto-register the UDID under the team and generate a fresh
   provisioning profile. You do not need to touch the Apple Developer
   portal for this.
4. **Select the device as the run destination.** In the Xcode toolbar
   scheme picker, pick the paired iPhone (not a simulator) and hit ⌘R.
   Xcode will install and launch the app.
5. **Trust the developer cert on the phone (first run only).** iOS will
   refuse to open a freshly-side-loaded build until you mark the signer
   as trusted. On the iPhone: **Settings → General → VPN & Device
   Management → Developer App → RA5ZRTAX47 → Trust**. After that the app
   icon on the home screen becomes launchable.
6. **Sign in with your portal email.** The app boots into `SignInView`,
   tap **Continue**, and Clerk will send an email OTP to the address
   associated with your workspace user. Once the OTP is verified the app
   swaps to the live agent repo and starts hitting the Fleet API.

If `xcodebuild` on the command line is preferred, replace the
`-destination 'id=<simulator-uuid>'` flag with
`-destination 'platform=iOS,id=<iphone-udid>'` and remove
`CODE_SIGNING_ALLOWED=NO` (device builds must be signed).
