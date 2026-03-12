# Majeur Multi-Auditor Cross-Validation Methodology v4.0

**Source**: Derived from [majeur](https://github.com/z0r0z/majeur) Moloch DAO framework audit methodology
**Purpose**: Achieve "God Mode" vulnerability detection accuracy through multi-auditor cross-validation

---

## Executive Summary

The Majeur methodology transforms single-pass auditing into a **23+ auditor cross-validation matrix** that dramatically improves:
- **Signal-to-noise ratio**: ~8% FP rate (Pashov) vs ~60% FP rate (unstructured AI audit)
- **Finding completeness**: Cross-auditor deduplication catches findings that any single tool misses
- **Confidence calibration**: [75-100] confidence scoring with explicit decision thresholds
- **False positive elimination**: Documented criteria per vulnerability category

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           MAJEUR GOD MODE AUDIT                             │
├─────────────────────────────────────────────────────────────────────────────┤
│  Phase 0: Pre-Audit                                                         │
│  ├── Load protocol context (reference/protocols/*.md)                       │
│  ├── Load vulnerability patterns (reference/fv-sol/*.md)                    │
│  └── Establish Known Findings list (KF#1-N)                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│  Phase 1: Multi-Auditor Scan (Parallel)                                     │
│  ├── [Auditor 1] Pashov Deep Mode (5 agents, 170 vectors)                   │
│  ├── [Auditor 2] Forefy Multi-Expert (3 rounds: systematic, economic, triage)│
│  ├── [Auditor 3] Solodit Prior Art (20k+ real findings cross-reference)     │
│  ├── [Auditor 4] Sharp Edges (design footguns, code maturity)               │
│  └── [Auditor 5] Certora FV (invariants, parametric rules, revert conditions)│
├─────────────────────────────────────────────────────────────────────────────┤
│  Phase 2: Cross-Auditor Consolidation                                       │
│  ├── Merge all findings into unified list                                   │
│  ├── Tag duplicates: "Duplicate of Auditor1 #X / Auditor2 #Y"               │
│  ├── Apply false positive criteria (FALSE-POSITIVE-CRITERIA.md)             │
│  └── Assign confidence scores [75-100]                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│  Phase 3: Triager Validation (Adversarial)                                  │
│  ├── Each finding gets: > **Review:** [verdict]. [reasoning]. [duplicates]  │
│  ├── Verdicts: "Not a bug" / "Valid observation" / "Design tradeoff" /      │
│  │             "Real concern, configuration-dependent" / "Production blocker"│
│  └── Counter-argue each finding before accepting                            │
├─────────────────────────────────────────────────────────────────────────────┤
│  Phase 4: Final Report                                                      │
│  ├── Novel findings (not duplicates of KF#N or other auditors)              │
│  ├── Deduplicated finding count                                             │
│  └── Confidence-weighted severity assessment                                │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Component 1: Multi-Auditor Registry

### Primary Auditors (Run All)

| Auditor | Type | Source | Focus |
|---------|------|--------|-------|
| **Pashov Deep** | 5-agent parallel | pashov-skills/ | 170 attack vectors, confidence scoring |
| **Forefy 3-Round** | Multi-expert | MULTI-EXPERT.md | Systematic → Economic → Triager |
| **Solodit MCP** | Prior art | SOLODIT-MCP.md | 20k+ real findings cross-reference |
| **Sharp Edges** | Design footguns | SHARP-EDGES.md | Dangerous defaults, sentinel confusion |
| **Certora FV** | Formal verification | CERTORA-INTEGRATION.md | Mathematical invariant proofs |

### Secondary Auditors (Supplementary)

| Auditor | Type | Value Add |
|---------|------|-----------|
| **Protocol Context** | Knowledge base | Protocol-specific bug classes (governance.md, lending.md, etc.) |
| **fv-sol Categories** | Pattern matching | 10 vulnerability categories with false positive criteria |
| **Code Maturity** | Quality assessment | 9-category maturity scoring (0-4 scale) |

---

## Component 2: Known Findings List (KF#)

Before auditing, establish **Known Findings** — protocol-specific behaviors that are intentional designs, not bugs:

```markdown
## Known Findings: [Protocol Name]

### KF#1: [Short Name]
**Behavior**: [What it does]
**Intentional**: [Yes/No] — [Why it's by design]
**Risk accepted by**: [Protocol team / Documentation / Economic analysis]

### KF#2: [Short Name]
...
```

**Example from Majeur:**

```markdown
### KF#1: Sale cap=0 sentinel collision
**Behavior**: When cap=0, `buyShares` treats sale as unlimited (skips cap checks)
**Intentional**: Yes — minting mode is intentionally unlimited; non-minting is bounded by DAO balance
**Risk accepted by**: Configuration Guidance documentation

### KF#2: Ragequit drains futarchy pools
**Behavior**: Ragequit distributes from total ETH balance, including futarchy earmarks
**Intentional**: Yes — exit rights supersede earmarks by Moloch design philosophy
**Risk accepted by**: Moloch governance model (ragequit as nuclear option)

### KF#3: Zero quorum passes with 1 vote
**Behavior**: When quorumBps=0 and quorumAbsolute=0, single FOR vote passes proposal
**Intentional**: Yes — deliberate configuration for trusted/small DAOs
**Risk accepted by**: Configuration Guidance documentation
```

---

## Component 3: Review Annotation Format

Every finding MUST include a review annotation block:

```markdown
> **Review: [VERDICT].** [REASONING]. [DUPLICATE REFS if applicable]. [v2 HARDENING if applicable].
```

### Verdict Options

| Verdict | Meaning | Action |
|---------|---------|--------|
| **Not a bug** | Intentional design, works as intended | No fix needed |
| **Valid observation** | True but not exploitable for profit | Document, inform users |
| **Design tradeoff** | Real concern balanced against other concerns | Configuration guidance |
| **Real concern, configuration-dependent** | Valid under specific configs | Document safe configurations |
| **Known quirk** | Acknowledged edge case, no security impact | Document |
| **Production blocker** | Critical vulnerability requiring fix | MUST fix before deploy |

### Example Review Annotations

```markdown
### Finding: Permissionless proposal opening enables front-running
> **Review: Valid observation, not a production blocker.** The griefing vector is real but mitigable in practice. `castVote` auto-opens proposals atomically (line 352), so proposers can open+vote in one tx — or use `multicall` to open and vote together — preventing the cancel window entirely. Key mitigations: (1) `proposalThreshold > 0` restricts who can open; (2) auto-futarchy blocks cancellation. Good v2 hardening candidate.

### Finding: Snapshot at N-1 vulnerable to flash loan
> **Review: Not a bug.** Per fv-sol-5-c6 false positive criteria: "Same-block snapshot abuse — **false positive** by design." Snapshot at `block.number - 1` means flash-loaned tokens deposited at block N have zero voting power. This is the gold-standard pattern per governance.md remediation notes.

### Finding: Force-fed ETH inflates ragequit payouts
> **Review: Not a bug.** Per fv-sol-5-c8 false positive criteria: "Contract explicitly designed to accept arbitrary ETH." Economically irrational attack — attacker donates ETH to benefit others. (Duplicate: QuillShield DGA-2)
```

---

## Component 4: Cross-Auditor Deduplication

When consolidating findings from multiple auditors, tag duplicates explicitly:

```markdown
### [UNIQUE-ID] Finding Title
- **Source auditor**: Pashov #3
- **Also found by**: Zellic #13, Plainshift #1, Octane #6
- **Severity**: [Agreed severity across auditors]
- **Duplicate count**: 4/5 auditors flagged this
```

### Deduplication Rules

1. **Same root cause** → Mark as duplicate regardless of phrasing
2. **Same impact** → Mark as duplicate even if different attack paths
3. **Variants of same issue** → Group under primary finding with sub-variants
4. **Internal duplicates** → Auditors may flag same issue multiple times; collapse

---

## Component 5: Confidence Scoring [75-100]

| Score | Meaning | Decision |
|-------|---------|----------|
| **95-100** | Mathematical certainty, PoC confirmed | Report as definitive |
| **85-94** | High confidence, clear exploit path | Report with validation |
| **75-84** | Moderate confidence, theoretical concern | Report as observation |
| **<75** | Low confidence, speculative | Exclude from final report |

### Confidence Formula

```
Confidence = Base_Score + Modifiers

Base_Score:
- PoC exists and passes: +30
- Clear exploit path documented: +20
- Matches known vulnerability pattern: +15
- Impact assessment complete: +10
- Root cause identified: +10
- Mitigation verified: +5

Modifiers:
- Cross-auditor agreement: +1 per additional auditor (max +5)
- Solodit prior art match: +5
- Certora invariant violation: +10
- Design footgun (Sharp Edges): -5 (lower severity, not security bug)
- Configuration-dependent: -5
- Requires unlikely conditions: -10
```

---

## Component 6: Signal-to-Noise Comparison

Track FP rates across auditors to calibrate trust:

| Auditor | Total Findings | True Positives | False Positives | FP Rate |
|---------|---------------|----------------|-----------------|---------|
| Pashov Deep | 13 | 12 | 1 | 7.7% |
| Zellic V12 | 24 | 10 | 14 | 58.3% |
| Octane | 49 | 8 | 41 | 83.7% |
| Forefy | 10 | 9 | 1 | 10.0% |

**Calibration**: Weight findings from lower-FP auditors higher; require additional validation for high-FP auditors.

---

## Integration into SolidityEVM Workflow

### Phase 0: Setup (Before Audit)

```bash
# 1. Load protocol context
Read reference/protocols/[protocol-type].md

# 2. Load vulnerability patterns
Read reference/fv-sol/fv-sol-*.md

# 3. Establish Known Findings list
Create KF#1-N from design docs, previous audits, known limitations
```

### Phase 1: Multi-Auditor Scan (Parallel)

```markdown
## Run in parallel:
1. Pashov Deep Mode (pashov-skills/SKILL.md)
2. Forefy 3-Round (MULTI-EXPERT.md)
3. Solodit Prior Art (SOLODIT-MCP.md)
4. Sharp Edges Analysis (SHARP-EDGES.md)
5. [Optional] Certora FV if specs exist
```

### Phase 2: Consolidation

```markdown
## For each finding from all auditors:
1. Check against KF#N — if match, mark "Known Finding"
2. Check against other auditors — tag duplicates
3. Apply false positive criteria (FALSE-POSITIVE-CRITERIA.md)
4. Assign confidence score [75-100]
5. Write Review annotation
```

### Phase 3: Final Report

```markdown
## Report Structure:
- Executive Summary
  - Total findings from all auditors: N
  - After deduplication: M
  - After FP filtering: K
  - Production blockers: X

- Per-finding detail with:
  - Review annotation
  - Duplicate references
  - Confidence score
  - Source auditors
```

---

## Appendix: Migrating from v3.3 to v4.0 (Majeur-Enhanced)

| v3.3 Component | v4.0 Enhancement |
|----------------|------------------|
| MULTI-EXPERT.md | Add Forefy round attribution + Review annotations |
| TRIAGER.md | Add explicit verdict options + confidence scoring |
| FINDING-FORMAT.md | Add duplicate refs + source auditor + confidence |
| SOLODIT-MCP.md | Already integrated (claudit) |
| pashov-skills/ | Add cross-auditor deduplication step |
| reference/fv-sol/ | Already integrated; add FP criteria documentation |
| (NEW) FALSE-POSITIVE-CRITERIA.md | Document explicit FP criteria per category |
| (NEW) CONFIDENCE-SCORING.md | Detailed scoring methodology |
| (NEW) SHARP-EDGES.md | Design footgun analysis |
| (NEW) KNOWN-FINDINGS-TEMPLATE.md | KF#N documentation template |
