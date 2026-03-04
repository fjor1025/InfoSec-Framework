<!-- Managed by docs-for-humans-and-ai skill -->
<!-- Ecosystem: Go (Cosmos SDK / IBC / CometBFT) -->
<!-- Version: 2.1 -->

# Go Smart Contract Audit Framework

Covers **Cosmos SDK**, **CometBFT ABCI/ABCI++**, **IBC**, and general Go blockchain applications. Version 2.1 adds ABCI++ lifecycle, module integration, and transaction structure attack patterns.

**Before making changes**, read this file fully. For repo-wide conventions, see [../CLAUDE.md](../CLAUDE.md).

## Directory Structure

```
Go-SmartContract/
├── CLAUDE.md                                  ← You are here
├── README.md                                  ← Human-facing overview + quick start
├── CommandInstruction-Go.md                   ← System prompt (binding rules, 8 Go/Cosmos lenses)
├── Go-Smart-Contract-Audit-Methodology.md     ← Methodology + ClaudeSkills C1–C6 + ABCI++
└── Audit_Assistant_Playbook_Go.md             ← Conversation structure (Sections 1–10)
```

## 3-File Architecture

| File | Role | AI Behavior |
|------|------|-------------|
| **CommandInstruction-Go.md** | System prompt | Load FIRST. 8 Go/Cosmos-specific lenses. |
| **Go-Smart-Contract-Audit-Methodology.md** | Methodology | Phases, checklists, attack patterns, ClaudeSkills C1–C6, ABCI++ patterns. |
| **Audit_Assistant_Playbook_Go.md** | Conversation structure | 10 sections, SCAN prompts, agent roles. |

## Auditor's Mindset (8 Lenses)

| Lens | What It Catches |
|------|----------------|
| Pointer & Reference Hunting | Pointer aliasing, mutations before validation, value vs pointer receivers |
| Error Path Paranoia | Ignored errors (`_, _ :=`), `panic()` in production, missing wrapping |
| Zero Value Exploitation | Zero-value structs treated as valid, `nil` returns from store.Get() |
| Module Boundary Thinking | Keeper dependency graph, cross-keeper calls, BlockedAddr bypass |
| State Consistency Analysis | Partial state updates, missing rollback, iterator mutations |
| Economic Attack Surface | Token flow manipulation, rounding direction, fee extraction |
| ABCI++ Lifecycle Safety | PrepareProposal/ProcessProposal determinism, VoteExtension trust, FinalizeBlock |
| Transaction Structure Analysis | Multi-msg tx, nested via authz/gov, AnteHandler chain gaps |

## ABCI Version Quick Reference

| ABCI Version | Key Methods | Critical Rules |
|-------------|-------------|---------------|
| Classic (v0.34) | CheckTx, DeliverTx, BeginBlock, EndBlock | No panics in handlers |
| ABCI++ (v0.37+) | +PrepareProposal, +ProcessProposal | Must be deterministic |
| ABCI++ (v0.38+) | +ExtendVote, +VerifyVoteExtension | Trust boundary at VoteExtension |
| FinalizeBlock | Replaces DeliverTx | ONLY place for state changes |
| Commit | Persistence | No broadcast_tx (deadlock risk) |

## Semantic Phases (Go)

| Phase | Go Indicators | Key Questions |
|-------|--------------|---------------|
| VALIDATION | `ValidateBasic()`, early `if` checks | All fields validated? Signatures checked? |
| SNAPSHOT | `k.Get*()`, `store.Get()` | Zero values handled? Nil returns checked? |
| ACCOUNTING | `ctx.BlockTime()`, oracle queries | Time manipulation? Rounding errors? |
| MUTATION | `store.Set()`, pointer modification | Value conserved? Pointer safety? |
| COMMIT | `Save*()`, protobuf marshaling | Atomic writes? Gas accounted? |
| EVENTS | `EmitEvent()`, `EmitTypedEvent()` | All changes logged? Safe attributes? |
| ERROR | `return nil, err`, `panic()` | State rolled back? Cleanup done? |

## Key Integrations

| Source | What It Provides | Patterns |
|--------|-----------------|----------|
| ClaudeSkills Cosmos Scanner | Cosmos-specific vulnerability detection | C1–C6 |
| ABCI++ Specification | CometBFT v0.37–v0.38+ lifecycle | PrepareProposal, VoteExtension |
| Cosmos Exploit Database | 20+ real-world exploits | Dragonberry, Jackfruit, Barberry |
| awesome-cosmos-security | Curated security resources | Community research |

## Editing Rules

- Companion to `Cosmos-SDK/` — Go-level code analysis vs chain-level security
- ABCI++ version matters — always specify which version a pattern applies to
- ClaudeSkills patterns C1–C6 are referenced throughout the methodology
- Go-specific red flags (pointer mutation, zero values, ignored errors) are universal across Cosmos/IBC/CometBFT

<!-- LOCAL CUSTOMIZATIONS — everything below this line is preserved on update -->
