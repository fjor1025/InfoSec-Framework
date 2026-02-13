# Writing Vulnerability Reports That Win

> **Purpose:** Teach auditors how to write reports that judges validate in 60 seconds.
> **Audience:** Experienced security researchers submitting to bug bounties and audit contests.
> **Core Principle:** A report is an argument, not a form. Every sentence must advance the judge toward "yes, this is valid."

---

## The Problem With Most Reports

Most rejected reports are technically correct but poorly communicated. They read like a checklist someone filled out rather than a story someone told. The judge opens your report, sees a wall of tables, brackets, and "TBD" placeholders, and their first instinct is to skim.

**Reports that win do three things:**
1. They tell a story with a beginning (what's broken), middle (why it matters), and end (how to fix it)
2. They make the judge feel confident without requiring them to think hard
3. They answer every objection before the judge raises it

**Reports that lose do three things:**
1. They describe a code pattern without explaining why it's dangerous
2. They leave the judge to "figure it out" from the PoC
3. They hedge with "could," "might," or "potentially" instead of proving

---

## The 60-Second Test

Before submitting, read your report as if you've never seen the codebase. Set a timer for 60 seconds. If you can't answer all three questions below, rewrite it:

1. **What breaks?** (invariant, assumption, guarantee)
2. **Who loses what?** (dollars, access, availability — be specific)
3. **How hard is it to exploit?** (one call? one block? one million dollars of capital?)

If the answer to any of these requires reading the PoC first, you've failed. The report must stand alone.

---

## Report Structure: The Guided Tour

Think of your report as a guided tour of a crime scene. You're the detective walking the judge through what happened. You don't hand them a stack of evidence bags and say "figure it out." You point at each thing, explain what it means, and connect it to the next thing.

### 1. Title — The Headline

The title is a news headline. It must communicate severity, location, and consequence in one line.

**Bad titles:**
- "Issue in withdraw function"
- "Potential reentrancy"
- "Missing check"

**Good titles:**
- "Critical: Missing share validation in Vault::withdraw() allows complete fund extraction"
- "High: Price oracle in Pool::swap() can be manipulated via flash loan to drain LP funds"
- "Medium: Unbounded loop in Staking::distributeRewards() enables gas-based DoS blocking all withdrawals"

**Pattern:** `[Severity]: [Root cause] in [Location] [enables/allows/causes] [concrete consequence]`

### 2. The Kill Shot — First Paragraph

The first paragraph decides whether the judge keeps reading or skips to the next report. You have three sentences. Use them.

**Structure:** `{root cause} will cause {impact} for {affected party} because {actor} can {attack path}.`

**Example:**
> The `withdraw()` function in `Vault.sol:L187` does not verify that `shares <= balanceOf[msg.sender]` before burning shares and transferring the underlying asset. An unprivileged attacker can call `withdraw(totalSupply)` and receive the entire vault balance, because the share-to-asset conversion happens before the balance check. This drains all depositor funds in a single transaction.

Notice: no hedging, no "could potentially," no "if conditions align." The attacker **can** do this. The protocol **loses** funds. Period.

### 3. Vulnerability Details — The Crime Scene

Now walk the judge through exactly what's broken and where.

**What judges need:**
- The exact file, function, and line number
- What the code does vs. what it should do
- Why the difference matters

**What judges don't need:**
- A description of how Solidity works
- An explanation of what ERC-20 tokens are
- Background on what a vault is

**Example:**

In [Vault.sol:L187](src/Vault.sol#L187), the `withdraw` function converts shares to assets and transfers them without first checking the caller's share balance:

```solidity
function withdraw(uint256 shares) external {
    uint256 assets = shares * totalAssets() / totalSupply();  // L188: conversion
    _burn(msg.sender, shares);                                 // L189: burn (reverts if insufficient)
    asset.transfer(msg.sender, assets);                        // L190: transfer
}
```

The developer assumed `_burn` would revert if `shares > balanceOf[msg.sender]`. This is true for the burn itself — but the asset calculation on L188 already computed a value based on `totalSupply()` which includes all shares, not just the caller's. The attacker passes `shares = totalSupply()` and receives `totalAssets()` worth of tokens. The burn then reduces the attacker's balance (which may be small or zero), but the transfer has already been calculated on the full supply.

**Key insight:** Show the judge the *reasoning gap* — the distance between what the developer assumed and what actually happens. This is more persuasive than just saying "missing check."

### 4. Impact — The Damage Report

Impact is not a severity label. Impact is a concrete statement about who loses what and how much.

**Bad impact:**
> "High impact. Funds at risk."

**Good impact:**
> The vault currently holds 2,847 ETH ($8.5M at current prices). An attacker with 0.1 ETH (gas costs) can extract the entire balance in a single transaction. All 1,204 depositors lose their full deposit with no recovery mechanism.

**When you can't know the exact TVL, bound it:**
> Any funds deposited into the vault after deployment are extractable. The attack cost is a single transaction fee (~$2), so the attacker profits on any vault balance above $2.

**For non-fund-loss impacts, be equally specific:**
> All staking operations revert for approximately 6 hours (45 blocks × 12 seconds × 30 iterations). During this period, no user can stake, unstake, or claim rewards. This is repeatable at a cost of ~0.05 ETH per 6-hour denial window.

### 5. Proof of Concept — The Evidence

The PoC is not your report. The PoC is evidence that supports your report. A judge should be able to understand your finding entirely from the report text and only use the PoC to verify that you're not lying.

**PoC rules:**
1. It must run. If it doesn't compile and pass, you've lost all credibility.
2. It must be minimal. Strip everything that isn't needed to demonstrate the bug.
3. It must have assertions. "Trust me, it works" is not evidence.
4. It must have comments that connect back to your report narrative.

**Example: Solidity (Foundry)**
```solidity
function testExploit_WithdrawDrainsVault() public {
    // Setup: Vault has 1000 ETH from legitimate depositors
    vm.deal(depositor, 1000 ether);
    vm.prank(depositor);
    vault.deposit{value: 1000 ether}();
    
    // Attacker starts with 0 shares and 0.1 ETH (gas only)
    address attacker = makeAddr("attacker");
    vm.deal(attacker, 0.1 ether);
    uint256 vaultBefore = address(vault).balance;  // 1000 ETH
    
    // Attack: single call with totalSupply as shares
    vm.prank(attacker);
    vault.withdraw(vault.totalSupply());
    
    // Result: vault drained, attacker has the funds
    assertEq(address(vault).balance, 0, "vault should be empty");
    assertGt(attacker.balance, 999 ether, "attacker should have vault funds");
}
```

**Example: Go (Cosmos)**
```go
func TestExploit_DrainModuleAccount(t *testing.T) {
    // Setup: module holds 1000 stake tokens
    app := simapp.Setup(false)
    ctx := app.BaseContext()
    moduleBalance := sdk.NewCoins(sdk.NewCoin("stake", sdk.NewInt(1000)))
    
    // Attack: unprivileged user triggers vulnerable handler
    attacker := sdk.AccAddress([]byte("attacker"))
    msg := types.NewMsgExploit(attacker, sdk.NewInt(1000))
    _, err := app.MsgServiceRouter().Handler(msg)(ctx, msg)
    require.NoError(t, err)
    
    // Result: attacker has module funds
    attackerBal := app.BankKeeper.GetBalance(ctx, attacker, "stake")
    require.Equal(t, sdk.NewInt(1000), attackerBal.Amount)
}
```

**Example: Rust (CosmWasm)**
```rust
#[test]
fn test_exploit_drain_contract() {
    let mut deps = mock_dependencies();
    // Setup: contract holds 1000 tokens
    setup_contract(deps.as_mut(), 1000u128);
    
    // Attack: unprivileged user calls withdraw with inflated amount
    let attacker = Addr::unchecked("attacker");
    let msg = ExecuteMsg::Withdraw { amount: Uint128::new(1000) };
    let res = execute(deps.as_mut(), mock_env(), mock_info(attacker.as_str(), &[]), msg);
    
    // Result: contract drained
    assert!(res.is_ok());
    let transfer_msg = &res.unwrap().messages[0];
    // Verify BankMsg::Send with full contract balance
}
```

### 6. Root Cause — The Diagnosis

State the root cause as a single clear sentence. Then show why it's a bug, not a design choice.

**Pattern:**
> In `[file:line]`, [what the code does wrong] because [why it's wrong].

**Example:**
> In `Vault.sol:L188`, the share-to-asset conversion uses `totalSupply()` as the denominator without first verifying the caller owns the shares being redeemed. This allows any caller to compute a payout based on the full vault balance regardless of their actual position.

**Why it's not a design choice:**
- The `deposit()` function at L145 correctly validates `amount > 0` before minting shares
- The NatSpec comment on L185 says "Redeems shares for proportional underlying assets"
- The test suite has a test `test_withdraw_reverts_insufficient_shares` that passes only because it uses a small withdrawal amount (doesn't trigger the edge case)

### 7. Recommendation — The Fix

A good recommendation is specific, minimal, and doesn't introduce new issues.

**Bad recommendation:**
> "Add proper validation."

**Good recommendation:**
```diff
function withdraw(uint256 shares) external {
+   require(shares <= balanceOf[msg.sender], "insufficient shares");
    uint256 assets = shares * totalAssets() / totalSupply();
    _burn(msg.sender, shares);
    asset.transfer(msg.sender, assets);
}
```

If the fix is non-trivial, explain the tradeoffs:
> Adding the `require` check before the calculation prevents the attack while preserving the existing share-to-asset conversion logic. An alternative approach — moving the `_burn` before the calculation — would also work but changes the `totalSupply()` denominator, which may affect the payout calculation for legitimate users.

---

## Semantic Phase Integration

Every finding should identify which semantic phase the bug lives in. This tells the judge (and yourself) exactly where in the execution flow the invariant breaks:

| Phase | The Bug Is Here When... |
|-------|------------------------|
| **VALIDATION** | A check is missing, wrong, or bypassable |
| **SNAPSHOT** | State is read stale, cached, or from the wrong source |
| **ACCOUNTING** | A calculation is wrong (rounding, overflow, oracle, fees) |
| **MUTATION** | State is modified in the wrong order or with wrong values |
| **COMMIT** | Storage writes are partial, duplicated, or missing |

**In your report, state this naturally:**
> "The vulnerable code path skips the VALIDATION phase entirely — no check verifies the caller's share balance before the ACCOUNTING phase computes the payout."

Don't use the phase names as table headers to fill in. Use them as diagnostic language in your narrative.

---

## Methodology Validation

Before submitting, verify these four checks. If any fails, your finding needs more work:

**Reachability** — Can this code path actually execute on a live chain?
- Is the function public/external? Is it behind a proxy that's deployed? Is the handler registered?
- If the code is unreachable, it's not a vulnerability.

**State Freshness** — Does your exploit work with realistic current state?
- Are you assuming an empty contract? A specific TVL? A particular block number?
- If the exploit only works in a contrived setup, say so explicitly and quantify when it applies.

**Execution Closure** — Have you modeled all external interactions?
- Does your exploit account for callbacks, reentrancy guards, flash loan fees, IBC acknowledgements?
- If you ignored an external call, the judge will find it.

**Economic Realism** — Is the attack profitable or meaningful?
- What does the attacker spend? What do they gain?
- If the attack costs more than it yields, it might be informational, not high severity.

State these checks as assertions in your report, not as a filled-out table:
> "This attack is reachable via the public `withdraw()` function on the deployed vault at [address]. It works with current on-chain state (any non-zero TVL). No external calls are involved. The attacker spends ~$2 in gas and extracts the full vault balance."

---

## Platform-Specific Severity Guidance

Different platforms define severity differently. Match your impact statement to the platform you're submitting to:

**Immunefi:**
- Critical = Direct theft of funds or permanent freeze (>$1M in scope)
- High = Direct theft (<$1M) or temporary freeze causing material loss
- Medium = Theft requiring unlikely conditions or governance manipulation

**Code4rena:**
- High = Assets can be stolen/lost/compromised directly, or protocol insolvency
- Medium = Functionality broken or value leaked under viable conditions
- Low = Informational or low-likelihood edge cases

**Sherlock:**
- High = Definite loss of funds without limitations or external conditions
- Medium = Conditional loss of funds or material loss of yield

**Hats Finance:**
- Critical = Direct loss or manipulation of funds without special conditions
- High = Conditional loss of funds or protocol stability impact

Adjust your language to match. A Sherlock "High" requires "definite loss without limitations" — if your exploit requires a flash loan, governance proposal, or specific oracle state, say so and argue why those conditions are easily met.

---

## Cross-Chain Report Considerations

When auditing non-Solidity smart contracts, adapt the report structure:

### Cosmos/Go Reports
- PoC should be a Go test, not pseudocode
- Explicitly state whether the bug is in a message handler (single-user impact) or BeginBlock/EndBlock (chain-wide impact)
- For chain halt bugs, emphasize the consensus failure — this is typically Critical by definition
- Reference known patterns: "This resembles the Dragonberry vulnerability (ICS-23 proof bypass)"

### Rust/CosmWasm/Solana Reports
- Specify the framework (CosmWasm vs Anchor vs Substrate) — they have different security models
- For Solana: include the account validation context (which accounts, which constraints)
- For CosmWasm: show the exact message and entry point
- For Substrate: include the weight/fee analysis if relevant

### Cairo/StarkNet Reports
- Show felt252 arithmetic issues with actual prime field math, not just "it overflows"
- For L1↔L2 bridge bugs, diagram the cross-layer message flow
- Include Caracal detector references if the pattern is known

### Algorand/PyTeal Reports
- Show the transaction group construction for the exploit
- Explicitly list which transaction fields are missing validation
- Reference Tealer detectors if the pattern is known
- For smart signature bugs, construct the actual signing transaction

---

## Common Mistakes That Get Reports Rejected

**1. "This function doesn't check X"**
Not a finding unless you explain what happens when X is unchecked. Missing a check is a code pattern. Draining funds is a vulnerability.

**2. "An attacker could potentially..."**
Remove the word "potentially" from your vocabulary. Either they can or they can't. If you're unsure, do the work to find out before submitting.

**3. Submitting a PoC without a report**
"See the test" is not a report. The test proves the exploit works. The report explains why it matters and how to fix it.

**4. Copy-pasting the code and saying "this is wrong"**
The judge can read code too. Tell them something they can't see by reading: the semantic gap between intent and implementation.

**5. Wrong severity**
A missing event emission is not High severity. A gas optimization is not Medium. Overclaiming severity destroys your credibility for the findings that actually matter.

**6. Not anticipating objections**
If there's an obvious counterargument ("but the admin can pause"), address it: "The admin pause function at L205 only prevents new deposits, not withdrawals. The attack vector remains open even when paused."

**7. Vague recommendations**
"Add proper validation" teaches nobody anything. Show the exact `require` statement, the exact line to add it, and explain why that location prevents the bug without breaking legitimate use.

---

## Report Quality Checklist

Read your final report and verify:

- [ ] **Title** communicates severity + location + consequence in one line
- [ ] **First paragraph** is the complete finding in 3 sentences
- [ ] **Zero hedging** — no "could," "might," "potentially," "if conditions are right"
- [ ] **Exact location** — file, function, line number, not "somewhere in the contract"
- [ ] **Concrete impact** — dollars, users, duration, not "funds at risk"
- [ ] **Working PoC** — compiles, runs, has assertions, has comments
- [ ] **Root cause** — single sentence explaining the bug, not a code walkthrough
- [ ] **Not a design choice** — evidence the developer intended different behavior
- [ ] **Recommendation** — diff-style fix at the exact location
- [ ] **No jargon without explanation** — if you use a technical term, the judge knows what you mean in context
- [ ] **Validation checks** pass — Reachability, State Freshness, Execution Closure, Economic Realism

---

**Framework Version:** 2.0
**Last Updated:** February 2026
**Compatible with:** All ecosystem frameworks (Solidity, Rust, Go, Cairo, Algorand)
