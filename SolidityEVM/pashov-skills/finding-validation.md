# Finding Validation

> **Source:** Pashov Audit Group Skills — adapted for InfoSec-Framework integration
> **Cross-Reference:** Aligns with [CommandInstruction.md](../CommandInstruction.md) Mandatory Validation Checks

Each finding passes a false-positive gate, then gets a confidence score (how certain you are it is real).

## FP Gate

Every finding must pass all three checks. If any check fails, drop the finding — do not score or report it.

1. You can trace a concrete attack path: caller → function call → state change → loss/impact. Evaluate what the code _allows_, not what the deployer _might choose_.
2. The entry point is reachable by the attacker (check modifiers, `msg.sender` guards, `onlyOwner`, access control).
3. No existing guard already prevents the attack (`require`, `if`-revert, reentrancy lock, allowance check, etc.).

### Alignment with InfoSec Framework Validation

| Pashov FP Gate | InfoSec Validation Check | Relationship |
|----------------|-------------------------|-------------|
| Check 1: Concrete attack path | **Reachability** + **State Freshness** | Attack path must be traceable and use current state |
| Check 2: Entry point reachable | **Reachability** + **Execution Closure** | Attacker can call the function; external calls modeled |
| Check 3: No existing guard | **Execution Closure** | All mitigations checked |
| — | **Economic Realism** | Pashov adds this via confidence deductions |

## Confidence Score

Confidence measures certainty that the finding is real and exploitable — not how severe it is. Every finding that passes the FP gate starts at **100**.

**Deductions (apply all that fit):**

- Privileged caller required (owner, admin, multisig, governance) → **-25**.
- Attack path is partial (general idea is sound but cannot write exact caller → call → state change → outcome) → **-20**.
- Impact is self-contained (only affects the attacker's own funds, no spillover to other users) → **-15**.

Confidence indicator: `[score]` (e.g., `[95]`, `[75]`, `[60]`).

Findings below the confidence threshold (default 75) are still included in the report table but do not get a **Fix** section — description only.

### Mapping Confidence to InfoSec Severity

| Confidence Range | Typical Severity | Notes |
|-----------------|-----------------|-------|
| 90-100 | Critical / High | High certainty, clear path, no privilege required |
| 75-89 | High / Medium | Solid finding, minor uncertainty |
| 60-74 | Medium / Low | Below threshold — needs manual validation |
| < 60 | Low / Info | Theoretical concern, best validated in Working Chat |

## Do Not Report

- Anything a linter, compiler, or seasoned developer would dismiss — INFO-level notes, gas micro-optimizations, naming, NatSpec, redundant comments.
- Owner/admin can set fees, parameters, or pause — these are by-design privileges, not vulnerabilities.
- Missing event emissions or insufficient logging.
- Centralization observations without a concrete exploit path (e.g., "owner could rug" with no specific mechanism beyond trust assumptions).
- Theoretical issues requiring implausible preconditions (e.g., compromised compiler, corrupt block producer, >50% token supply held by attacker). Note: common ERC20 behaviors (fee-on-transfer, rebasing, blacklisting, pausing) are NOT implausible — if the code accepts arbitrary tokens, these are valid attack surfaces.
