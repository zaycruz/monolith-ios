# Monolith iOS Mockups — v0.2 → v0.3 Changelog

Reference for implementation. This documents every design change between the original mockups (v0.2) and the current liquid glass revision (v0.3). Use v0.3 as the source of truth.

---

## Summary

v0.2 was visually correct to the Monolith brand but felt like a terminal wearing an iPhone costume — dense, cold, flat. v0.3 applies iOS 26 liquid glass conventions while preserving the Monolith palette and brand identity. The result feels native to iOS while staying dark, monochrome, and operator-grade.

---

## Device frame

| Property | v0.2 | v0.3 |
|---|---|---|
| Frame width | 380px | 393px (iPhone 16 Pro) |
| Frame height | 810px | 852px (iPhone 16 Pro) |
| Corner radius (outer) | 52px | 55px |
| Corner radius (inner screen) | 44px | 47px |
| Dynamic Island width | 110px | 126px |
| Dynamic Island height | 32px | 37px |
| Home indicator opacity | 100% white | 30% white |

---

## Spacing and touch targets

| Element | v0.2 | v0.3 |
|---|---|---|
| Channel/DM row height | ~42px | 56px minimum |
| Channel/DM row padding | 9px 6px | 12px 20px |
| Search bar padding | 8px 12px | 12px 16px |
| Search bar font size | 12px | 15px |
| Tab bar height | 78px | 88px |
| Tab bar icon size | 20px | 26px |
| Message padding | 8px 22px | 8px 20px 12px |
| Reaction pill padding | 2px 8px | 5px 12px |
| Thread link padding | 6px 10px | 8px 14px |
| Composer field padding | 10px 14px | 12px 16px |

---

## Liquid glass surfaces

These elements gained `backdrop-filter: blur() saturate()` with translucent backgrounds. In v0.2 they were opaque flat surfaces.

### Tab bar
- v0.2: `background: rgba(15,16,17,0.95)` — nearly opaque, no blur
- v0.3: `background: rgba(15,16,17,0.45)`, `backdrop-filter: blur(40px) saturate(180%)`, `border-top: 1px solid rgba(255,255,255,0.08)`, `box-shadow: inset 0 1px 0 rgba(255,255,255,0.04)`
- Active tab indicator: v0.2 used color change only. v0.3 adds a 3px white bar above the active icon at 50% opacity

### Navigation bar
- v0.2: `border-bottom: 1px solid var(--stone)` — flat, opaque obsidian background
- v0.3: `background: rgba(15,16,17,0.5)`, `backdrop-filter: blur(30px) saturate(150%)`, `border-bottom: 1px solid rgba(255,255,255,0.06)`

### Search bar
- v0.2: `background: var(--stone)`, `border-radius: 10px` — solid flat box
- v0.3: `background: rgba(22,24,26,0.6)`, `backdrop-filter: blur(20px)`, `border: 1px solid rgba(255,255,255,0.06)`, `border-radius: 14px`

### Composer
- v0.2: `background: linear-gradient(to top, var(--obsidian) 70%, transparent)` — gradient fade
- v0.3: `background: rgba(15,16,17,0.6)`, `backdrop-filter: blur(40px) saturate(180%)`, `border-top: 1px solid rgba(255,255,255,0.06)`
- Input field: `background: rgba(22,24,26,0.7)`, `border: 1px solid rgba(255,255,255,0.08)`, `border-radius: 20px`

### Tool call blocks
- v0.2: `background: var(--void)`, `border: 1px solid var(--stone)`, `border-radius: 6px` — flat, sharp
- v0.3: `background: rgba(8,9,10,0.7)`, `border: 1px solid rgba(255,255,255,0.06)`, `border-radius: 12px`, `backdrop-filter: blur(10px)` — glass card

### Shortcut pills (workspace home)
- v0.2: flat rows with text and icon
- v0.3: horizontal pill capsules with glass treatment — `background: rgba(22,24,26,0.6)`, `border: 1px solid rgba(255,255,255,0.05)`, `border-radius: 14px`, `backdrop-filter: blur(10px)`

---

## Avatars

### Shape system (unchanged in concept, refined in execution)
- Humans: circle
- Agents: rounded square (22% border-radius)

### Size scale
| Size | v0.2 | v0.3 |
|---|---|---|
| xs | 16px | 20px |
| sm | n/a | 20px (used in stacks) |
| md | 24px | 28px |
| lg | 32px | 36px |
| xl | n/a | 44px (detail hero) |

