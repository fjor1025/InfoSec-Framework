# False Positive Criteria v4.0

**Source**: Derived from majeur audit methodology + fv-sol knowledge base
**Purpose**: Systematically eliminate false positives using documented criteria

---

## How to Use This Document

When triaging a potential finding:

1. **Identify the vulnerability category** (fv-sol-1 through fv-sol-10)
2. **Navigate to that category's FP criteria section**
3. **Check each criterion** — if ANY criterion matches, mark as **False Positive**
4. **Document which criterion matched** in the Review annotation

### Annotation Format

```markdown
> **Review: False positive.** Per [category]-[criterion]: "[exact criterion text]"
```

**Example:**
```markdown
> **Review: False positive.** Per fv-sol-5-c7: "Function is nonpayable — msg.value always 0"
```

---

## fv-sol-1: Reentrancy

### FP Criteria

| ID | Criterion | Example |
|----|-----------|---------|
| **fv-sol-1-c1** | State is not modified after external call | View-only callbacks |
| **fv-sol-1-c2** | External call target is trusted (owner, self, known protocol) | UniswapV3 callback to router |
| **fv-sol-1-c3** | Function has nonReentrant modifier with correct implementation | OZ ReentrancyGuard |
| **fv-sol-1-c4** | CEI pattern is correctly followed (state changes before external calls) | Standard transfer-last pattern |
| **fv-sol-1-c5** | External call is to non-malicious address controlled by protocol | Treasury address |
| **fv-sol-1-c6** | Function is not callable externally (internal/private) | Helper function |
| **fv-sol-1-c7** | State that could be exploited is already finalized | Claim already marked complete |
| **fv-sol-1-c8** | Cross-contract reentrancy blocked by consistent locking | Same mutex across contracts |
| **fv-sol-1-c9** | EIP-1153 transient storage guard IS cleared in all exit paths | Guard explicitly cleared after execution |

### Real Example from Majeur

```markdown
**Finding**: Reentrancy via delegatecall in multicall
**FP Criterion Applied**: fv-sol-1-c3
**Reasoning**: "EIP-1153 transient mutex is correctly implemented with cleanup in all exit paths (line 1013: `tstore(REENTRANCY_GUARD_SLOT, 0)`)"
```

---

## fv-sol-2: Precision Errors

### FP Criteria

| ID | Criterion | Example |
|----|-----------|---------|
| **fv-sol-2-c1** | Precision loss is < 1 wei and economically insignificant | Dust amounts |
| **fv-sol-2-c2** | Round-trip operations are deliberately asymmetric (fees) | Explicit fee taking |
| **fv-sol-2-c3** | Protocol explicitly documents rounding direction | ERC4626 rounds down on deposit |
| **fv-sol-2-c4** | mulDiv implementation includes explicit overflow protection | Solady mulDiv |
| **fv-sol-2-c5** | Scaling factor compensates for decimal mismatch | 1e12 multiplier for USDC |
| **fv-sol-2-c6** | ERC4626 inflation attack is mitigated by virtual assets/shares | OpenZeppelin's virtual offset |
| **fv-sol-2-c7** | Fee-on-transfer tokens are explicitly documented as unsupported | README exclusion |

### Real Example from Majeur

```markdown
**Finding**: Double-floor rounding in futarchy payout causes dust
**FP Criterion Applied**: fv-sol-2-c1
**Reasoning**: "The finding itself states 'no theft path exists; this is a benign rounding artifact.' Wei-level dust is standard in Solidity math."
```

---

## fv-sol-3: Arithmetic Errors

### FP Criteria

| ID | Criterion | Example |
|----|-----------|---------|
| **fv-sol-3-c1** | Overflow is impossible due to value bounds | Timestamps < 2^64 |
| **fv-sol-3-c2** | unchecked block is correctly scoped to safe operations | Post-check subtraction |
| **fv-sol-3-c3** | Division by zero is guarded | Explicit if (d != 0) check |
| **fv-sol-3-c4** | Casting is within safe bounds | uint96 sufficient for token amounts |
| **fv-sol-3-c5** | Assembly arithmetic includes explicit overflow checks | eq(div(z, x), y) pattern |

### Real Example from Majeur

```markdown
**Finding**: Assembly mulDiv may overflow
**FP Criterion Applied**: fv-sol-3-c5
**Reasoning**: "mulDiv implementation follows standard assembly pattern with overflow protection via `eq(div(z, x), y)` check"
```

---

## fv-sol-4: Access Control

### FP Criteria

| ID | Criterion | Example |
|----|-----------|---------|
| **fv-sol-4-c1** | Permissionless function is intentionally public | Price oracle queries |
| **fv-sol-4-c2** | Self-referential ACL (msg.sender == address(this)) is intentional governance | DAO onlyDAO pattern |
| **fv-sol-4-c3** | Admin role is correctly checked at function entry | onlyOwner modifier |
| **fv-sol-4-c4** | Signature validation includes all relevant parameters | Full message hash |
| **fv-sol-4-c5** | Hash collision requires 2^128 computational effort | Keccak256 with sufficient entropy |
| **fv-sol-4-c6** | Replay protection includes chainId, address, nonce | EIP-712 domain |
| **fv-sol-4-c7** | CREATE2 address is protected by constructor validation | Summoner permission check |
| **fv-sol-4-c8** | Initializer is protected by initialization guard | initializer modifier |
| **fv-sol-4-c9** | CREATE2 squatting mitigated by permission check on init | `init()` requires `msg.sender == SUMMONER` |

