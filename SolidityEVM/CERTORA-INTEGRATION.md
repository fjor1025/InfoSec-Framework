# Certora Formal Verification Integration v4.0

**Source**: Derived from majeur/certora formal verification methodology
**Purpose**: Mathematical proof of smart contract invariants using Certora Prover

---

## What is Certora FV?

Certora Formal Verification provides **mathematical proofs of smart contract correctness** by:
- Verifying code against a formal specification (CVL rules)
- Examining **all possible states and execution paths** (not just sampled ones)
- Proving invariants hold universally, not just for tested cases

### FV vs Testing

| Aspect | Testing/Fuzzing | Formal Verification |
|--------|-----------------|---------------------|
| Coverage | Sample paths | All paths |
| Certainty | Statistical confidence | Mathematical proof |
| Bugs found | Specific instances | Universal violations |
| Cost | Lower | Higher |
| When to use | Always | High-value contracts |

---

## CVL Property Types

### 1. Invariants

System-wide properties that MUST always hold true. Automatically verified against every external function.

```cvl
// Example: Total supply equals sum of all balances
invariant totalSupplyIsSumOfBalances()
    sumOfAllBalances() == totalSupply()
```

### 2. Parametric Rules

Rules verified against every non-view external function using `method f` with `calldataarg args`.

```cvl
// Example: Only mint/burn change totalSupply
rule onlyMintBurnChangeTotalSupply(method f) {
    uint256 supplyBefore = totalSupply();
    env e; calldataarg args;
    f(e, args);
    uint256 supplyAfter = totalSupply();
    
    assert supplyAfter != supplyBefore => 
        f.selector == sig:mint(address,uint256).selector ||
        f.selector == sig:burn(address,uint256).selector;
}
```

### 3. Access Control Rules

Rules verifying that state-changing functions revert when the caller lacks the required role.

```cvl
// Example: Only DAO can call setProposalThreshold
rule onlyDAOCanSetProposalThreshold() {
    env e;
    uint256 newThreshold;
    
    setProposalThreshold@withrevert(e, newThreshold);
    
    assert !lastReverted => e.msg.sender == currentContract;
}
```

### 4. Revert Condition Rules

Rules verifying that functions revert under specific invalid conditions.

```cvl
// Example: transfer reverts when balance insufficient
rule transferRevertsOnInsufficientBalance() {
    env e; address to; uint256 amount;
    
    require balanceOf(e.msg.sender) < amount;
    
    transfer@withrevert(e, to, amount);
    
    assert lastReverted;
}
```

### 5. Integrity Rules

Rules verifying that successful function calls produce the correct state changes.

```cvl
// Example: transfer moves exact amounts
rule transferIntegrity() {
    env e; address to; uint256 amount;
    
    uint256 senderBefore = balanceOf(e.msg.sender);
    uint256 receiverBefore = balanceOf(to);
    
    transfer(e, to, amount);
    
    assert balanceOf(e.msg.sender) == senderBefore - amount;
    assert balanceOf(to) == receiverBefore + amount;
}
```

### 6. Sanity (Satisfy) Rules

Lightweight reachability checks ensuring functions are not vacuously verified.

```cvl
// Example: transfer is reachable
rule transferSanity() satisfies {
    env e; address to; uint256 amount;
    transfer(e, to, amount);
    satisfy true;
}
```

---

## Key Invariant Patterns from Majeur

### ERC-20 / Token Accounting

```cvl
// 1. Sum of balances equals totalSupply
invariant totalSupplyIsSumOfBalances()
    sumOfAllBalances == totalSupply()
    { preserved { requireInvariant sumOfBalancesIsWellDefined(); } }

// 2. Transfer conserves total supply
rule transferConservesTotalSupply() {
    env e; address to; uint256 amount;
    uint256 supplyBefore = totalSupply();
    transfer(e, to, amount);
    assert totalSupply() == supplyBefore;
}
```

### Proposal State Machine

```cvl
// 3. executed is a one-way latch
rule executedNeverBecomeFalse(uint256 id, method f) {
    require executed(id) == true;
    env e; calldataarg args;
    f(e, args);
    assert executed(id) == true;
}

// 4. snapshotBlock is write-once
rule snapshotBlockWriteOnce(uint256 id, method f) {
    uint256 snapBefore = snapshotBlock(id);
    require snapBefore != 0;
    env e; calldataarg args;
    f(e, args);
    assert snapshotBlock(id) == snapBefore;
}

// 5. State transition: Executed cannot transition to any other state
rule executedIsFinal(uint256 id, method f) {
    require state(id) == ProposalState.Executed;
    env e; calldataarg args;
    f(e, args);
    assert state(id) == ProposalState.Executed;
}
```

### Voting Integrity

```cvl
// 6. castVote reverts if already voted
rule cannotVoteTwice(uint256 id) {
    env e;
    require hasVoted(id, e.msg.sender) != 0;
    
    castVote@withrevert(e, id, 1);
    
    assert lastReverted;
}

// 7. Total votes cannot exceed snapshotted supply
invariant votesCannotExceedSupply(uint256 id)
    forVotes(id) + againstVotes(id) + abstainVotes(id) <= supplySnapshot(id)
```

### Ragequit Conservation

```cvl
// 8. Payout is bounded by pool
rule ragequitPayoutBounded(address token, uint256 amt) {
    env e;
    uint256 pool = token == 0 ? 
        nativeBalance(currentContract) : 
        balanceOf(token, currentContract);
    uint256 total = sharesTotalSupply() + lootTotalSupply();
    
    require amt <= total;
    
    uint256 payout = mulDiv(pool, amt, total);
    
    assert payout <= pool;
}
```