### New: gradient fills on human avatars
- v0.2: flat solid colors (`#3B5BDB`, `#7048E8`, `#0EA5E9`)
- v0.3: `linear-gradient(135deg, ...)` on each human avatar for subtle depth
  - Zay: `#3B5BDB → #5C7CFA`
  - Sofia: `#7048E8 → #9775FA`
  - Jason: `#0EA5E9 → #38BDF8`

### New: presence status dots
- v0.2: no presence indicators on avatars
- v0.3: 12px status dot overlaid bottom-right of avatar, with 2.5px obsidian border
  - Online: `var(--running)` (#4ADE80) with `box-shadow: 0 0 6px rgba(74,222,128,0.5)`
  - Offline: `var(--iron)` (#3A3F44) solid

### Slit mark on agent avatars
- v0.2: `::before` pseudo — `width: 2px`, positioned with fixed left/top/bottom percentages
- v0.3: same approach, refined — `left: 22%`, `top: 22%`, `bottom: 22%`, `opacity: 0.7`

---

## Typography changes

| Context | v0.2 | v0.3 |
|---|---|---|
| Tab bar labels | JetBrains Mono 9px | IBM Plex Sans 10px weight 500 |
| Channel names in sidebar | JetBrains Mono 13px | IBM Plex Sans 16px |
| Section headers | JetBrains Mono 10px, 0.2em tracking, uppercase | IBM Plex Sans 13px, weight 600, 0.02em tracking, uppercase |
| DM names (human) | IBM Plex Sans 13.5px | IBM Plex Sans 16px |
| DM names (agent) | JetBrains Mono 13px | JetBrains Mono 14.5px |
| Search placeholder | JetBrains Mono 12px | IBM Plex Sans 15px |
| Workspace name | JetBrains Mono 17px weight 600 | IBM Plex Sans 22px weight 600 |
| Message body | IBM Plex Sans 13.5px | IBM Plex Sans 15px |
| Message author (human) | IBM Plex Sans 13px weight 600 | IBM Plex Sans 15px weight 600 |
| Message author (agent) | JetBrains Mono 12.5px | JetBrains Mono 14px |
| Timestamp | JetBrains Mono 10px | IBM Plex Sans 12px |

**Key shift:** v0.2 used JetBrains Mono for almost everything (channel names, tab labels, search, section headers). v0.3 reserves JetBrains Mono strictly for: agent names, tool call content, runtime data (VM specs, uptime, model name, token counts), `code` inline elements, and the `agent` tag. Everything else uses IBM Plex Sans.

---

## Border radius

| Element | v0.2 | v0.3 |
|---|---|---|
| Search bar | 10px | 14px |
| Tool call block | 6px | 12px |
| Reaction pills | 11px | 20px |
| Thread link | 7px | 12px |
| Template cards | 10px | 16px |
| VM size rows | 8px | 14px |
| Detail tab bar | 8px | 14px |
| Individual tab | 6px | 11px |
| Composer field | 20px | 20px (unchanged) |
| Action buttons | 10px | 14px |

**Pattern:** v0.3 uses 14-16px as the default radius for interactive containers, 20px for pill shapes, 12px for inline cards (tool calls, threads).

---

## Colors

Palette is unchanged. The difference is in how opacity and alpha are used:

### v0.2 approach
Used CSS custom properties directly: `var(--stone)`, `var(--graphite)`, `var(--obsidian)`. Borders were `1px solid var(--stone)`. Backgrounds were solid.

### v0.3 approach
Uses `rgba()` values for translucent layering:
- Borders: `rgba(255,255,255, 0.04-0.08)` instead of solid color tokens
- Backgrounds: `rgba(22,24,26, 0.5-0.7)` for glass surfaces
- Hover states: `rgba(255,255,255, 0.015)` instead of a named color
- Active states: `rgba(255,255,255, 0.06)`

The solid palette tokens (`--void`, `--obsidian`, `--stone`, etc.) are still used for non-glass elements — the body background, avatar fills, and opaque content areas.

---

## Workspace home changes

| Feature | v0.2 | v0.3 |
|---|---|---|
| Workspace icon | none | 32px rounded square with gradient fill and slit mark |
| Presence line | JetBrains Mono, under workspace name | IBM Plex Sans 13px, with animated green dot |
| Shortcuts | vertical list rows | horizontal glass pill capsules |
| Channel rows | # prefix as text, no icon | 36px rounded square icon with # inside |
| Channel row preview | none | last message preview text on unread channels |
| DM rows | avatar + name only | avatar + presence dot + name + preview + time |
| Unread badge | white circle, JetBrains Mono | white circle, IBM Plex Sans weight 700, 22px diameter |
| Section add button | "+" text | 28px circle button |

---

## Channel view changes

| Feature | v0.2 | v0.3 |
|---|---|---|
| Nav bar | flat obsidian | glass blur nav |
| Nav back button | `‹` character | `‹` character, 36px hit target |
| Nav actions | 2 icons, 17-18px | 2 icons, 22px, 16px gap |
| Member bar avatars | 16px (xs) | 20px (sm) |
| Day separator | JetBrains Mono 10px | IBM Plex Sans 12px weight 600 |
| Message left border (v0.2 distinction) | 2px colored left border per message type | removed — avatar shape carries the distinction |
| Agent tag | uppercase `AGENT`, sharp border | lowercase `agent`, subtle glass pill |
| Hover state | none | rgba(255,255,255,0.015) background |
| Typing indicator | "dispatch is drafting" | "dispatch is thinking" |

---

## New screens in v0.3

### 03 · dm.agent
1:1 DM with an agent. Nav shows agent name in JetBrains Mono + running state + uptime. Shows multi-tool-call stacking (slack.read_channel + gmail.search in one message).

### 04 · agent.detail
Tap any agent avatar. Hero section centered with large avatar (56px), name, role, state pill (green tinted for running). Glass tab bar (Overview / Tools / Logs / Config). KV rows for instance and model data. Tool list with 36px icons, 2-letter abbreviations, origin, status. supabase.mcp shows amber "warn" status. Three action buttons: Open terminal, Message dispatch, Stop agent (danger variant).

### 05 · thread.view
Parent message pinned in grey block at top. Glass nav shows "Thread" + reply/agent count. Thread join divider includes agent avatar. Multi-agent participation visible.

### 06 · agent.launch
Modal (✕ dismiss). Hero with title + description. Template 2×2 grid with glass cards. VM size list with pricing. Glass name input field with `agent /` prefix and blinking cursor. Snow-white CTA.

### 07 · activity.feed
Large title "Activity" at top. Glass search with "Filter activity..." placeholder. Chronological feed with "New" and "Earlier today" sections. Each item: avatar + headline (bold name, action, channel reference) + preview + time. Active Activity tab in glass tab bar.

---

## What stayed the same

- Void (#08090A) body background
- Monolith slit-as-mark in agent avatars
- JetBrains Mono for agent identity and runtime data
- IBM Plex Sans for human prose and body text
- Tool calls rendered inline in messages (not hidden)
- Reactions as symbol set (✓ ! ? ✗ ↻ +), not emoji
- Raava gradient used only as whisper accent
- Human avatars as circles, agent avatars as rounded squares
- `agent` tag next to agent names in messages (lowercased in v0.3)
- Thread link with avatar stack + reply count

---

## Implementation notes for Swift

1. **Glass materials in SwiftUI:** Use `.ultraThinMaterial` or `.regularMaterial` for glass surfaces. These map to the `backdrop-filter: blur()` in the mockups. On iOS 26, prefer the new Liquid Glass system materials when targeting iOS 26+.

2. **Avatar shape:** `clipShape(Circle())` for humans, `clipShape(RoundedRectangle(cornerRadius: size * 0.22))` for agents.

3. **Status dots:** `overlay` modifier positioned with `.offset()` at bottom-trailing.

4. **Glass tab bar:** `TabView` with `.tabViewStyle(.page)` won't give glass. Use a custom tab bar with `VisualEffectView` or `.background(.ultraThinMaterial)`.

5. **Font assignment:** Agent name → `Font.custom("JetBrains Mono", size: 14).weight(.semibold)`. Human name → `Font.system(size: 15, weight: .semibold)` or Plex Sans custom.

6. **Tool call blocks:** Custom `View` with `.background(.ultraThinMaterial)` and `RoundedRectangle(cornerRadius: 12)` clip.

7. **Presence dot animation:** The green running dot has `box-shadow: 0 0 8px` glow. In SwiftUI, use `.shadow(color: .green.opacity(0.5), radius: 4)`.

8. **Touch targets:** All interactive rows must have a minimum 44pt height per Apple HIG. The mockups use 56px which exceeds this.
