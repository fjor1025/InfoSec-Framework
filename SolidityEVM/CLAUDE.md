<!-- Managed by docs-for-humans-and-ai skill -->
<!-- Ecosystem: Solidity/EVM -->
<!-- Version: 3.1 -->

# SolidityEVM Audit Framework

The **benchmark framework** that all other ecosystem frameworks were modeled after. Covers Solidity smart contracts on EVM-compatible chains (Ethereum, Arbitrum, Optimism, Base, Polygon, BSC, etc.).

**Before making changes**, read this file fully. For repo-wide conventions, see [../CLAUDE.md](../CLAUDE.md).

## Directory Structure

```
SolidityEVM/
├── CLAUDE.md                          ← You are here
├── README.md                          ← Human-facing overview + quick start
├── CommandInstruction.md              ← System prompt (binding rules, 10 lenses)
├── audit-workflow1.md                 ← Manual methodology (7 phases, 11 attack categories, 170-vector Pashov)
├── audit-workflow2.md                 ← Semantic phase analysis (SNAPSHOT→COMMIT + Spec Completeness)
├── Audit_Assistant_Playbook.md        ← Conversation structure (19 SCAN prompts, 5 agents + Pashov)
└── pashov-skills/                     ← Pashov Audit Group integration
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

## 3-File Architecture

| File | Role | Lines | AI Behavior |
|------|------|-------|-------------|
| **CommandInstruction.md** | System prompt | ~200 | Load FIRST. Binding rules override all other knowledge. |
| **audit-workflow1.md** | Manual methodology | ~1150 | Reference during Code Path Explorer and hypothesis validation. |
| **audit-workflow2.md** | Semantic phases | ~620 | Classify functions by phase; audit phase-by-phase not call-order. |
| **Audit_Assistant_Playbook.md** | Conversation structure | ~1960 | Defines 5 agent roles, 19 SCAN prompts, and the audit lifecycle. |
| **pashov-skills/** | Parallelized scan | ~700 | Optional Phase 0 — automated triage before manual audit. |

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
| [evmresearch.io](https://evmresearch.io) | 300+ notes, 6 knowledge areas | v3.0 |
| [QuillAudits Claude Skills V1](https://github.com/quillai-network/qs_skills) | 10 semantic audit skills | v2.1 |
| [Pashov Audit Group](https://github.com/pashov/skills) | 170 attack vectors, parallelized agents | v3.1 |
| OWASP SC Top 10 (2025) | 12 extended categories | v3.0 |

## Editing Rules

- This is the **benchmark** — changes here may need to propagate to other ecosystems
- Never weaken the 5 Core Rules of Engagement or 4 Mandatory Validation Checks
- New attack vectors must cross-reference existing workflow steps in audit-workflow1.md
- New SCAN prompts go in Section 8 of the Playbook
- New agent roles go in Section 2 of the Playbook
- Version bump required for any integration (update header, README, root README)
- Pashov attack vectors (attack-vectors-*.md) are verbatim copies — edit only via adaptation files

<!-- LOCAL CUSTOMIZATIONS — everything below this line is preserved on update -->
