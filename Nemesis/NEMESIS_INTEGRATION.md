# NEMESIS Integration Status

> **Purpose:** Track how NEMESIS iterative reasoning is wired into each ecosystem framework.
> **Status:** v1.0 — All 6 ecosystem frameworks updated with NEMESIS phase hook.
> **Source:** [nemesis-auditor](https://github.com/sainikethan/nemesis-auditor) — MIT License

---

## Integration Model

NEMESIS integrates as an **optional deep-reasoning phase** in each ecosystem's audit workflow. It does NOT replace any existing phase — it adds a new one.

### How Findings Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  NEMESIS produces:                                              │
│  ├─ Verified findings (NEM-001, NEM-002, ...)                   │
│  ├─ Suspects (functions/state needing further investigation)    │
│  ├─ Coupled State Dependency Map                                │
│  └─ Cross-feed discovery paths                                  │
│                                                                  │
│  Framework consumes:                                             │
│  ├─ Findings → feed into Hypothesis Generator as confirmed      │
│  │             signal (same as Pashov scan results)              │
│  ├─ Suspects → become hypotheses for Code Path Explorer         │
│  ├─ Coupled State Map → enriches Protocol Mapper output         │
│  └─ Discovery paths → tag findings for report attribution       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Per-Ecosystem Integration

### SolidityEVM

| Aspect | Detail |
|--------|--------|
| **Phase position** | Phase 0.5 — after Pashov fast scan, before Phase 1 Understanding |
| **Trigger** | `[AUDIT AGENT: NEMESIS Deep Audit]` |
| **Files modified** | `CommandInstruction.md` — AUDIT WORKFLOW INTEGRATION section |
| **Feed-forward** | NEMESIS findings merge with Pashov findings into Phase 2 hypotheses |
| **Complementarity** | Pashov catches pattern-match vectors; NEMESIS catches reasoning + state coupling bugs |

### Rust (CosmWasm / Solana / Substrate)

| Aspect | Detail |
|--------|--------|
| **Phase position** | Phase 0 — before Phase 1 Understanding |
| **Trigger** | `[AUDIT AGENT: NEMESIS Deep Audit]` |
| **Files modified** | `CommandInstruction-Rust.md` — AUDIT WORKFLOW INTEGRATION section |
| **Feed-forward** | NEMESIS findings feed into Phase 2 hypotheses |
| **Complementarity** | Framework catches Rust-specific patterns (ownership, CPI, panic); NEMESIS catches logic + state coupling |

### Go (Cosmos SDK / IBC / CometBFT)

| Aspect | Detail |
|--------|--------|
| **Phase position** | Phase 0 — before Phase 1 Exploration |
| **Trigger** | `[AUDIT AGENT: NEMESIS Deep Audit]` |
| **Files modified** | `CommandInstruction-Go.md` — AUDIT WORKFLOW INTEGRATION section |
| **Feed-forward** | NEMESIS findings feed into Phase 2 hypotheses |
| **Complementarity** | Framework catches Go/Cosmos patterns (C1–C6, ABCI); NEMESIS catches logic + state coupling |

### Cosmos-SDK (Chain-Level)

| Aspect | Detail |
|--------|--------|
| **Phase position** | Phase 0 — before Phase 1 Architecture Mapping |
| **Trigger** | `[AUDIT AGENT: NEMESIS Deep Audit]` |
| **Files modified** | `CommandInstruction-Cosmos.md` — AUDIT WORKFLOW INTEGRATION section |
| **Feed-forward** | NEMESIS coupled state map enriches cross-module invariant analysis |
| **Complementarity** | Framework catches governance/consensus/IBC; NEMESIS catches module state coupling bugs |

### Cairo (StarkNet)

| Aspect | Detail |
|--------|--------|
| **Phase position** | Phase 0 — before Phase 1 Exploration |
| **Trigger** | `[AUDIT AGENT: NEMESIS Deep Audit]` |
| **Files modified** | `CommandInstruction-Cairo.md` — AUDIT WORKFLOW INTEGRATION section |
| **Feed-forward** | NEMESIS findings feed into Phase 2 hypotheses |
| **Complementarity** | Framework catches Cairo patterns (felt252, L1↔L2, C1–C6); NEMESIS catches logic + state coupling |

### Algorand (PyTeal / TEAL)

| Aspect | Detail |
|--------|--------|
| **Phase position** | Phase 0 — before Phase 1 Exploration |
| **Trigger** | `[AUDIT AGENT: NEMESIS Deep Audit]` |
| **Files modified** | `CommandInstruction-Algorand.md` — AUDIT WORKFLOW INTEGRATION section |
| **Feed-forward** | NEMESIS findings feed into Phase 2 hypotheses |
| **Complementarity** | Framework catches Algorand patterns (A1–A9, rekey, groups); NEMESIS catches logic + state coupling |

---

## What NEMESIS Adds to Each Framework

| Aspect | Before NEMESIS | After NEMESIS |
|--------|---------------|--------------|
| **Logic bug coverage** | Hypothesis-driven (human generates hypotheses) | Systematic first-principles interrogation of every function |
| **State coupling analysis** | Manual invariant detection via semantic phases | Automated coupled state dependency mapping + mutation matrix |
| **Cross-cutting bugs** | Found if auditor hypothesizes them | Found by iterative cross-feed between Feynman and State passes |
| **Partial operation bugs** | Ad-hoc checking | Systematic parallel path comparison (withdraw vs liquidate vs emergency) |
| **Defensive code masking** | Not specifically targeted | Explicit masking pattern detection (ternary clamps, min caps, try-catch) |
| **Multi-tx state drift** | Time-dependent analysis in semantic phases | Explicit multi-step journey tracing with accumulated error analysis |

---

## Validation Gate Alignment

NEMESIS findings are subject to the same framework validation requirements:

| Framework Check | NEMESIS Equivalent |
|----------------|-------------------|
| **Reachability** | Phase 8 Verification Gate — code trace confirms execution path |
| **State Freshness** | State Inconsistency Auditor Phase 6 — multi-step journey confirms current state |
| **Execution Closure** | Feynman Category 7 — external call reordering models all callbacks |
| **Economic Realism** | Phase 0 Recon Q0.1 — attack goals must be economically viable |

NEMESIS findings that pass its own verification gate will also pass the framework's 4 mandatory validation checks.