### Real Example from Majeur

```markdown
**Finding**: CREATE2 address can be pre-deployed
**FP Criterion Applied**: fv-sol-4-c9
**Reasoning**: "CREATE2 squatting is mitigated by the SUMMONER permission check. `init()` requires `msg.sender == SUMMONER`"
```

---

## fv-sol-5: Logic Errors

### FP Criteria

| ID | Criterion | Example |
|----|-----------|---------|
| **fv-sol-5-c1** | Edge case is explicitly handled | Default branch in switch |
| **fv-sol-5-c2** | Conditional uses correct comparison operator | >= vs > as intended |
| **fv-sol-5-c3** | Loop terminates correctly | i < length, not i != length |
| **fv-sol-5-c4** | State machine transitions are irreversible as intended | executed latch |
| **fv-sol-5-c5** | Configuration parameters have documented safe ranges | quorumBps <= 10000 |
| **fv-sol-5-c6** | Same-block snapshot manipulation blocked by N-1 pattern | `snapshotBlock = block.number - 1` |
| **fv-sol-5-c7** | msg.value reuse blocked by nonpayable function | multicall is NOT payable |
| **fv-sol-5-c8** | Force ETH benefits victims or is economically irrational | Attacker donates ETH to others |
| **fv-sol-5-c9** | First-depositor inflation mitigated by virtual shares | OpenZeppelin ERC4626 |

### Real Example from Majeur

```markdown
**Finding**: Flash loan vote manipulation via same-block snapshot
**FP Criterion Applied**: fv-sol-5-c6
**Reasoning**: "Snapshot at N-1 means flash-loaned tokens deposited at block N have zero voting power"

**Finding**: msg.value reuse in multicall
**FP Criterion Applied**: fv-sol-5-c7
**Reasoning**: "`multicall` is NOT `payable` — `msg.value` is always 0"

**Finding**: selfdestruct force-feeds ETH to inflate ragequit
**FP Criterion Applied**: fv-sol-5-c8
**Reasoning**: "Force-fed ETH benefits ragequitters, not the attacker. Economically irrational attack."
```

---

## fv-sol-6: Unchecked External Returns

### FP Criteria

| ID | Criterion | Example |
|----|-----------|---------|
| **fv-sol-6-c1** | Return value is checked explicitly | if (!success) revert |
| **fv-sol-6-c2** | SafeERC20/Solady safeTransfer used | SafeERC20.safeTransfer |
| **fv-sol-6-c3** | Low-level call return is validated | (bool ok,) = x.call() |
| **fv-sol-6-c4** | Non-standard ERC20 handled (USDT, BNB) | Assembly returndata check |
| **fv-sol-6-c5** | Return value is intentionally ignored (known behavior) | Approve before transferFrom |
| **fv-sol-6-c6** | Address existence is validated before call | code.length > 0 |
| **fv-sol-6-c7** | Return bomb mitigated by gas limits | Gas-bounded external call |
| **fv-sol-6-c8** | Return data bomb bounded by caller's gas | Governance-gated execution |
| **fv-sol-6-c9** | Phantom read guarded by code existence check | extcodesize check |
| **fv-sol-6-c10** | Nonstandard ERC20 covered by Solady-style assembly | returndatasize() validation |

### Real Example from Majeur

```markdown
**Finding**: Nonstandard ERC20 (USDT) will cause silent failures
**FP Criterion Applied**: fv-sol-6-c10
**Reasoning**: "Solady-style assembly checks `returndatasize()` and validates return value — handles USDT (no return), BNB, etc."
```

---

## fv-sol-7: Proxy Insecurities

### FP Criteria

| ID | Criterion | Example |
|----|-----------|---------|
| **fv-sol-7-c1** | Proxy is UUPS with correct _authorizeUpgrade | OZ UUPSUpgradeable |
| **fv-sol-7-c2** | Storage layout is preserved across upgrades | Storage gap pattern |
| **fv-sol-7-c3** | Initializer is protected and called exactly once | initializer modifier |
| **fv-sol-7-c4** | Implementation cannot be initialized directly | _disableInitializers() |
| **fv-sol-7-c5** | Selfdestruct not reachable in implementation | No suicide/selfdestruct |
| **fv-sol-7-c6** | Constructor does not set state incorrectly | Immutables only |
| **fv-sol-7-c7** | Beacon proxy updates are access controlled | onlyOwner on beacon |

---

## fv-sol-8: Slippage / MEV

### FP Criteria

