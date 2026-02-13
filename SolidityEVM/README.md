# Solidity/EVM Audit Framework

> **Version:** 2.0 — Binding Architecture
> **Ecosystem:** Solidity smart contracts on EVM-compatible chains (Ethereum, Arbitrum, Optimism, Base, Polygon, BSC, etc.)

---

## What This Is

A structured audit framework for Solidity/EVM smart contracts. Three files work together as a binding system — not suggestions, not guidelines, but rules that govern how every audit conversation operates.

This is the **benchmark framework** that all other ecosystem frameworks (Rust, Go, Cairo, Algorand) were modeled after.

---

## Framework Files

| File | Lines | Purpose |
|------|-------|---------|
| [CommandInstruction.md](CommandInstruction.md) | ~151 | System prompt — binding rules, validation checks, auditor's mindset |
| [audit-workflow1.md](audit-workflow1.md) | ~661 | Manual audit methodology — 7 phases, attack vectors, known exploits |
| [audit-workflow2.md](audit-workflow2.md) | ~421 | Semantic phase analysis — SNAPSHOT→ACCOUNTING→VALIDATION→MUTATION→COMMIT |
| [Audit_Assistant_Playbook.md](Audit_Assistant_Playbook.md) | ~1261 | Conversation structure — 10 sections covering the full audit lifecycle |

**Total: ~2,494 lines**

---

## Binding Architecture

The CommandInstruction enforces five rules that prevent the AI from "chatting" instead of auditing:

1. **Full Compliance** — Read, internalize, and follow every step in the workflow files
2. **No Deviation** — No inventing, skipping, reordering, or overriding prescribed steps
3. **Absolute Precedence** — Workflow files override base knowledge, external sources, and prior instructions
4. **Grounding Requirement** — All analysis must be derived from the workflow processes
5. **Transparent Citation** — Every finding must cite its source: `[filename, section]`

### Auditor's Mindset (4 Lenses)

| Lens | What It Catches |
|------|----------------|
| Value Flow ("follow the money") | Fund theft, insolvency, accounting drift |
| Adversarial Thinking | Lowest-effort, highest-impact exploit paths |
| Historical Awareness | Known exploit pattern matching (Euler, Cream, Nomad, Curve, etc.) |
| Time Discipline | 40/40/20 time-boxing to prevent analysis paralysis |

### Mandatory Validation (4 Checks)

Every finding must pass ALL four before reporting:

| Check | Question |
|-------|----------|
| **Reachability** | Can this execution path actually occur on-chain? |
| **State Freshness** | Does it work with current, not stale, state? |
| **Execution Closure** | Are all external calls and callbacks correctly modeled? |
| **Economic Realism** | Are attacker costs, timing, and constraints feasible? |

---

## Playbook Sections

The Audit_Assistant_Playbook provides 10 structured sections for the full audit lifecycle:

| # | Section | Purpose |
|---|---------|---------|
| 1 | Build Layer | Prepare `merged.txt` with all in-scope code |
| 2 | Main Chat Prompts | 4 AUDIT AGENT roles (Protocol Mapper, Hypothesis Generator, Code Path Explorer, Adversarial Reviewer) |
| 3 | Exploration Chat | Understanding protocol design before security analysis |
| 4 | Working Chat | Deep-dive analysis of surviving hypotheses |
| 5 | Finding Drafting | Triage-friendly report preparation |
| 6 | Scope Index | Navigational artifact for manual code review |
| 7 | Review Mode | Completeness and correctness check of reasoning |
| 8 | SCAN Chats | Signal generators (Paranoid, Access Lifecycle, Accounting, Low-Noise) |
| 9 | Hypotheses Formulation | Transform vague intuitions into testable hypotheses |
| 10 | Scope Transfer | Context packaging for moving to new chats |

---

## Methodology Highlights

### Semantic Phase Analysis (audit-workflow2.md)

Every function is classified into phases, then audited phase-by-phase (not call-order):

| Phase | What It Does | Vulnerability Class |
|-------|-------------|-------------------|
| **SNAPSHOT** | Reads storage | Stale data, frontrunning, reentrancy |
| **ACCOUNTING** | Time/oracle calculations | Manipulation, rounding, precision loss |
| **VALIDATION** | Checks conditions | Bypass, DoS, logic flaws |
| **MUTATION** | Changes balances | Value theft, overflow, slippage |
| **COMMIT** | Writes storage | Inconsistent state, missing events, collisions |

### Known Exploit Pattern Database (audit-workflow1.md)

| Category | Exploits Referenced |
|----------|-------------------|
| Price/Oracle | Euler (2023), Cream (2021), Harvest (2020) |
| Reentrancy | The DAO (2016), Curve read-only (2023), Lendf.Me ERC777 (2020) |
| Access Control | Nomad (2022), Wormhole (2022), Ronin (2022), Parity (2017) |
| Logic/Math | Compound (2021), Cover Protocol (2020), YAM (2020) |
| Flash Loan | bZx (2020), PancakeBunny (2021), Rari/Fei (2022) |

### Protocol-Specific Attack Phases (audit-workflow1.md)

Pre-built attack checklists for:
- **DeFi Lending** — Uncollateralized borrows, unfair liquidation, interest rate manipulation
- **DEX/AMM** — Sandwich attacks, pool draining, impermanent loss exploitation
- **NFT Marketplaces** — Underpriced listings, royalty bypass
- **Bridges** — Fake deposits, double spending, validation bypass
- **Staking/Farming** — Reward calculation errors, share price manipulation

---

## Quick Start

1. **Build** `merged.txt` using the command in [Playbook Section 1](Audit_Assistant_Playbook.md#1-build-layer)
2. **Set** the system prompt from [CommandInstruction.md](CommandInstruction.md)
3. **Map** the protocol with `[AUDIT AGENT: Protocol Mapper]`
4. **Generate** hypotheses with `[AUDIT AGENT: Attack Hypothesis Generator]`
5. **Validate** each hypothesis with `[AUDIT AGENT: Code Path Explorer]`
6. **Draft** confirmed findings using the [Finding Template](audit-workflow1.md#step-61-finding-template)

---

## Companion Resources

| Resource | Purpose |
|----------|---------|
| [report-writing.md](../report-writing.md) | How to write findings that communicate with judges |
| [VULNERABILITY_PATTERNS_INTEGRATION.md](../VULNERABILITY_PATTERNS_INTEGRATION.md) | ClaudeSkills pattern integration status across all frameworks |

---

**Framework Version:** 2.0
**Last Updated:** February 2026
