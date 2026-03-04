# Pashov Audit Group Skills — Integrated Reference

> **Source:** [Pashov Audit Group Skills](https://github.com/pashov/skills) — MIT Licensed
> **Integration:** v1.0 — Integrated into InfoSec-Framework SolidityEVM module
> **Purpose:** Parallelized agentic security audit with 170 attack vectors, confidence-scored findings, and multi-agent orchestration

---

## What This Is

A parallelized smart contract security audit system built by [Pashov Audit Group](https://www.pashov.com/). It discovers in-scope Solidity files, spawns multiple scanning agents in parallel, then merges and deduplicates their findings into a single confidence-scored report.

**Not a substitute for a formal audit** — but the check you should never skip.

### How It Complements the InfoSec Framework

| Aspect | InfoSec Framework (Existing) | Pashov Skills (Integrated) |
|--------|------------------------------|---------------------------|
| **Approach** | Manual hypothesis-driven audit with structured conversation roles | Automated parallelized scan with agentic decomposition |
| **Attack Vectors** | Pattern-matching against 40+ known exploits + OWASP SC Top 10 | 170 atomic attack vectors with FP gates per vector |
| **Finding Scoring** | Severity matrix (Critical/High/Medium/Low) | Confidence scoring (0-100) with deduction rules |
| **Agent Model** | 4 sequential roles (Mapper → Generator → Explorer → Reviewer) | 5 parallel agents (4 vector scanners + 1 adversarial reasoner) |
| **Best For** | Deep manual audits, hypothesis validation, report writing | Fast automated scanning, pre-audit triage, CI integration |

### Combined Workflow

```
┌──────────────────────────────────────────────────────────────────┐
│ PHASE 0: FAST SCAN (Pashov Parallelized Audit)                   │
│ └─ Invoke: [AUDIT AGENT: Pashov Parallelized Scan]               │
│    └─ Agents 1-4: Vector scan (170 vectors, parallel)            │
│    └─ Agent 5: Adversarial reasoning (DEEP mode only)            │
│    └─ Output: Confidence-scored findings, merged & deduplicated  │
├──────────────────────────────────────────────────────────────────┤
│ PHASE 1: UNDERSTANDING (InfoSec Protocol Mapper)                 │
│ └─ Build mental model from Pashov scan + manual review           │
├──────────────────────────────────────────────────────────────────┤
│ PHASE 2-5: Standard InfoSec workflow                             │
│ └─ Hypothesis generation, deep validation, finding docs, review  │
│ └─ Pashov findings feed into hypothesis generation               │
└──────────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
pashov-skills/
├── README.md                          # This file
├── finding-validation.md              # FP gate + confidence scoring
├── report-formatting.md               # Output format for scan reports
├── agents/
│   ├── vector-scan-agent.md           # Vector scanning agent instructions
│   └── adversarial-reasoning-agent.md # Deep adversarial reasoning agent
└── attack-vectors/
    ├── attack-vectors-1.md            # Vectors 1-42
    ├── attack-vectors-2.md            # Vectors 43-84
    ├── attack-vectors-3.md            # Vectors 85-126
    └── attack-vectors-4.md            # Vectors 127-170
```

---

## Attack Vector Coverage (170 Vectors)

| Category | Vector Count | Key Areas |
|----------|-------------|-----------|
| Signature & Cryptography | V1, V21, V27, V37, V51, V127, V138, V157, V161, V170 | Malleability, replay, commit-reveal, abi.encodePacked collision |
| ERC Token Standards | V2, V10-V14, V19, V33, V40, V49-V50, V63-V68, V80-V81, V83-V84, V104, V107, V109, V116, V126, V134, V148 | ERC20/721/1155/4626 edge cases, rounding, callbacks |
| Access Control | V15, V38, V79, V101, V113, V118, V139, V150 | Missing modifiers, delegation, uninitialized implementations |
| Reentrancy | V12, V52, V60, V83, V105, V153, V156 | Classic, cross-function, read-only, ERC-777, cross-chain |
| Oracle & Price Feeds | V55, V69, V86, V93, V124, V137, V141, V145, V164 | Chainlink staleness, TWAP manipulation, L2 sequencer |
| Flash Loan & MEV | V3, V86, V90, V125, V131, V144 | Snapshot-based benefits, sandwich, governance |
| Proxy & Upgrades | V6, V18, V20, V28, V36, V46, V48, V53, V58, V106, V113, V118, V123, V139, V149, V155, V162, V168 | UUPS, Diamond, storage collision, CPIMP |
| Math & Precision | V4, V26, V32, V35, V45, V56, V66-V67, V70, V120, V133, V135-V136, V167 | Division-before-multiply, truncation, inflation attack |
| DoS & Griefing | V10, V22, V25, V30, V42, V54, V77, V82, V110, V129, V146 | Unbounded loops, push payment, return bomb |
| Cross-Chain & LayerZero | V7, V24, V38-V39, V42, V44, V47, V59, V71, V114, V117, V119, V140, V142-V143, V156, V159-V160 | lzCompose, DVN, peer validation, rate limits |
| Assembly & Low-Level | V34, V62, V74, V76, V78, V85, V91-V92, V99, V158, V166, V169 | Scratch space, dirty bits, returndatasize, free memory pointer |
| Account Abstraction | V100, V108, V122, V150, V163 | validateUserOp, paymaster, counterfactual wallet |
| Deployment & Configuration | V31, V72, V88, V96, V102-V103, V132 | Immutable misconfiguration, nonce gaps, partial bootstrap |

---

## Known Limitations

- **Codebase size**: Works best up to ~2,500 lines of Solidity. Past ~5,000 lines, triage accuracy drops.
- **What AI misses**: AI is strong at pattern matching but struggles with relational reasoning: multi-transaction state setups, specification/invariant bugs, cross-protocol composability, game-theory attacks, and off-chain assumptions.
- **Complementary**: AI catches what humans forget to check. Humans catch what AI cannot reason about. You need both.

---

## Attribution

Built by [Pashov Audit Group](https://www.pashov.com/). [MIT License](https://github.com/pashov/skills/blob/main/LICENSE).