### Access Control

```cvl
// 9. All setters require onlyDAO
rule settersRequireOnlyDAO(method f, calldataarg args) 
    filtered { f -> f.selector in setterSelectors }
{
    env e;
    f@withrevert(e, args);
    
    assert !lastReverted => e.msg.sender == currentContract;
}
```

---

## Harness Patterns

### Ghost Variables with Hooks

Track aggregate state that isn't directly available in the contract:

```cvl
// Ghost variable to track sum of all balances
ghost mathint sumOfAllBalances {
    init_state axiom sumOfAllBalances == 0;
}

// Hook on SSTORE to update ghost
hook Sstore balanceOf[KEY address a] uint256 newBalance (uint256 oldBalance) {
    sumOfAllBalances = sumOfAllBalances - oldBalance + newBalance;
}

// Hook on SLOAD to constrain individual balances
hook Sload uint256 balance balanceOf[KEY address a] {
    require balance <= sumOfAllBalances;
}
```

### Simplified Harness Functions

Expose internal state for CVL verification:

```solidity
// In Harness contract
function getProposalState(uint256 id) external view returns (uint8) {
    return uint8(_state(id));
}

function getTallies(uint256 id) external view returns (uint96 forVotes, uint96 againstVotes, uint96 abstainVotes) {
    Tallies memory t = tallies[id];
    return (t.forVotes, t.againstVotes, t.abstainVotes);
}
```

### External Call Summarization

Focus verification on contract's own logic by summarizing external dependencies:

```cvl
// Summarize external token transfers as NONDET
methods {
    function _.transfer(address, uint256) external => NONDET;
    function _.transferFrom(address, address, uint256) external => NONDET;
}
```

---

## Project Structure

```
certora/
├── conf/
│   ├── Token.conf           # Config for token contract verification
│   ├── Governance.conf      # Config for governance contract
│   └── Full.conf            # Combined verification
├── harnesses/
│   ├── TokenHarness.sol     # Exposes internal state
│   └── GovernanceHarness.sol
├── specs/
│   ├── Token.spec           # Token invariants and rules
│   ├── Governance.spec      # Governance invariants
│   └── CrossContract.spec   # Cross-contract properties
└── invariants.md            # Human-readable invariant list
```

---

## Integration with Audit Workflow

### When to Use Certora FV

| Situation | Use FV? | Reason |
|-----------|---------|--------|
| High-value TVL (>$10M) | Yes | Mathematical certainty worth the cost |
| Novel mechanisms | Yes | No historical patterns to rely on |
| Token economics | Yes | Accounting invariants critical |
| State machines | Yes | Proves all transitions correct |
| Simple CRUD | No | Testing sufficient |
| Low-value contracts | No | Cost/benefit ratio unfavorable |

### Reviewing Existing FV Specs

When auditing a protocol that has Certora specs:

1. **Read invariants.md first** — understand what was proven
2. **Check assumptions** — what was summarized as NONDET?
3. **Verify harness fidelity** — does harness preserve all validation logic?
4. **Look for gaps** — what invariants are NOT proven?
5. **Cross-reference findings** — do any audit findings violate proven invariants?

### Using FV Results in Audit

```markdown
## Finding: Potential reentrancy in ragequit

**FV Cross-Reference**: Invariant #53 proves nonReentrant guards all state-changing external calls.

**Verification Status**: 
- [x] Invariant proven via Certora
- [x] Harness preserves nonReentrant modifier
- [x] No NONDET summarization of reentrancy paths

**Conclusion**: False positive per Certora proof.
```

---

## Invariant Categories Checklist

### Token Contracts

- [ ] Total supply equals sum of all balances
- [ ] Transfer conserves total supply
- [ ] Only mint/burn change total supply
- [ ] Burn reverts on insufficient balance
- [ ] Transfer reverts on insufficient balance
- [ ] Zero-address transfers handled correctly

### Governance Contracts

- [ ] Proposal ID computed deterministically
- [ ] Snapshot block is write-once
- [ ] Executed flag is one-way (never unset)
- [ ] Vote tallies cannot exceed supply snapshot
- [ ] Cannot vote twice on same proposal
- [ ] Timelock delay enforced before execution

### Access Control

- [ ] All privileged functions check authorization
- [ ] Role assignment functions are access controlled
- [ ] No function can bypass ACL via delegatecall
- [ ] Initialization can only happen once

### Economic Properties

- [ ] Ragequit payouts bounded by pool
- [ ] Price computation is monotonic
- [ ] No value creation from thin air
- [ ] Fee collection is bounded

---

## Appendix: CVL Syntax Quick Reference

```cvl
// Invariant declaration
invariant name(params)
    expression
    { preserved { setup code } }

// Parametric rule (all functions)
rule name(method f) {
    // setup
    env e; calldataarg args;
    f(e, args);
    // assertions
}

// Specific function rule
rule name() {
    env e;
    specificFunction(e, param1, param2);
    assert condition;
}

// Revert checking
function@withrevert(e, args);
assert lastReverted;

// Satisfy (reachability)
satisfy condition;

// Ghost variables
ghost type name;
hook Sstore path value (oldValue) { update ghost }
hook Sload type value path { require constraint }

// Method filters
filtered { f -> f.selector == sig:func().selector }
filtered { f -> !f.isView }
```
