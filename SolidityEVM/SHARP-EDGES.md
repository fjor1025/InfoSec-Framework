# Sharp Edges Analysis v4.0

**Source**: Trail of Bits Skills (Sharp Edges + Code Maturity Assessment)
**Purpose**: Identify design footguns, dangerous configurations, and sentinel value confusion

---

## What Are Sharp Edges?

Sharp edges are **design patterns that are technically correct but create footguns**:
- They work as documented
- They can lead to unexpected behavior for uninformed users
- They require careful configuration guidance
- They are NOT security vulnerabilities but can ENABLE vulnerabilities

**Classification**: Sharp edges are typically **Low/Informational** severity, not bugs.

---

## Sharp Edge Categories

### Category 1: Dangerous Defaults

Default configuration values that create security risks if not explicitly changed.

| Pattern | Risk | Detection |
|---------|------|-----------|
| **Zero quorum** | Proposals pass with 1 vote | Check `quorumBps == 0 && quorumAbsolute == 0` |
| **Zero threshold** | Anyone can propose | Check `proposalThreshold == 0` |
| **Zero timelock** | Instant execution, no exit window | Check `timelockDelay == 0` |
| **Zero TTL** | Proposals never expire | Check `proposalTTL == 0` |
| **Unlimited minting** | Token supply unbounded | Check `cap == 0` in minting mode |

### Example Analysis from Majeur

```markdown
#### 1.1 Zero Quorum Passes Proposals With 1 Vote - Critical (Sharp Edge)

> **Review: Valid footgun, already documented.** When both `quorumBps=0` and `quorumAbsolute=0` (defaults), a single FOR vote passes any proposal. This is documented in Configuration Guidance: DAOs should set appropriate quorum. The `summon()` function accepts `quorumBps` as a parameter, so deployers who set it to 0 are making a deliberate (if dangerous) choice. UIs should warn or prevent zero-quorum deployments.

**Classification**: Sharp Edge, NOT a bug
**Mitigation**: Configuration guidance + UI warnings
```

---

### Category 2: Configuration Cliffs

Parameter boundaries where small changes cause dramatic behavioral shifts.

| Pattern | Risk | Detection |
|---------|------|-----------|
| **Unbounded parameter at init** | Bricked state | Check for validation in init vs setters |
| **Config invalidation** | Mass proposal/permit invalidation | Check bumpConfig side effects |
| **Dangerous combinations** | State locks | Check `ragequittable=false && timelockDelay=0` |

### Example Analysis from Majeur

```markdown
#### 2.1 Init Does Not Validate quorumBps Range - Critical (Sharp Edge)

> **Review: Valid finding.** `setQuorumBps()` correctly rejects `bps > 10_000`, but `init()` does not validate. A `quorumBps` value exceeding 10000 at deploy time would make proposals permanently unpassable (quorum target exceeds total supply). **v2 hardening:** add `require(_quorumBps <= 10_000)` to `init()`.

**Classification**: Sharp Edge requiring fix
**Mitigation**: Add validation to init()
```

---

### Category 3: Silent Failures

Operations that succeed without expected effects, misleading integrators.

| Pattern | Risk | Detection |
|---------|------|-----------|
| **Silent no-op** | Operation appears to succeed but does nothing | Check early returns without events |
| **Soft failure returns** | Return value implies failure but function didn't revert | Check (bool ok, bytes data) patterns |
| **Idempotent without signaling** | Repeated calls succeed but only first has effect | Check state checks at function entry |

### Example Analysis from Majeur

```markdown
#### 3.1 queue() Is a Silent No-Op When Timelock Is Zero - Medium (Sharp Edge)

> **Review: Valid UX concern.** `queue()` returns silently without recording anything when `timelockDelay=0`. Integrations that call `queue()` then wait for a timelock will wait indefinitely. Consider reverting with a descriptive error instead. **v2 hardening:** revert with `NoTimelock()` instead of silent return.

**Classification**: Sharp Edge / UX concern
**Mitigation**: Explicit revert with descriptive error
```

---

### Category 4: Sentinel Value Confusion

When special values like 0 or max have multiple meanings.

| Pattern | Risk | Detection |
|---------|------|-----------|
| **Zero = unlimited AND zero = exhausted** | Sentinel collision | Check `if (x == 0)` branches |
| **address(0) overloading** | ETH vs unset vs burn | Check address(0) semantics per function |
| **type(uint).max as sentinel** | Max valid value vs special meaning | Check max value comparisons |

### Example Analysis from Majeur

```markdown
#### 4.1 Sale cap=0 Means Unlimited, Not Zero - Critical (Sharp Edge)

> **Review: Known quirk. Duplicate of Zellic #13.** Already documented in Configuration Guidance. The cap is a soft guardrail. In minting mode, unlimited is the intended behavior. UIs should surface this clearly.

**Behavior**: `cap=0` skips the cap check entirely, treating the sale as unlimited.
**Classification**: Sharp Edge, documented behavior
**Mitigation**: UI documentation + alternative sentinel (type(uint256).max for unlimited)

#### 4.2 rewardToken=address(0) Has Three Different Meanings - High (Sharp Edge)

> **Review: Valid design footgun.** `address(0)` means:
> - "ETH" in `_payout()`
> - "use funder's choice" in `fundFutarchy()`
> - "default to minted loot" in auto-futarchy via `openProposal()`
> 
> **v2 hardening:** use a distinct sentinel (e.g., `address(1)`) for "unset/use default" vs `address(0)` for ETH.

**Classification**: Sharp Edge requiring design refinement
**Mitigation**: Separate sentinel values for distinct semantics
```

---

## Code Maturity Assessment Framework

9-category scoring system (0-4 per category):

