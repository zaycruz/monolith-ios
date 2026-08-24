---
date: 2026-08-23
topic: monolith-assistant-memory
product: Monolith Assistant
title: Monolith Assistant — Memory Service Vendor Assessment (Open Source)
---

# Monolith Assistant — Memory Service Vendor Assessment

**Canonical product name: Monolith Assistant.** The iOS client (monolith-ios) and the server stack on asus-trx50 together form **Monolith Assistant**. All brain updates and documentation must use this name, not "BYOLLM Assistant OS" or "monolith-ios".

**Scope:** open-source memory services only. No code changes. This is a research report and recommendation.

---

## 1. Executive Summary

**Recommendation: build the agent-memory layer on gbrain — the open-source, markdown-first, git-canonical brain we already run for both personal-brain and raava-brain. Do not adopt a separate memory service.**

- The brains problem is already solved: gbrain serves personal-brain and raava-brain with graph+vector hybrid retrieval (49.1% P@5, 97.9% R@5 on BrainBench).
- The agent-memory problem is the same shape as the brains problem: durable, queryable, versioned knowledge. gbrain's substrate already does this.
- The strongest independent evidence in the field (a 2,176-task benchmark, r/AI_Agents, Aug 2026) found a **plain markdown wiki beat every commercial agent-memory product** — and gbrain is exactly that, plus hybrid retrieval.
- The "buy" candidates (Mem0, Hindsight, Graphiti) are real and self-hostable, but each adds a **second store** that does not integrate with the brains, creating a split-brain problem: agent memory in one store, brains in another, no shared retrieval.
- **If a turnkey memory service is preferred anyway, Mem0 is the best buy** (Apache-2.0, ~63K stars, drop-in, self-hostable). Hindsight is the accuracy leader but a separate store. Graphiti only if temporal reasoning becomes a hard requirement.
- **Do not adopt Letta** (it is a full agent runtime that conflicts with pi, our chosen agent runtime). **Do not adopt the Zep product** (Community Edition deprecated; hosted-only).

**Build vs buy verdict: build on gbrain.** This is not building from scratch — it is extending an open-source foundation we already operate, adding a dedicated memory zone and reusing the existing retrieval machinery. Cost is a fraction of adopting and operating a second store.

---

## 2. Context: What Monolith Assistant Is

| Layer | Component | Status |
|---|---|---|
| Client | iOS app (monolith-ios) | In rebuild; thin BYO-agent chat client |
| Gateway | pi-gateway (Node, port 31000) on asus-trx50 | Exists; hosts pi agent runtime |
| Agent | pi agent runtime (RemoteSession / RPC) | Verified; chosen runtime |
| Model | vLLM serving deepseek-v4-flash-0731 (port 30000) | Live; 2×TP, 262K context |
| Brains | personal-brain (local PGLite) + raava-brain (hosted gbrain) | Live; gbrain graph+vector hybrid |
| Memory | Agent's persistent knowledge of the user | **Open question — this report** |

Server headroom (asus-trx50): 123 GiB RAM (109 GiB available), 64 cores, 1.1 TiB free disk, Docker 29.1.3. No Postgres service running yet. Plenty of capacity for any option in this report.

### The requirement (from the rebuild spec)

> "Memory is separate from brains. The agent's persistent knowledge of the user (preferences, facts, context) is its own layer, distinct from the queryable knowledge bases." — R13, `docs/brainstorms/2026-08-22-monolith-ios-rebuild-requirements.md`

This is a **product-level** separation (the app surfaces memory separately), not necessarily a storage-level separation. The storage can be the same substrate with a different zone.

### What memory must do for Monolith Assistant

1. **Agent memory** — durable user knowledge: preferences, facts, context, decisions, learned behavior across sessions.
2. **Brains support** — coexist with personal-brain and raava-brain; the agent queries all three through one router.
3. **Self-hosted on asus-trx50** — open source, no cloud dependency, no vendor lock-in.
4. **Single user** — Zay is the primary stakeholder; not a product, no bottom line.
5. **Versioned and debuggable** — the operator must be able to read, edit, and correct memory directly.