| ID | Criterion | Example |
|----|-----------|---------|
| **fv-sol-8-c1** | Slippage parameter is enforced | require(out >= minOut) |
| **fv-sol-8-c2** | Deadline parameter is enforced | require(block.timestamp <= deadline) |
| **fv-sol-8-c3** | Price is validated against oracle | TWAP check |
| **fv-sol-8-c4** | Sandwich attack is economically infeasible | High fees, low liquidity |
| **fv-sol-8-c5** | MEV protection is handled at infrastructure layer | Flashbots Protect |
| **fv-sol-8-c6** | Transaction is atomic and cannot be front-run | Commit-reveal scheme |

---

## fv-sol-9: Unbounded Loops / Gas Griefing

### FP Criteria

| ID | Criterion | Example |
|----|-----------|---------|
| **fv-sol-9-c1** | Array length is bounded by constant | MAX_RECIPIENTS = 100 |
| **fv-sol-9-c2** | Loop processes user-controlled input safely | Paginated iteration |
| **fv-sol-9-c3** | Gas consumption is O(1) per operation | Constant-time operations |
| **fv-sol-9-c4** | Batch operations have explicit limits | for (i=0; i<min(n, MAX); i++) |
| **fv-sol-9-c5** | Callback reentrancy blocked | nonReentrant on batch |
| **fv-sol-9-c6** | Blacklistable token DoS mitigated by caller-controlled array | User can omit problematic tokens |

### Real Example from Majeur

```markdown
**Finding**: Blacklistable token (USDT) in ragequit causes DoS
**FP Criterion Applied**: fv-sol-9-c6
**Reasoning**: "Caller supplies the token list, enabling self-mitigation. User can simply omit blacklisted token from array."
```

---

## fv-sol-10: Oracle Manipulation

### FP Criteria

| ID | Criterion | Example |
|----|-----------|---------|
| **fv-sol-10-c1** | TWAP oracle with sufficient window | 30-minute TWAP |
| **fv-sol-10-c2** | Multiple oracle sources with median | Chainlink + Uniswap TWAP |
| **fv-sol-10-c3** | Circuit breaker on extreme price movements | 10% deviation check |
| **fv-sol-10-c4** | Oracle staleness is checked | require(updatedAt > block.timestamp - 1 hours) |
| **fv-sol-10-c5** | L2 sequencer uptime is validated | Chainlink sequencer feed |
| **fv-sol-10-c6** | Price bounds are enforced | minPrice <= price <= maxPrice |
| **fv-sol-10-c7** | Spot price not used for liquidations | Oracle with manipulation resistance |

---

## Protocol-Specific FP Criteria

### Governance Protocols

| ID | Criterion | Example |
|----|-----------|---------|
| **gov-c1** | Voting checkpoint uses unmodified upstream library | Solady ERC20Votes |
| **gov-c2** | Quorum uses snapshotted supply, not live | supplySnapshot[id] |
| **gov-c3** | All parameter changes require governance proposal | onlyDAO modifier |
| **gov-c4** | Delegation state is path-independent | Standard delegate() |
| **gov-c5** | Flash loan voting blocked by N-1 snapshot | getPastVotes(block.number - 1) |

### Real Example from Majeur

```markdown
**Finding**: Voting checkpoint overwrite vulnerability
**FP Criterion Applied**: gov-c1
**Reasoning**: "Standard ERC20Votes implementation inherited by Shares contract — unmodified upstream code that handles same-block operations correctly."

**Finding**: Quorum manipulation via supply changes
**FP Criterion Applied**: gov-c2
**Reasoning**: "Quorum uses snapshotted supply: `supplySnapshot[id]` is set at proposal creation (line 296)"
```

---

## Applying FP Criteria: Workflow

```
┌─────────────────────────────────────────────┐
│           Finding Triage Workflow           │
├─────────────────────────────────────────────┤
│ 1. Identify vulnerability category          │
│    └── fv-sol-1 through fv-sol-10          │
│                                             │
│ 2. Check protocol-specific criteria first   │
│    └── gov-c*, lending-c*, dex-c*, etc.    │
│                                             │
│ 3. Check category-specific FP criteria      │
│    └── fv-sol-X-c1 through fv-sol-X-cN     │
│                                             │
│ 4. If ANY criterion matches:                │
│    └── Mark as False Positive               │
│    └── Document: "Per [criterion]: [text]"  │
│                                             │
│ 5. If NO criterion matches:                 │
│    └── Proceed with severity assessment     │
│    └── Assign confidence score              │
│    └── Write full Review annotation         │
└─────────────────────────────────────────────┘
```

---

## Quick Reference: Most Common FP Patterns

| Pattern | Criterion | Why It's FP |
|---------|-----------|-------------|
| Same-block flash loan voting | fv-sol-5-c6 | N-1 snapshot blocks it |
| msg.value in nonpayable multicall | fv-sol-5-c7 | msg.value is always 0 |
| Force ETH via selfdestruct | fv-sol-5-c8 | Attacker loses money |
| USDT in SafeERC20 | fv-sol-6-c10 | Solady handles it |
| Blacklist token DoS | fv-sol-9-c6 | User controls array |
| ERC20Votes checkpoint | gov-c1 | Unmodified upstream |
| Standard delegation | gov-c4 | Path-independent |
