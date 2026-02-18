# Writing Vulnerability Reports That Win

> **Purpose:** Teach auditors how to write reports that judges validate in 60 seconds — and that survive the escalation process afterward.
> **Audience:** Experienced security researchers submitting to bug bounties and audit contests.
> **Core Principle:** A report is an argument, not a form. Every sentence must advance the judge toward "yes, this is valid."
> **Defense Principle:** A winning report doesn't just persuade — it preempts every objection the judge, sponsor, or rival warden will raise. 

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

**Reports that get invalidated after acceptance do one more thing:** 
4. They omit constraints, preconditions, or known-issue context that the sponsor or a rival warden discovers during escalation

---

## The 60-Second Test

Before submitting, read your report as if you've never seen the codebase. Set a timer for 60 seconds. If you can't answer all three questions below, rewrite it:

1. **What breaks?** (invariant, assumption, guarantee)
2. **Who loses what?** (dollars, access, availability — be specific)
3. **How hard is it to exploit?** (one call? one block? one million dollars of capital?)

If the answer to any of these requires reading the PoC first, you've failed. The report must stand alone.

---

## Pre-Submission Defense Gate

> **Most rejected reports are not rejected for bad writing. They're rejected because the researcher didn't check what the judge already knows.**

Before writing a single word, run this defense gate. If any item fails, your report is dead on arrival regardless of quality:

### 1. Known Issues & Previous Audits

- [ ] **Read the contest README / known issues list.** Every Sherlock and Code4rena contest publishes known issues. If your finding appears there, it's auto-invalid.
- [ ] **Read all linked previous audit reports.** Most contests link prior audits (Trail of Bits, OpenZeppelin, Spearbit, etc.). If your finding was already reported and acknowledged, it's a known issue.
- [ ] **Search the protocol's GitHub issues and discussions.** Developers often discuss edge cases in issues. If you find a comment like "we accept this risk because...", your finding needs to explicitly argue why their acceptance is wrong.
- [ ] **Check deployed contract state.** For Immunefi/live bounties, verify the vulnerability exists on the deployed code, not just the repo version.

### 2. Scope Verification

- [ ] **Confirm the contract/function is in scope.** Contest scoping documents are precise. A perfect finding on an out-of-scope contract is worth zero.
- [ ] **Confirm the attack vector uses in-scope entry points.** If your exploit requires calling a function on a contract that's out of scope, articulate why the in-scope contract is still the root cause.

### 3. Duplicate Differentiation

If your finding touches a common pattern (reentrancy, oracle manipulation, rounding), preemptively differentiate:

- **State the unique root cause** — not "reentrancy in withdraw" but "reentrancy specifically in the share calculation at L188, not the transfer at L190"
- **If multiple functions share the same bug**, submit ONE report covering all instances — not separate reports per function. (See "Multi-Finding Strategy" below.)
- **If a similar-looking finding exists**, explain in your report why yours is a different root cause: "Unlike the missing-slippage-check pattern in `swap()`, this issue stems from a stale oracle read in `liquidate()` — different semantic phase (SNAPSHOT vs VALIDATION), different exploit path, different fix."

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

**Important: Confidence ≠ Omission (Constraint Envelope)** 

Eliminate weasel words (`could`, `might`, `potentially`). But **keep constraint words** (`when`, `requires`, `given that`). The kill shot must include the conditions under which the attack works:

> The `withdraw()` function in `Vault.sol:L187` does not verify that `shares <= balanceOf[msg.sender]` **when the vault has active deposits** (TVL > 0). An unprivileged attacker can call `withdraw(totalSupply)` and receive the entire vault balance in a single transaction. This drains all depositor funds. **The attack does not work when the vault is empty or when the contract is paused** (the pause guard at L12 blocks all external calls).

The constraint envelope shows the judge you've done thorough analysis, not just the happy-path attack. Judges discover omitted constraints during review and treat them as dishonesty, which downgrades or invalidates findings. State what works, state what doesn't, and argue why the working conditions are realistic.

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

Before submitting, verify these five checks. If any fails, your finding needs more work:

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

**Detection & Response** — Can the protocol see and stop this? 
- Does the attack emit events that monitoring systems would catch?
- Does the protocol have a pause mechanism that could halt the attack mid-execution?
- Is the attack frontrunnable by MEV bots (which may help or hurt the attacker)?
- If the attack is silent (no unusual events, looks like normal usage), state this — it's an aggravating factor that strengthens severity.
- If the protocol can detect and respond within one block, acknowledge this and argue why the attack still completes before response.

