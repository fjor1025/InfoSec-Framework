# Finding Validation

Each finding passes a false-positive gate, then gets a confidence score (how certain you are it is real).

## FP Gate

Every finding must pass all three checks. If any check fails, drop the finding — do not score or report it.

1. You can trace a concrete attack path: caller → entry function → state change → loss/impact. Evaluate what the code _allows_, not what the deployer _might choose_.
2. The entry point is reachable by the attacker (check capability requirements, `public` vs `public(package)` visibility, object ownership, shared vs owned).
3. No existing guard already prevents the attack (assertions, capability checks, ability restrictions, hot potato pattern, etc.).

## Confidence Score

Confidence measures certainty that the finding is real and exploitable — not how severe it is. Every finding that passes the FP gate starts at **100**.

**Deductions (apply all that fit):**

- Privileged caller required (admin, upgrade authority, governance) → **-25**.
- Attack path is partial (general idea sound but cannot write exact path) → **-20**.
- Impact is self-contained (only affects the attacker's own funds) → **-15**.
- Requires specific token/object behavior (unusual abilities, custom types) that may not apply → **-10**.
- Requires external precondition (oracle failure, validator collusion, dependency bug) → **-10**.

Confidence indicator: `[score]` (e.g., `[95]`, `[75]`, `[60]`).

Findings below the confidence threshold (default 75) are still included in the report table but do not get a **Fix** section — description only.

## Do Not Report

- Anything a linter, compiler, or seasoned Move developer would dismiss — INFO-level notes, gas micro-optimizations, naming, documentation.
- Admin/authority can set fees, parameters, or pause — these are by-design privileges, not vulnerabilities.
- Missing event emissions or insufficient logging.
- Centralization observations without a concrete exploit path (e.g., "upgrade authority could rug" with no specific mechanism).
- Theoretical issues requiring implausible preconditions (e.g., compromised validator, >50% supply held by attacker).
