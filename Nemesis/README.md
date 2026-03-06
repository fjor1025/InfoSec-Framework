# NEMESIS — Deep Iterative Reasoning Auditor

> **Version:** 1.0 — Integrated into InfoSec-Framework
> **Source:** [nemesis-auditor](https://github.com/sainikethan/nemesis-auditor) — MIT License
> **Type:** Language-agnostic iterative audit agent (Solidity, Move, Rust, Go, C++, Python, TypeScript)
> **Benchmark:** 100% precision, 52.9% Sherlock coverage (9/17 findings, 3/5 Highs, 6/12 Mediums)

---

## What This Is

NEMESIS is an iterative deep-logic security audit agent that combines two complementary sub-auditors in an alternating feedback loop to find bugs that neither can catch alone.

| Pass | Agent | What It Finds |
|------|-------|---------------|
| 1 | **Feynman Auditor** | Business logic bugs via first-principles questioning — every line challenged, every assumption exposed |
| 2 | **State Inconsistency Auditor** | Coupled state desync bugs — maps every mutation path, finds gaps where one side updates without the other |
| 3+ | **Alternating targeted passes** | Each pass feeds findings into the next until convergence (max 6 passes) |

### How It Differs From Existing Framework Tools

| Aspect | InfoSec Framework (Existing) | Pashov Skills (Solidity) | NEMESIS (New) |
|--------|------------------------------|--------------------------|---------------|
| **Approach** | Structured hypothesis-driven audit | Parallelized vector pattern scan | Iterative reasoning loop |
| **Strength** | Methodology + ecosystem-specific lenses | Broad coverage of 170 known vectors | Deep logic + state coupling bugs |
| **Language** | Per-ecosystem (Solidity, Rust, Go, Cairo, Algorand) | Solidity only | Language-agnostic |
| **Finding type** | Manual hypothesis validation | Known vulnerability patterns | Unknown bugs from reasoning |
| **Best for** | Full audit lifecycle | Fast triage, pre-audit scan | Complex business logic, coupled state |

### Sherlock Benchmark Comparison

| Metric | Pashov Skills | NEMESIS | Combined |
|--------|---------------|---------|----------|
| **Total findings** | 6 | 11 | 14 unique |
| **True positives** | 5 | 11 | 14 |
| **False positives** | 1 | 0 | 1 |
| **Precision** | 83.3% | 100% | 93.3% |
| **Sherlock coverage** | 17.6% (3/17) | 52.9% (9/17) | 52.9% (9/17) |
| **Highs matched** | 1/5 | 3/5 | 3/5 |
| **Mediums matched** | 2/12 | 6/12 | 6/12 |

---

## Architecture

NEMESIS is built from 3 Claude Code skills, now included in this directory:

```
Nemesis/
├── CLAUDE.md                              # AI agent context
├── README.md                              # This file
├── NEMESIS_INTEGRATION.md                 # Per-ecosystem integration status
└── skills/
    ├── nemesis-auditor/
    │   └── SKILL.md                       # The orchestrator — runs the iterative loop
    ├── feynman-auditor/
    │   └── SKILL.md                       # First-principles logic bug finder (7 question categories, 972 lines)
    └── state-inconsistency-auditor/
        └── SKILL.md                       # Coupled state desync detector (8 phases, 517 lines)
```

### Feynman Auditor — 7 Question Categories

| Category | Core Question | What It Catches |
|----------|--------------|-----------------|
| 1. Purpose | WHY does this line exist? | Dead code, undocumented invariants |
| 2. Ordering | What if I move this line? | Reentrancy, state gaps, race conditions |
| 3. Consistency | WHY does A have this guard but B doesn't? | Missing access control, asymmetric validation |
| 4. Assumptions | What is implicitly trusted? | Caller type, external data, state preconditions |
| 5. Boundaries | What breaks at the edges? | First/last call, dust, empty state, self-reference |
| 6. Return/Error | What happens on failure paths? | Ignored returns, silent failures, resource leaks |
| 7. Call Reorder + Multi-Tx | Swap external calls + multi-tx state drift | CEI violations, stale state accumulation |

### State Inconsistency Auditor — 8 Phases

| Phase | What It Does |
|-------|-------------|
| 1. Map Coupled Pairs | Identify all state variables that must stay in sync |
| 2. Find Mutations | List every function and path that modifies each state variable |
| 3. Cross-Check | For each mutation of State A, verify State B is also updated |
| 4. Ordering Analysis | Check operation ordering within functions for stale reads |
| 5. Parallel Paths | Compare similar operations (withdraw vs liquidate) for consistency |
| 6. Multi-Step Journeys | Trace user sequences for accumulated state drift |
| 7. Masking Detection | Find defensive code that hides broken invariants |
| 8. Verification Gate | Code trace + PoC for all Critical/High/Medium findings |

---

## Integration With InfoSec Framework

NEMESIS integrates as an optional deep-reasoning phase in each ecosystem's audit workflow:

| Ecosystem | Phase Position | Trigger |
|-----------|---------------|---------|
| **SolidityEVM** | Phase 0.5 — after Pashov fast scan, before hypothesis generation | `[AUDIT AGENT: NEMESIS Deep Audit]` |
| **Rust** | Phase 0 — before hypothesis generation | `[AUDIT AGENT: NEMESIS Deep Audit]` |
| **Go / Cosmos SDK** | Phase 0 — before hypothesis generation | `[AUDIT AGENT: NEMESIS Deep Audit]` |
| **Cairo / StarkNet** | Phase 0 — before hypothesis generation | `[AUDIT AGENT: NEMESIS Deep Audit]` |
| **Algorand / PyTeal** | Phase 0 — before hypothesis generation | `[AUDIT AGENT: NEMESIS Deep Audit]` |

### Combined Workflow (Solidity Example)

```
┌──────────────────────────────────────────────────────────────────┐
│ PHASE 0: FAST SCAN — Pashov Parallelized Scan (pattern-match)   │
│ PHASE 0.5: DEEP REASONING — NEMESIS Iterative Loop (logic+state)│
│ PHASE 1: UNDERSTANDING — Protocol Mapper                        │
│ PHASE 2: HYPOTHESIS — merge Pashov + NEMESIS + manual signals   │
│ PHASE 3: DEEP VALIDATION — Code Path Explorer per hypothesis    │
│ PHASE 4: FINDING DOCUMENTATION                                  │
│ PHASE 5: ADVERSARIAL REVIEW                                     │
└──────────────────────────────────────────────────────────────────┘
```

### When to Use NEMESIS vs Pashov vs Manual

| Situation | Recommended Tool |
|-----------|-----------------|
| Fast pre-audit triage (<2,500 SLOC Solidity) | Pashov Parallelized Scan |
| Complex business logic, custom math, novel mechanisms | NEMESIS |
| Deep manual audit with structured methodology | InfoSec Framework phases |
| Maximum coverage (serious audit) | All three: Pashov → NEMESIS → Manual phases |
| Non-Solidity codebase | NEMESIS (language-agnostic) + ecosystem-specific framework |

---

## Usage

### Via Claude Code Slash Commands

```
/nemesis                        # Full iterative audit
/nemesis --contract MyToken     # Audit a single contract/module
/nemesis --pass1                # Only Feynman Auditor
/nemesis --pass2                # Only State Inconsistency Auditor
/nemesis --continue             # Resume interrupted audit
/feynman                        # Feynman Auditor standalone
/state-audit                    # State Inconsistency Auditor standalone
```

### Via InfoSec Framework Agent Trigger

```
[AUDIT AGENT: NEMESIS Deep Audit]
```

This invokes the full NEMESIS iterative loop within the InfoSec Framework workflow.

---

## Output Format

Findings are saved to `.audit/findings/`:

```
.audit/findings/
├── feynman-pass1.md          # Pass 1 Feynman findings
├── state-pass2.md            # Pass 2 State Inconsistency findings
├── feynman-pass3.md          # Pass 3 targeted Feynman (if needed)
├── state-pass4.md            # Pass 4 targeted State (if needed)
└── nemesis-verified.md       # Final consolidated + verified report
```

Each finding includes:

```markdown
### Finding NEM-001: [Title]
**Severity:** CRITICAL | HIGH | MEDIUM | LOW
**Discovery Path:** Feynman-only | State-only | Cross-feed Pass N → Pass M

**Root Cause:** [What is broken and why]
**Trigger Sequence:**
1. [Step-by-step to reproduce]

**Impact:** [What goes wrong — fund loss, locked state, etc.]
**Fix:** [Minimal code change]
**Verification:** Code trace | PoC test | Both
```

---

## Attribution

Built by [@sainikethan](https://github.com/sainikethan). [MIT License](https://github.com/sainikethan/nemesis-auditor/blob/main/LICENSE).