State these checks as assertions in your report, not as a filled-out table:
> "This attack is reachable via the public `withdraw()` function on the deployed vault at [address]. It works with current on-chain state (any non-zero TVL). No external calls are involved. The attacker spends ~$2 in gas and extracts the full vault balance. The attack completes in a single transaction; the protocol's pause mechanism (triggered manually by a 3/5 multisig) cannot respond before the funds are extracted."

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
Remove weasel words (`could`, `might`, `potentially`, `if conditions align`) from your vocabulary. Either they can or they can't. If you're unsure, do the work to find out before submitting. **However:** keep constraint words (`when`, `requires`, `given that`) — omitting valid preconditions is overclaiming, which judges treat as dishonesty. See the Constraint Envelope section above.

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

**8. Submitting a known issue** 
You didn't read the contest README, the previous audit reports, or the protocol's GitHub issues. The finding was already reported, acknowledged, and accepted. This is the #1 rejection vector on Sherlock and Code4rena. Always run the Pre-Submission Defense Gate.

**9. Splitting findings from the same root cause** 
If `transfer()`, `transferFrom()`, and `burn()` all have the same missing balance check, that's ONE finding with three instances — not three findings. Splitting inflates your count but gets you marked as a duplicator. See Multi-Finding Strategy below.

---

## Multi-Finding Strategy 

When you find multiple bugs, you must decide: one report or multiple? The wrong choice gets valid findings invalidated.

### Same Root Cause = One Report

If multiple functions share the same underlying bug (same missing check, same flawed calculation, same broken assumption), submit **one report** listing all affected locations:

> **Root cause:** The `_computeShares()` internal function at L88 does not account for fee-on-transfer tokens.
> **Affected functions:** `deposit()` (L120), `withdraw()` (L187), `rebalance()` (L245)
> **Impact:** Each function miscalculates shares by the fee amount, but the impact differs...

### Different Root Cause = Separate Reports

If two bugs happen to affect the same function but stem from different logical errors, submit separately and explicitly state why they're distinct:

> "This finding addresses the oracle staleness check in `liquidate()` at L55. It is distinct from [Finding #X] which addresses the collateral ratio calculation at L62 — different semantic phase (SNAPSHOT vs ACCOUNTING), different root cause, and different fix."

### Platform Rules

| Platform | Same Root Cause Policy | Split Penalty |
|----------|----------------------|---------------|
| **Sherlock** | Grouped into one finding | Splits are collapsed; you get credited for one |
| **Code4rena** | Grouped by root cause | Duplicate submissions waste your time |
| **Immunefi** | Each submission standalone | Combining may undersell total severity |
| **Hats Finance** | Grouped by root cause | Similar to Sherlock |

---

## Judge Objection Taxonomy

Judges and sponsors use a predictable set of objection patterns to invalidate findings. Know them in advance and address each one that applies **in your report**, before you submit.

| Objection | What the Judge Says | How to Preempt It |
|-----------|-------------------|-------------------|
| **Trusted Role** | "This requires admin action" | "The attack requires no privileged access. The function at L187 is `external` with no modifier." Or, if admin IS required: argue why admin compromise is in scope per platform rules. |
| **By Design** | "See comment at line X" | "The NatSpec at L185 says 'proportional assets,' but the implementation allows disproportionate extraction. The design intent is violated, not followed." |
| **Low Likelihood** | "Requires specific conditions" | State all conditions explicitly and argue they're common: "This requires TVL > 0 and an unpaused contract — the default state since deployment." |
| **Duplicate** | "Same root cause as #42" | Differentiate: "Unlike #42 (missing slippage check in `swap()`), this finding targets a stale oracle read in `liquidate()` — different phase, different path, different fix." |
| **Informational** | "No material impact" | Quantify the impact: dollars lost, users affected, duration of DoS. "Informational" means you failed to prove material harm. |
| **Out of Scope** | "This contract isn't in scope" | "The vulnerable code is in-scope `Vault.sol:L187`. The external call to `Token.sol` is a dependency, not the root cause." |
| **Economic Infeasibility** | "Attack costs more than it yields" | Show the math: "Attacker spends 0.003 ETH (gas). Attacker receives [TVL]. ROI: [TVL/0.003]x." |
| **External Dependency** | "Relies on oracle/external protocol" | "The oracle manipulation is achievable via flash loan (cost: 0.05% fee on $X). The external dependency is exploitable, not theoretical." |
| **Known Issue** | "Listed in README / previous audit" | "The previous Trail of Bits audit (Finding 3.2) identified a *different* oracle issue in `swap()`. This finding targets `liquidate()`, which was not covered." |
| **Time-Decay** | "State changes next block" | "The attack completes atomically in one transaction. No cross-block state dependency exists." |