| Score | Rating | Meaning |
|-------|--------|---------|
| 4 | Excellent | Best-in-class practices throughout |
| 3 | Satisfactory | Standard security practices followed |
| 2 | Moderate | Some gaps but fundamentally sound |
| 1 | Weak | Significant gaps requiring attention |
| 0 | Missing | Critical practices absent |

### Categories

| # | Category | What It Assesses |
|---|----------|------------------|
| 1 | **Arithmetic** | Overflow protection, precision handling, unchecked blocks |
| 2 | **Auditing** | Event emission, state tracking, monitoring hooks |
| 3 | **Access Controls** | Role management, permission checks, admin patterns |
| 4 | **Complexity** | Code clarity, function length, inheritance depth |
| 5 | **Decentralization** | Admin key risks, upgrade controls, trust assumptions |
| 6 | **Documentation** | NatSpec coverage, README quality, inline comments |
| 7 | **Transaction Ordering** | MEV awareness, frontrun protection, deadline checks |
| 8 | **Low-Level Code** | Assembly safety, call patterns, memory management |
| 9 | **Testing** | Coverage, edge cases, invariant testing |

### Example Assessment from Majeur

```markdown
## Code Maturity: Moloch.sol

| Category | Score | Notes |
|----------|-------|-------|
| Arithmetic | 3 | mulDiv with overflow checks, uint96 bounds appropriate |
| Auditing | 3 | Comprehensive events, state tracking |
| Access Controls | 4 | Pure self-governance, no admin keys |
| Complexity | 2 | 2110 lines single contract, could be modularized |
| Decentralization | 4 | No external privileged roles |
| Documentation | 3 | Good NatSpec, some edge cases underdocumented |
| Transaction Ordering | 3 | Snapshot at N-1, standard patterns |
| Low-Level Code | 3 | Solady-style assembly, well-audited patterns |
| Testing | 3 | Certora FV + unit tests |

**Overall: 2.89/4.0 (Moderate-Satisfactory)**
```

---

## Sharp Edges Detection Checklist

### Pre-Audit Configuration Review

```markdown
## Configuration Sharp Edges Checklist

### Governance Parameters
- [ ] quorumBps != 0 OR quorumAbsolute != 0 (avoid 1-vote passage)
- [ ] proposalThreshold > 0 (restrict who can propose)
- [ ] proposalTTL > 0 (proposals should expire)
- [ ] timelockDelay > 0 if ragequittable can be disabled

### Init vs Setter Validation
- [ ] init() validates all parameters that setters validate
- [ ] No parameter can be set to value that bricks the contract

### Sentinel Values
- [ ] Document all special meanings of 0
- [ ] Document all special meanings of address(0)
- [ ] Document all special meanings of type(uint).max

### State Machine Transitions
- [ ] All write-once latches documented
- [ ] bumpConfig side effects documented
- [ ] Irreversible state changes documented
```

### Per-Function Sharp Edge Analysis

For each function, check:

```markdown
## Function: [functionName]

### Dangerous Defaults
- [ ] What happens with default (zero) values for all parameters?
- [ ] Are defaults documented?

### Silent Failures
- [ ] Does function return without revert on invalid inputs?
- [ ] Are early returns logged or signaled?

### Sentinel Confusion
- [ ] Does any parameter have multiple special value meanings?
- [ ] Are special values documented?

### Configuration Cliffs
- [ ] Are there parameter boundaries that cause dramatic behavior changes?
- [ ] Are boundaries validated?
```

---

## Integration with Audit Workflow

### When to Run Sharp Edges Analysis

```
┌────────────────────────────────────────────┐
│        Sharp Edges in Audit Workflow       │
├────────────────────────────────────────────┤
│ Phase 1: Pre-Audit Setup                   │
│ └── Run Sharp Edges configuration checklist│
│                                            │
│ Phase 2: Function-Level Analysis           │
│ └── Per-function sharp edge checks         │
│                                            │
│ Phase 3: Findings Triage                   │
│ └── Classify sharp edges as Low/Info       │
│ └── NOT vulnerabilities unless config-     │
│     dependent exploits exist               │
│                                            │
│ Phase 4: Report                            │
│ └── Separate "Sharp Edges" section         │
│ └── Include Configuration Guidance         │
└────────────────────────────────────────────┘
```

### Sharp Edge vs Vulnerability Classification

| Criterion | Sharp Edge | Vulnerability |
|-----------|------------|---------------|
| Works as documented? | Yes | No |
| Requires misconfiguration? | Yes | No |
| Exploitable by default? | No | Yes |
| Fix type | Documentation/guidance | Code change |
| Typical severity | Low/Informational | Medium/High/Critical |

---

## Appendix: Common Sharp Edge Patterns by Protocol Type

### Governance Protocols

| Sharp Edge | Risk | Standard Mitigation |
|------------|------|---------------------|
| Zero quorum | 1-vote passage | Require quorum > 0 at deploy |
| Zero threshold | Anyone proposes | Set minimum stake requirement |
| No timelock | Instant execution | Add grace period for ragequit |
| Open-ended voting | Zombie proposals | Set reasonable TTL |

### Token Sales

| Sharp Edge | Risk | Standard Mitigation |
|------------|------|---------------------|
| cap=0 unlimited | Infinite minting | Use max uint for unlimited |
| Zero price | Free tokens | Require price > 0 |
| No cooldown | Flash buy-sell | Add transfer delay |

### DeFi Protocols

| Sharp Edge | Risk | Standard Mitigation |
|------------|------|---------------------|
| Zero slippage | Full MEV extraction | Require minOut > 0 |
| No deadline | Stale transaction execution | Enforce deadline parameter |
| Unlimited approval | Token theft on contract compromise | Exact amount approvals |