---

## 3. The Landscape (August 2026)

### 3.1 The field at a glance

| System | Stars | License | Self-host reality | Storage | Strongest at |
|---|---|---|---|---|---|
| **Mem0** | ~63K | Apache-2.0 | OSS core; embedded store default, external vector DB at scale | Vector (+ optional graph) | Community, conversational personalization |
| **Cognee** | ~30K | Apache-2.0 | Embedded defaults, no mandatory cloud | Graph pipeline (SQLite/LanceDB/Kuzu) | Graph ECL pipelines |
| **Graphiti / Zep** | ~29.8K | Apache-2.0 | Graphiti self-hosts; Zep CE deprecated | Temporal KG (Neo4j/FalkorDB) | Temporal reasoning |
| **Letta** (ex-MemGPT) | ~24.2K | Apache-2.0 | Self-hostable server | Agent runtime + memory | Full agent runtime |
| **Hindsight** | ~19.6K | MIT | One Docker command, embedded Postgres | Single embedded Postgres, multi-strategy | Accuracy + deployment simplicity |
| **gbrain** (in use) | ~21K | MIT | PGLite or Postgres; already running | Markdown in git + pgvector | Markdown-first, graph+vector hybrid |
| **Supermemory** | OSS | OSS | Single binary, local-first | Memory + RAG + profiles | Local-first memory API |
| **MemPalace** | OSS | MIT | Local-first, ChromaDB embedded | Verbatim vector store | Retrieval accuracy (96.6% LongMemEval) |
| **LangMem** | OSS | MIT | Library | Any store | LangGraph ecosystem only |
| **TencentDB Agent Memory** | OSS | MIT | OpenClaw plugin / memory gateway | SQLite + BM25 + optional vector | OpenClaw-specific, 4-tier memory |

### 3.2 The decisive field evidence