**Rule:** If more than two of these objections apply to your finding and you can't convincingly refute them, consider whether the finding is actually valid at the severity you're claiming.

---

## Escalation & Post-Submission Defense

Your report's life doesn't end at submission. On every major platform, there's a dispute phase where sponsors, judges, and rival wardens challenge your findings. **30-40% of contest outcomes are determined during escalation, not during initial submission.**

### Platform Dispute Mechanisms

| Platform | Process | Your Window |
|----------|---------|-------------|
| **Sherlock** | 48-hour escalation period after initial judging | Wardens can escalate (challenge invalidation) or de-escalate (challenge validation) |
| **Code4rena** | Post-judging QA + sponsor feedback | Sponsors comment on each finding; judge makes final call |
| **Immunefi** | Multi-round triage with program team | You may get 2-3 rounds of questions before accept/reject |
| **Hats Finance** | Community review period | Other auditors can challenge |

### How to Respond to Sponsor Pushback

When a sponsor says "this is by design" or "this doesn't apply":

1. **Don't argue emotion.** Respond with code references and on-chain evidence.
2. **Quote their own code against them.** NatSpec comments, README descriptions, and test names that contradict the sponsor's claim are powerful.
3. **Provide additional PoC if needed.** If the sponsor says "the attacker can't do X" and they can, write a second targeted test proving it.
4. **Reference platform rules, not opinions.** "Per Sherlock judging criteria Section IV: 'Issues that cause loss of funds without external conditions are High severity.' This finding meets that criteria because..."

### When to Escalate vs. Accept

- **Escalate** when you have concrete evidence the judge missed: a code reference, a PoC, a platform rule citation.
- **Accept a downgrade** when the judge identifies a constraint you genuinely missed. Fighting valid downgrades damages your reputation.
- **Never escalate on vibes.** "I feel this is High" is not an argument. "Per platform rules, unconditioned fund loss is High; here's why the conditions are met" is.

### Writing an Escalation Comment

**Bad escalation:**
> "I disagree with the invalidation. This is clearly a High severity issue."

**Good escalation:**
> "I'm escalating this finding based on three points:
> 1. The sponsor states 'admin can pause before exploit.' However, the pause function at L205 requires a 48-hour timelock (see `TimelockController.sol:L89`). The attack completes in one block.
> 2. The judge grouped this with Finding #42, but the root causes differ: #42 is a missing access control check (VALIDATION phase); this finding is a stale price read (SNAPSHOT phase). They require different fixes.
> 3. Per [platform] judging criteria: 'Loss of funds without realistic external conditions is High.' The only condition is TVL > 0, which has held since deployment (verified on-chain)."

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
- [ ] **Validation checks** pass — Reachability, State Freshness, Execution Closure, Economic Realism, Detection & Response
- [ ] **Constraint envelope** — attack conditions AND failure conditions both stated 
- [ ] **Pre-submission defense** — known issues, previous audits, scope, and duplicates checked
- [ ] **Objections preempted** — each applicable judge objection addressed in the report 
- [ ] **Multi-finding strategy** — same root cause = one report; different root cause = separate reports.

---

**Framework Version:** 2.1 (Red Team Hardening)
**Last Updated:** February 18, 2026
**Compatible with:** All ecosystem frameworks (Solidity, Rust, Go, Cairo, Algorand)

### v2.1 Changelog (Red Team Hardening)
- **Pre-Submission Defense Gate:** Known issues, previous audits, scope verification, duplicate differentiation
- **Constraint Envelope:** Distinction between hedging (bad) and constraint bounding (necessary)
- **Judge Objection Taxonomy:** 10 objection patterns with preemptive defense strategies
- **Escalation & Post-Submission Defense:** Platform dispute mechanisms, sponsor pushback responses, escalation writing
- **Multi-Finding Strategy:** Same root cause vs. different root cause, platform-specific rules
- **Detection & Response:** 5th methodology validation check for attack observability
- **Updated quality checklist:** 5 new items for defensive completeness
