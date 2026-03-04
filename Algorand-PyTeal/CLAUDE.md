<!-- Managed by docs-for-humans-and-ai skill -->
<!-- Ecosystem: Algorand / PyTeal -->
<!-- Version: 2.0 -->

# Algorand/PyTeal Smart Contract Audit Framework

Covers **Algorand** smart contracts in **PyTeal**, **TEAL**, and **ARC4**. Special attention to transaction field validation, group transaction security, and inner transaction fee pooling.

**Before making changes**, read this file fully. For repo-wide conventions, see [../CLAUDE.md](../CLAUDE.md).

## Directory Structure

```
Algorand-PyTeal/
├── CLAUDE.md                              ← You are here
├── README.md                              ← Human-facing overview + quick start
├── CommandInstruction-Algorand.md         ← System prompt (binding rules, 6 Algorand lenses)
├── Algorand-Audit-Methodology.md          ← Full methodology + ClaudeSkills A1–A9
└── Audit_Assistant_Playbook_Algorand.md   ← Conversation structure (Sections 1–10)
```

## 3-File Architecture

| File | Role | AI Behavior |
|------|------|-------------|
| **CommandInstruction-Algorand.md** | System prompt | Load FIRST. 6 Algorand-specific lenses. |
| **Algorand-Audit-Methodology.md** | Methodology | Phases, checklists, ClaudeSkills A1–A9, Tealer patterns. |
| **Audit_Assistant_Playbook_Algorand.md** | Conversation structure | 10 sections, SCAN prompts, agent roles. |

## Auditor's Mindset (6 Lenses)

| Lens | What It Catches |
|------|----------------|
| Transaction Field Hunting | Unvalidated RekeyTo, CloseRemainderTo, AssetCloseTo fields |
| Group Transaction Thinking | Group size validation, atomic transfer integrity, index assumptions |
| Inner Transaction Fee Awareness | Fee pooling exploitation, unset fees draining app balance |
| Clear State Program Paranoia | OnComplete bypass via clear program, state cleanup failures |
| Smart Signature Precision | Fee bounds, lease protection, rekey protection in LogicSig |
| Asset Opt-In Awareness | Push pattern failures, malicious opt-out timing |

## Critical Attack Vectors (11 Patterns)

| # | Vector | ClaudeSkills ID |
|---|--------|----------------|
| 1 | Rekeying Attack | A1 |
| 2 | Unchecked Transaction Fee | A2 |
| 3 | Closing Account | A3 |
| 4 | Closing Asset | A4 |
| 5 | Group Size Check | A5 |
| 6 | Time-Based Replay | A6 |
| 7 | Access Controls | A7 |
| 8 | Asset ID Verification | A8 |
| 9 | Denial of Service | A9 |
| 10 | Inner Transaction Fee | — |
| 11 | Clear State Transaction | — |

## Algorand Architecture Quick Reference

| Concept | Details |
|---------|---------|
| Languages | PyTeal (Python DSL), TEAL (assembly), ARC4 (ABI) |
| Execution | Approval Program + Clear State Program |
| Storage | Global State (64 KV) + Local State (16 per user) |
| Transactions | Atomic Groups (up to 16 txs) |
| Fees | Fee Pooling across group transactions |

## Tool References

| Tool | Purpose |
|------|---------|
| **Tealer** | Static analyzer (`unprotected-rekey`, `group-size-check`, `update-application-check`) |
| **Algorand Sandbox** | Local testing environment |
| **PyTeal** | Python DSL for smart contracts |

## Editing Rules

- Transaction field attacks (RekeyTo, CloseRemainderTo, AssetCloseTo) are Algorand's #1 vulnerability class
- Group transaction patterns are unique to Algorand — no equivalent in other ecosystems
- Inner transaction fee pooling is a chain-specific DoS vector
- ClaudeSkills patterns A1–A9 are integrated throughout the methodology

<!-- LOCAL CUSTOMIZATIONS — everything below this line is preserved on update -->
