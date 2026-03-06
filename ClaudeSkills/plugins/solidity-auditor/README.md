# solidity-auditor

> A parallelized Solidity security audit across 170 Pashov attack vectors.  
> **Source:** [Pashov Audit Group Skills](https://github.com/pashov/skills) — MIT Licensed  
> **Adapted for:** InfoSec-Framework (`SolidityEVM/pashov-skills/`)

## What It Does

Spawns 4 parallel vector-scan agents (Agents 1–4), each covering ~42 of the 170 attack vectors. Optionally spawns a 5th adversarial reasoning agent (DEEP mode). Merges results, deduplicates by root cause, scores by confidence, and produces a structured report.

## Usage

```
/solidity-auditor                       # Scan all .sol files (default)
/solidity-auditor deep                  # + adversarial reasoning agent (slower, more thorough)
/solidity-auditor src/Vault.sol         # Specific file(s) only
/solidity-auditor --file-output         # Also write report to assets/findings/
```

**Exclude pattern (all modes):** skips `interfaces/`, `lib/`, `mocks/`, `test/`, `*.t.sol`, `*Test*.sol`, `*Mock*.sol`.

## Architecture

| Agent | Role | Attack Vectors | Model |
|-------|------|---------------|-------|
| Agent 1 | Vector scan | attack-vectors-1.md (~42 vectors) | sonnet |
| Agent 2 | Vector scan | attack-vectors-2.md (~42 vectors) | sonnet |
| Agent 3 | Vector scan | attack-vectors-3.md (~42 vectors) | sonnet |
| Agent 4 | Vector scan | attack-vectors-4.md (~42 vectors) | sonnet |
| Agent 5 | Adversarial reasoning (DEEP only) | None — free-form logic analysis | opus |

## Reference Files

All references live in `SolidityEVM/pashov-skills/`:

| File | Purpose |
|------|---------|
| `attack-vectors/attack-vectors-{1,2,3,4}.md` | 170 atomic attack vectors, split into 4 bundles |
| `agents/vector-scan-agent.md` | Agent 1–4 instructions |
| `agents/adversarial-reasoning-agent.md` | Agent 5 (DEEP) instructions |
| `finding-validation.md` | FP gate (3 checks) + confidence scoring (100-point) |
| `report-formatting.md` | Report output template |

## Known Limitations

**Codebase size.** Works best up to ~2,500 lines of Solidity. Past ~5,000 lines, triage accuracy and mid-bundle recall drop. For large codebases, run per module.

**What AI misses.** Strong at pattern matching (missing access controls, unchecked returns, known reentrancy shapes). Struggles with multi-transaction state setups, specification/invariant bugs, cross-protocol composability, and game-theory attacks. Catches what humans forget to check; humans catch what AI cannot reason about.

## Relationship to InfoSec-Framework

This skill implements the **Phase 0 fast scan** described in `SolidityEVM/CommandInstruction.md`. Output feeds directly into:

- `SolidityEVM/Audit_Assistant_Playbook.md` — Section 2.5 (SCAN Pashov 170-Vector Triage)
- `SolidityEVM/audit-workflow1.md` — Step 5.2b (Pashov Attack Surface cross-reference)

**Recommended workflow:**
1. Run `/solidity-auditor` before starting the full manual audit (Phase 0)
2. Review confidence-scored findings
3. Feed surviving findings into the InfoSec-Framework Hypothesis Generator
4. Validate each finding against `SolidityEVM/audit-workflow1.md` step checklists