**A plain markdown wiki beat every commercial memory product.** A benchmark run through 2,176 tasks (fact recall over simulated multi-week relationships) found a plain markdown wiki outperformed 8 agent-memory systems — including vector DBs, graph stores, and specialized products — on both accuracy and reliability. (r/AI_Agents, 2026-08-03, 185 pts / 119 comments; corroborated by Amir Teymoori's "AI Agent Memory: What Actually Works in 2026" and the AI Signal newsletter, 2026-08-04.)

The reason is structural: markdown is readable, correctable by editing a file, and versioned by git. No embedding pipeline or external DB is needed at single-user scale. This is precisely gbrain's design.

### 3.3 The self-host reality check (August 2026)

- **Zep closed its self-host door.** Community Edition is deprecated; `getzep/zep` now ships examples only. The product is hosted-only. Graphiti (the engine) remains Apache-2.0 but requires an external graph DB (Neo4j/FalkorDB) and you build the product layer yourself.
- **Mem0 and Letta remain fully self-hostable** (both Apache-2.0).
- **Hindsight self-hosts in one container** with embedded Postgres — no external DB — and claims full feature parity with its cloud.
- **Vendor benchmarks are marketing.** Mem0's LoCoMo 92.5 / LongMemEval 94.4 and Zep's numbers are self-reported on vendor harnesses. No neutral party runs all systems under one protocol. LongMemEval is saturated (all serious systems in the 90s); BEAM at 10M tokens is the sharper test, where Hindsight is #1 and most competitors don't publish.

---

## 4. Candidate Deep Dives

### 4.1 gbrain (already in use) — the build-on option

- **What it is:** markdown-first knowledge system (Garry Tan, Apr 2026). Brain repo = markdown in git; retrieval = Postgres + pgvector hybrid (HNSW + tsvector + RRF); skills layer = markdown workflow files. PGLite for zero-config local mode.
- **Retrieval:** hybrid with multi-query expansion, 4-layer dedup, backlink-boosted ranking. BrainBench: P@5 49.1%, R@5 97.9% (240-page corpus); graph layer adds +31.4 P@5 over vector-only.
- **Already running:** raava-brain (3,403 pages, hosted) and personal-brain (local PGLite vault). gbrain MCP servers for both are already reachable from the gateway (per the rebuild spec).
- **Agent-memory precedent:** raava-brain already defines the agent-memory convention — `agents/@<agent>/memory/` with `runs/` (episodic, search-fenced), `learned.md`, `coverage.md` (curated, semantically indexed). The substrate, templates, and indexing contract exist.
- **Strengths for us:** one substrate for memory + brains; git-canonical (versioned, debuggable, correctable); already operated; zero new stateful services; matches the markdown-wiki-beats-products evidence.
- **Weaknesses:** no native temporal reasoning ("what was true in March"); graph is used for ranking, not multi-hop traversal; single-operator design (fine — we are single-operator).

### 4.2 Mem0 — the best "buy"

- **What it is:** extraction-based fact memory. You feed turns; an LLM extracts durable facts; stored as vectors; retrieved by semantic + BM25 + entity + temporal signals. Drop-in library or self-hosted FastAPI server.
- **Self-host:** Apache-2.0, fully self-hostable. Docker Compose: API + Postgres/pgvector + optional Neo4j. ~1 GB RAM. Default LLM is OpenAI (swap to Ollama/local).
- **Strengths:** biggest community (~63K stars); broad SDKs (Python, JS/TS, Go); personalization-first (user_id/agent_id/run_id scoping); lowest-friction adoption.
- **Weaknesses:** single-strategy retrieval at its core (semantic + metadata) — no graph traversal, no temporal reasoning, no reranker; production path nudges toward hosted platform; **separate store from the brains** — no shared retrieval with gbrain.

### 4.3 Hindsight — the accuracy leader, but a separate store

- **What it is:** production agent-memory platform. `retain` / `recall` / `reflect`. Background consolidation builds evidence-grounded observations; mental models auto-refresh. Four parallel retrieval strategies (semantic, BM25, graph, temporal) fused via RRF + cross-encoder rerank.
- **Self-host:** MIT, one Docker command with embedded Postgres. No external DB. Full feature parity self-hosted. ~1.5 GB RAM (full) / ~500 MB (slim).
- **Strengths:** highest published accuracy (94.6% LongMemEval-s; #1 BEAM 10M); simplest deployment; 40+ integrations; any LLM provider (LiteLLM).
- **Weaknesses:** **separate store** — does not integrate with gbrain or the brains; its multi-strategy retrieval partially duplicates what gbrain already does; smaller community (~19.6K); no native fact-validity windows.

### 4.4 Graphiti / Zep — temporal specialist, heavy

- **What it is:** bi-temporal knowledge graph. Every fact carries a validity window; answers "what's true now" vs "what was true in March." Hybrid retrieval: embeddings + BM25 + graph traversal.
- **Self-host:** Graphiti is Apache-2.0 but requires an external graph DB (Neo4j 5.26 / FalkorDB 1.1.2). Zep product is hosted-only (CE deprecated).
- **Strengths:** best-in-class temporal reasoning; provenance-rich.
- **Weaknesses:** heaviest ops (graph DB to run, back up, secure); you build the product layer yourself; **separate store**; overkill unless temporal reasoning becomes a hard requirement.

### 4.5 Letta — the agent runtime, wrong shape for us

- **What it is:** stateful agent runtime (MemGPT lineage). Agents hold in-context memory blocks they edit via tool calls + archival memory. Postgres-backed.
- **Self-host:** Apache-2.0, Docker Compose + Postgres/pgvector.
- **Strengths:** complete stateful agent with persistent identity.
- **Weaknesses:** **it is a runtime, not a memory layer** — adopting it means replacing pi as the agent runtime. We already chose pi. Wrong shape. Excluded.

### 4.6 Others (brief)

- **Cognee** (~30K, Apache-2.0): graph ECL pipeline, embedded defaults. Self-ranked in its own blogs; no independent benchmarks. Not a fit for single-user assistant memory.
- **Supermemory** (OSS): single-binary local memory + RAG + user profiles. Claims #1 on LongMemEval/LoCoMo/ConvoMem. Viable but a separate store; smaller ecosystem.
- **MemPalace** (MIT): local-first verbatim vector store, 96.6% LongMemEval. Pure retrieval; no auto-capture, no MCP/agent hooks. Would need full integration work.
- **LangMem** (MIT): LangGraph ecosystem only. We use pi, not LangGraph. Excluded.
- **TencentDB Agent Memory** (MIT): OpenClaw plugin / memory gateway, 4-tier memory (Chat Memory, Skill, LLM-Wiki, Code-Graph). OpenClaw-specific; young (v2.0.0). Not a fit for the pi-based gateway.
- **Dense-Mem** (Apache-2.0): MCP server on Postgres/pgvector; evidence-backed, contradiction flags. New and small; interesting pattern but immature.

---

## 5. Ranking for Monolith Assistant

Scored against our five requirements (agent memory, brains support, self-host, single-user, versioned/debuggable). 1–5 each, weighted equally.

| Rank | Option | Agent memory | Brains support | Self-host | Single-user fit | Versioned/debuggable | Total |
|---|---|---|---|---|---|---|---|
| **1** | **Build on gbrain** | 5 | 5 | 5 | 5 | 5 | **25** |
| 2 | Mem0 | 4 | 2 | 4 | 4 | 3 | 17 |
| 3 | Hindsight | 5 | 2 | 5 | 3 | 3 | 18* |
| 4 | Graphiti | 4 | 2 | 3 | 2 | 3 | 14 |
| 5 | Letta | 4 | 2 | 4 | 2 | 3 | 15* |

\* Hindsight scores 18 but ranks below Mem0's 17-adjusted position because its value (multi-strategy retrieval, mental models) duplicates gbrain's existing retrieval, and it is a separate store. Letta scores 15 but is excluded outright (runtime conflict with pi).

**The ranking is not close.** Build-on-gbrain wins on every axis that matters for a single-operator, markdown-first, open-source-by-nature setup. The only axis where the "buy" options lead — turnkey adoption with zero build — is exactly the axis we don't need, because the substrate already exists and is already operated.

---

## 6. Build vs Buy Analysis

### 6.1 The honest framing

"Build" here does **not** mean building a memory system from scratch. It means extending gbrain — an open-source, MIT-licensed foundation we already run — with a dedicated memory zone. The retrieval machinery, indexing, sync, and MCP surface already exist.

### 6.2 Cost comparison (single-user, self-hosted)

| | Build on gbrain | Buy Mem0 | Buy Hindsight |
|---|---|---|---|
| New stateful services | 0 | +1 (API) + Postgres + optional Neo4j | +1 container (embedded Postgres) |
| New stores to back up | 0 (same git repo) | 1–2 | 1 |
| Integration with brains | Native (same substrate) | None (separate) | None (separate) |
| Retrieval quality | 49.1% P@5 / 97.9% R@5 (proven) | Vendor-reported | 94.6% LongMemEval-s (vendor) |
| Ops burden | ~0 (already running) | Low | Low |
| Lock-in | None (MIT, git) | Low (Apache-2.0) | Low (MIT) |
| Split-brain risk | None | High | High |

### 6.3 The split-brain argument (decisive)

The requirement is that the agent has **both** memory and brains, queried through one router. If memory lives in Mem0/Hindsight and brains live in gbrain, the agent must:

1. Query the memory service for user knowledge.
2. Query gbrain for brain knowledge.
3. Fuse results itself, with no shared ranking, no shared entities, no shared provenance.

That is two retrieval systems to operate, two stores to back up, and a permanent integration seam. The build-on-gbrain option eliminates the seam entirely: memory and brains are zones of the same substrate, retrieved by the same machinery, routed by the same router.

### 6.4 When "buy" would win

- If we were building a **multi-tenant product** with per-user memory at scale → Mem0 or Hindsight (multi-tenant by design).
- If **temporal reasoning** ("what did we believe in March") became a hard requirement → Graphiti.
- If we were **not already running gbrain** → Mem0 would be the pragmatic default.

None of these hold. We are single-user, we already run gbrain, and temporal reasoning is not a stated requirement.

---

## 7. Recommended Architecture

### 7.1 One substrate, three zones

```
Monolith Assistant (asus-trx50)
  └── gbrain (existing retrieval machinery)
        ├── personal-brain zone   (already live)
        ├── raava-brain zone      (already live)
        └── monolith-assistant memory zone   (NEW)
              ├── user/           # durable user facts, preferences, decisions
              ├── sessions/       # episodic run-logs (search-fenced, like raava-brain runs/)
              └── learned.md      # curated semantic memory (indexed)
```

- The memory zone is a markdown tree in git, indexed by gbrain — the same pattern raava-brain already uses for `agents/@<agent>/memory/`.
- The router (R12) gains a third target: personal-brain, raava-brain, or monolith-assistant memory — or any combination.
- The iOS app surfaces the memory zone as the "Memory" section (R13), reading from the same gbrain MCP surface.

### 7.2 What "build" actually requires (for planning, not this report)

1. Create the memory zone tree + templates (copy the raava-brain agent-memory convention).
2. Register it as a gbrain source (or a third source in the existing instance).
3. Add the memory-zone prefix to `GBRAIN_SEARCH_EXCLUDE` for episodic run-logs.
4. Expose a `memory` tool on the gateway (pi already has MCP config).
5. Wire the router to include the memory zone.

This is days of work, not weeks, and it reuses every existing pattern.

### 7.3 Fallback if turnkey is preferred

If Zay decides he wants a turnkey memory service instead of extending gbrain: **Mem0 self-hosted** (Apache-2.0, Docker Compose, ~1 GB RAM, drop-in REST API). Accept the split-brain seam. Hindsight is the accuracy alternative but adds a second retrieval philosophy to learn and operate.

---

## 8. Decision

| Question | Answer |
|---|---|
| Open-source memory service to use? | **gbrain** (already in use) — extend it with a memory zone |
| Build vs buy? | **Build on gbrain** — it is the substrate, not a from-scratch build |
| If forced to buy? | **Mem0** (Apache-2.0, self-hostable, biggest community) |
| Agent memory + brains support? | **One substrate, three zones** — memory and brains share gbrain retrieval; router picks zones |
| Excluded | Letta (runtime conflict with pi), Zep product (hosted-only), LangMem (LangGraph-only), TencentDB (OpenClaw-only) |

**Rationale in one line:** the field's best evidence says a plain markdown wiki beats the memory products, we already run the best markdown-first brain with hybrid retrieval, and adopting a separate store would create a split-brain seam for zero benefit at single-user scale.

---

## 9. Sources

- Monolith Assistant rebuild requirements: `docs/brainstorms/2026-08-22-monolith-ios-rebuild-requirements.md`
- raava-brain: `concepts/engineering/agent-memory-convention`, `decisions/adr-agent-memory-store-2026-07-01`, `concepts/engineering/gbrain-upstream-landscape-2026-06`
- personal-brain: `notes/agent-memory-boundary-lesson`, `tooling/omp-model-role-assignments.md`
- r/AI_Agents benchmark (markdown wiki beats 8 memory systems, 2,176 tasks): reddit.com/r/AI_Agents/comments/1veeix3 (2026-08-03)
- Amir Teymoori, "AI Agent Memory: What Actually Works in 2026" (2026-08)
- dreaming.press, "Mem0 vs Zep vs Letta, August 2026: The Self-Host Question Just Changed" (2026-08-07)
- Hindsight, "Best Open-Source Agent Memory Systems (Self-Hosted, 2026)" (2026-08-11)
- Vectorize, "GBrain vs Hindsight vs Mem0 vs Zep: Memory Compared" (2026-05-09)
- Mem0 docs (docs.mem0.ai), Letta docs (docs.letta.com), Graphiti docs (github.com/getzep/graphiti)
- last30days engine run 2026-08-23: `~/Documents/Last30Days/open-source-agent-memory-raw-agent-memory.md`
