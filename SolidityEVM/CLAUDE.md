<!-- Managed by docs-for-humans-and-ai skill -->
<!-- Ecosystem: Solidity/EVM -->
<!-- Version: 4.0 (Majeur God Mode) -->

# SolidityEVM Audit Framework v4.0

The **benchmark framework** that all other ecosystem frameworks were modeled after. Covers Solidity smart contracts on EVM-compatible chains (Ethereum, Arbitrum, Optimism, Base, Polygon, BSC, etc.).

**v4.0 "God Mode"**: Multi-auditor cross-validation methodology derived from [majeur](https://github.com/z0r0z/majeur) audit corpus achieving ~8% FP rate vs ~60% baseline.

**Before making changes**, read this file fully. For repo-wide conventions, see [../CLAUDE.md](../CLAUDE.md).

## Directory Structure

```
SolidityEVM/
├── CLAUDE.md                          ← You are here
├── README.md                          ← Human-facing overview + quick start
├── CommandInstruction.md              ← System prompt (binding rules, 10 lenses, v4.0 god Mode)
├── audit-workflow1.md                 ← Manual methodology (7 phases, 11 attack categories, 170-vector Pashov)
├── audit-workflow2.md                 ← Semantic phase analysis (SNAPSHOT→COMMIT + Spec Completeness)
├── Audit_Assistant_Playbook.md        ← Conversation structure (19 SCAN prompts, 5 agents + Pashov)
├── advanced-poc-patterns.md           ← Advanced PoC templates (mainnet fork, flash loans, L2, MEV)
├── solidity-checks.md                 ← Quick DeFi tricks + protocol lookup table (v4.0)
│
├── ╔═══════════════════════════════════════════════════════════════════════╗
├── ║                     v4.0 MAJEUR GOD MODE (NEW)                        ║
├── ╚═══════════════════════════════════════════════════════════════════════╝
├── MAJEUR-METHODOLOGY.md              ← Multi-auditor cross-validation architecture (v4.0)
├── FALSE-POSITIVE-CRITERIA.md         ← Documented FP criteria per fv-sol category (v4.0)
├── SHARP-EDGES.md                     ← Design footgun detection + code maturity (v4.0)
├── CERTORA-INTEGRATION.md             ← Formal verification property patterns (v4.0)
│
├── ╔═══════════════════════════════════════════════════════════════════════╗
├── ║                     v3.3 COMPONENTS (ENHANCED)                        ║
├── ╚═══════════════════════════════════════════════════════════════════════╝
├── FINDING-FORMAT.md                  ← Standardized format + Review annotations (v4.0)
├── MULTI-EXPERT.md                    ← 3-round validation + Forefy attribution (v4.0)
├── TRIAGER.md                         ← Customer validation + confidence [75-100] (v4.0)
├── SOLODIT-MCP.md                     ← Solodit 20k+ findings integration (v3.3)
├── secure-development-patterns.md     ← OpenZeppelin integration validation (v3.3)
├── reference/                         ← Protocol context + vulnerability patterns
│   ├── protocols/                     ← 21 protocol-type context files
│   │   ├── lending.md                 ← Lending/borrowing patterns, 10,600+ real findings
│   │   ├── dexes.md                   ← AMM/DEX patterns
│   │   ├── bridges.md                 ← Cross-chain bridge patterns
│   │   ├── staking.md                 ← Staking/liquid staking patterns
│   │   ├── governance.md              ← DAO/voting patterns
│   │   ├── yield.md                   ← Yield aggregator patterns
│   │   ├── derivatives.md             ← Perpetuals/options patterns
│   │   └── ... (21 total)             ← See reference/protocols/ for full list
│   └── fv-sol/                        ← 10 vulnerability pattern categories
│       ├── fv-sol-1-reentrancy/       ← Classic + read-only + callback variants
│       ├── fv-sol-2-precision-errors/ ← Fixed-point, ERC4626 rounding, decimals
│       ├── fv-sol-3-arithmetic-errors/← Overflow, assembly pitfalls
│       ├── fv-sol-4-bad-access-control/← ACL, signatures, hash collision
│       ├── fv-sol-5-logic-errors/     ← Business logic, deployment config
│       ├── fv-sol-6-unchecked-returns/← External call validation
│       ├── fv-sol-7-proxy-insecurities/← Proxy patterns, upgrade lifecycle
│       ├── fv-sol-8-slippage/         ← MEV, sandwich, oracle front-running
│       ├── fv-sol-9-unbounded-loops/  ← DoS, gas griefing
│       └── fv-sol-10-oracle-manipulation/← Oracle attacks, L2 sequencer
└── pashov-skills/                     ← Pashov Audit Group integration
    ├── CLAUDE.md                      ← AI agent context
    ├── SKILL.md                       ← Orchestrator (discovers files, spawns agents, merges report)
    ├── VERSION                        ← Upstream version tracker
    ├── README.md                      ← Integration overview + comparison
    ├── finding-validation.md          ← FP gate (3 checks) + confidence scoring (100-point)
    ├── report-formatting.md           ← Output template for Pashov scan reports
    ├── agents/
    │   ├── vector-scan-agent.md       ← Agents 1–4 (Sonnet) instructions
    │   └── adversarial-reasoning-agent.md ← Agent 5 (Opus) instructions
    └── attack-vectors/
        ├── attack-vectors-1.md        ← Vectors 1–42
        ├── attack-vectors-2.md        ← Vectors 43–85
        ├── attack-vectors-3.md        ← Vectors 86–128
        └── attack-vectors-4.md        ← Vectors 129–170
```

## v4.0 "god Mode" Enhancements

| Component | Source | Value Add |
|-----------|--------|-----------|
| **MAJEUR-METHODOLOGY.md** | majeur audit corpus | Multi-auditor cross-validation achieving ~8% FP rate |
| **FALSE-POSITIVE-CRITERIA.md** | majeur + fv-sol | Documented FP criteria per vulnerability category |
| **SHARP-EDGES.md** | Trail of Bits Skills | Design footgun detection + code maturity scoring |
| **CERTORA-INTEGRATION.md** | majeur/certora | Formal verification property patterns (142 properties) |
| **Review Annotations** | majeur triaging | `> **Review:** [verdict]. [reasoning]. [duplicates]` format |
| **Confidence Scoring [75-100]** | majeur + Pashov | Systematic confidence calibration with decision thresholds |
| **Cross-Auditor Deduplication** | majeur corpus | "Duplicate of Auditor1 #X / Auditor2 #Y" tagging |
| **Known Findings (KF#)** | majeur pattern | Pre-established intentional behaviors list |

## v3.3 Components (Enhanced)

| Component | Source | Value Add |
|-----------|--------|-----------|
| **reference/protocols/** | .context framework | 21 protocol-specific context files with 10,600+ real finding patterns |
| **reference/fv-sol/** | .context framework | 10 structured vulnerability categories with case studies and mitigations |
| **MULTI-EXPERT.md** | .context framework | 3-round validation + Forefy attribution |
| **TRIAGER.md** | .context framework | Customer validation + confidence [75-100] scoring |
| **FINDING-FORMAT.md** | .context framework | Standardized format with Review annotations |
| **SOLODIT-MCP.md** | claudit MCP | 20k+ real findings for prior art validation |
| **secure-development-patterns.md** | openzeppelin-skills | OpenZeppelin integration validation patterns |
| **solidity-checks.md** | .context framework | Quick tricks + protocol lookup table |

## 3-File Architecture (v4.0 Extended)

| File | Role | Lines | AI Behavior |
|------|------|-------|-------------|
| **CommandInstruction.md** | System prompt | ~350 | Load FIRST. Binding rules override all other knowledge. |
| **audit-workflow1.md** | Manual methodology | ~1150 | Reference during Code Path Explorer and hypothesis validation. |
| **audit-workflow2.md** | Semantic phases | ~620 | Classify functions by phase; audit phase-by-phase not call-order. |
| **Audit_Assistant_Playbook.md** | Conversation structure | ~1960 | Defines 5 agent roles, 19 SCAN prompts, and the audit lifecycle. |
| **pashov-skills/** | Parallelized scan | ~1,300 | Optional Phase 0 — automated triage before manual audit. |
| **MAJEUR-METHODOLOGY.md** | god Mode architecture | ~450 | Multi-auditor cross-validation + review annotation format. |
| **FALSE-POSITIVE-CRITERIA.md** | FP elimination | ~500 | Check before reporting ANY finding. |

## Auditor's Mindset (10 Lenses)

| # | Lens | What It Catches |
|---|------|----------------|
| 1 | Value Flow ("follow the money") | Fund theft, insolvency, accounting drift |
| 2 | Adversarial Thinking | Lowest-effort, highest-impact exploit paths |
| 3 | Historical Awareness | Known exploit pattern matching (40+ exploits, 2016–2025) |
| 4 | Guard Consistency | Functions missing guards that peers enforce on same state |
| 5 | Invariant Awareness | Mathematical relationships between state variables that could break |
| 6 | OWASP Coverage | SC01–SC10 category completeness (12 extended categories) |
| 7 | Time Discipline | 40/40/20 time-boxing to prevent analysis paralysis |
| 8 | Specification Completeness | Gap between spec and implementation (92% of exploited contracts passed reviews) |
| 9 | Compiler Trust Boundary | via-IR, optimizer, Yul — compiler output ≠ source intent |
| 10 | Account Abstraction Awareness | ERC-4337/EIP-7702/ERC-7579 invalidate msg.sender, extcodesize, tx.origin assumptions |

## Semantic Phases

| Phase | What It Does | Key Vulnerability Class |
|-------|-------------|------------------------|
| SNAPSHOT | Reads storage | Stale data, frontrunning, reentrancy, EIP-1153 cross-call |
| ACCOUNTING | Time/oracle calculations | Manipulation, rounding, precision loss |
| VALIDATION | Checks conditions | Bypass, DoS, logic flaws, developer assumption gaps |
| MUTATION | Changes balances | Value theft, overflow, slippage |
| COMMIT | Writes storage | Inconsistent state, missing events, CPIMP windows |
| SPEC COMPLETENESS | Cross-cutting analysis | Developer assumptions, temporal gaps, trust collapse |

## Agent Roles

| Agent | Purpose | Trigger |
|-------|---------|---------|
| Protocol Mapper | Map modules/roles/flows | `[AUDIT AGENT: Protocol Mapper]` |
| Hypothesis Generator | Generate attack scenarios | `[AUDIT AGENT: Attack Hypothesis Generator]` |
| Code Path Explorer | Validate hypotheses with code | `[AUDIT AGENT: Code Path Explorer]` |
| Adversarial Reviewer | Challenge and stress-test findings | `[AUDIT AGENT: Adversarial Reviewer]` |
| Pashov Parallelized Scan | 170-vector automated triage | `[AUDIT AGENT: Pashov Parallelized Scan]` |

## Key Integrations

| Source | What It Provides | Version |
|--------|-----------------|---------|
| [majeur](https://github.com/z0r0z/majeur) | Multi-auditor methodology, 23+ AI auditor cross-validation | v4.0 |
| [evmresearch.io](https://evmresearch.io) | 300+ notes, 6 knowledge areas | v3.0 |
| [QuillAudits Claude Skills V1](https://github.com/quillai-network/qs_skills) | 10 semantic audit skills | v2.1 |
| [Pashov Audit Group](https://github.com/pashov/skills) | 170 attack vectors, parallelized agents | v3.1 |
| [Trail of Bits Skills](https://github.com/trailofbits/skills) | Sharp Edges + Code Maturity | v4.0 |
| OWASP SC Top 10 (2025) | 12 extended categories | v3.0 |

## god Mode Workflow

```
┌─────────────────────────────────────────────────────────────────────┐
│                     GOD MODE AUDIT WORKFLOW                         │
├─────────────────────────────────────────────────────────────────────┤
│ Phase 0: Setup                                                      │
│ └── Load protocol context (reference/protocols/*.md)               │
│ └── Load fv-sol patterns (reference/fv-sol/*.md)                   │
│ └── Establish Known Findings list (KF#1-N)                         │
├─────────────────────────────────────────────────────────────────────┤
│ Phase 1: Multi-Auditor Scan (Parallel)                              │
│ ├── [Auditor 1] Pashov Deep Mode (5 agents, 170 vectors)           │
│ ├── [Auditor 2] Forefy Multi-Expert (MULTI-EXPERT.md)              │
│ ├── [Auditor 3] Solodit Prior Art (SOLODIT-MCP.md)                 │
│ ├── [Auditor 4] Sharp Edges (SHARP-EDGES.md)                       │
│ └── [Auditor 5] Certora FV (CERTORA-INTEGRATION.md)                │
├─────────────────────────────────────────────────────────────────────┤
│ Phase 2: Cross-Auditor Consolidation                                │
│ ├── Merge all findings                                              │
│ ├── Tag duplicates: "Duplicate of Auditor1 #X / Auditor2 #Y"       │
│ ├── Apply FP criteria (FALSE-POSITIVE-CRITERIA.md)                 │
│ └── Assign confidence [75-100]                                      │
├─────────────────────────────────────────────────────────────────────┤
│ Phase 3: Triager Validation                                         │
│ ├── Each finding: > **Review:** [verdict]. [reasoning].            │
│ └── Verdicts: Not a bug / Valid observation / Design tradeoff /    │
│               Configuration-dependent / Production blocker          │
├─────────────────────────────────────────────────────────────────────┤
│ Phase 4: Final Report                                               │
│ ├── Novel findings only (deduplicated)                              │
│ └── Confidence-weighted severity                                    │
└─────────────────────────────────────────────────────────────────────┘
```

## Editing Rules

- This is the **benchmark** — changes here may need to propagate to other ecosystems
- Never weaken the 5 Core Rules of Engagement or 4 Mandatory Validation Checks
- New attack vectors must cross-reference existing workflow steps in audit-workflow1.md
- New SCAN prompts go in Section 8 of the Playbook
- New agent roles go in Section 2 of the Playbook
- Version bump required for any integration (update header, README, root README)
- Pashov attack vectors (attack-vectors-*.md) are verbatim copies — edit only via adaptation files

<!-- LOCAL CUSTOMIZATIONS — everything below this line is preserved on update -->
