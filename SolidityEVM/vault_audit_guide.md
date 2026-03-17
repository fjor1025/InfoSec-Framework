# SafeCast Vault Exploit — Identification Guide

> **Technique:** Identify unsafe-downcast vulnerabilities inside vault share/asset accounting in under 30 seconds, even in 50,000-line codebases.
> **Framework integration:** Extends [audit-workflow1.md](audit-workflow1.md) Step 5.2 (Vault/ERC-4626) and Pashov vectors V32, V70.
> **Audience:** Experienced smart contract auditors who already understand ERC-4626 share math.

---

## The Core Exploit Pattern

ERC-4626 vaults (and custom vault designs) compute share prices using two global accumulators:

```
sharePrice = totalAssets / totalSupply
shares     = assets × totalSupply / totalAssets
assets     = shares × totalAssets / totalSupply
```

Many gas-optimised implementations pack `totalAssets` and/or `totalSupply` into a struct slot alongside other values. The most common packing choice is `uint128` (saves one SLOAD). When a developer writes:

```solidity
// VULNERABLE — bare downcast, no bounds check
state.totalAssets = uint128(newTotalAssets);
```

Solidity ≥ 0.8 silently truncates any value exceeding `2^128 − 1` (≈ 3.4 × 10^38). The result wraps to a tiny residual, collapsing the share price to near-zero or inflating it astronomically — enabling an attacker to drain the vault.

The `SafeCast` library equivalent reverts before truncation:

```solidity
// SAFE — SafeCast.toUint128 reverts if newTotalAssets > type(uint128).max
state.totalAssets = SafeCast.toUint128(newTotalAssets);
```

---

## 30-Second Identification Protocol

Run the following three grep commands in sequence. Each takes about 5–10 seconds on a 50 kLOC codebase.

### Step 1 — Locate all bare downcasts (10 seconds)

```bash
grep -rn \
  "uint128(\|uint96(\|uint64(\|uint32(\|uint16(\|uint8(\|int128(\|int64(\|int32(" \
  contracts/ --include="*.sol" \
| grep -v \
  "SafeCast\|type(uint\|type(int\|//\| \*\|^\s*//"
```

> **What you are looking for:** Any explicit narrowing cast not guarded by `SafeCast` and not preceded by a `type(uintN).max` bounds check.

### Step 2 — Locate vault accounting functions (5 seconds)

```bash
grep -rn \
  "totalAssets\|totalSupply\|convertToShares\|convertToAssets\
\|previewDeposit\|previewWithdraw\|previewMint\|previewRedeem\
\|_assets\b\|_shares\b\|storedAssets\|storedShares" \
  contracts/ --include="*.sol" \
| grep -v "//\|^\s*//"
```

### Step 3 — Cross-reference overlap (15 seconds, manual)

Review the file names and function names from Steps 1 and 2. Flag every location where:

| Condition | Risk level |
|-----------|-----------|
| Same function contains both a bare downcast AND reads/writes `totalAssets` or `totalSupply` | **Critical** |
| Bare downcast result is written to a state variable later read by `convertToShares` / `convertToAssets` | **Critical** |
| Bare downcast is on a value derived from user input (deposit `amount`, flash-loan repay amount) | **High** |
| Bare downcast is inside an `unchecked` block | **Critical** (double-silent failure) |

---

## The Five Canonical Exploit Sites

Unsafe downcasts in the following five locations have appeared repeatedly across audits:

| Site | Vulnerable pattern | Attack consequence |
|------|-------------------|-------------------|
| `_update` / `_deposit` hook | `state.totalAssets = uint128(assets + earned)` | Share price collapse → unlimited share minting |
| `_withdraw` / `_redeem` hook | `state.totalShares = uint128(totalSupply - burned)` | Share price explosion → withdrawal of full vault with dust shares |
| Reward/interest accrual | `uint128(accumulatedInterest)` stored, then added to `totalAssets` | Interest truncated → incorrect share price, silent fund loss |
| Price oracle integration | `uint128(latestAnswer)` stored as asset price | Price truncation → wrong collateral valuation in lending vaults |
| Cross-contract accounting | Vault returns `uint128` to a strategy; strategy uses it as `uint256` in further math | Silent undercount propagates into downstream accounting |

---

## Exploit Chain — Step by Step

The following shows how a truncation at site #1 leads to fund loss:

```
1. Protocol accumulates yield: newTotalAssets = 2^128 + 50_000e18
2. Developer writes:          state.totalAssets = uint128(newTotalAssets)
3. Solidity truncates to:     state.totalAssets = 50_000e18  ← catastrophic loss
4. Share price becomes:       50_000e18 / totalSupply        ← near-zero
5. Attacker calls deposit(1e18):
   shares = 1e18 × totalSupply / 50_000e18 → extremely large share grant
6. Attacker calls redeem(allShares):
   assets = shares × 50_000e18 / (totalSupply + large_shares)
   → extracts nearly all vault assets
7. Vault is drained; honest depositors receive zero
```

> **Economic Realism check:** The attack requires the vault's `totalAssets` to reach `2^128` (≈ 3.4 × 10^38 in the token's smallest unit). For an 18-decimal token, that equals 3.4 × 10^20 tokens (dividing by 10^18 per token). At $1 per token that is ≈ $3.4 × 10^20 — clearly impossible for most protocols. However, protocols may use **scaled values** (e.g., interest-rate accumulators, fee accumulators, or rebasing index multipliers expressed in WAD/RAY). A 27-decimal RAY accumulator reaches `2^128` after only ≈ 3.4 × 10^11 units of the underlying token — reachable in high-TVL or long-running protocols. Always confirm the unit of the accumulated value before dismissing this as an FP.

---

## Quick Mental Checklist During Code Review

```markdown
## SafeCast Vault Audit Checklist

### Downcast Locations
- [ ] Every explicit narrowing cast in scope identified (grep Step 1)
- [ ] Each cast verified: SafeCast OR preceded by `require(x <= type(uintN).max)`
- [ ] No bare casts inside `unchecked` blocks touching vault state

### Vault Accounting Integrity
- [ ] `totalAssets` storage type can hold the protocol's maximum realistic value
- [ ] `totalSupply` storage type can hold the protocol's maximum realistic value
- [ ] No packed struct fields for vault accumulators without overflow analysis
- [ ] Reward / interest accumulators use full-width types or have documented max bounds

### Share Price Invariant
- [ ] `convertToShares` and `convertToAssets` always read the correct (non-truncated) values
- [ ] `previewDeposit` / `previewWithdraw` results consistent with `deposit` / `withdraw` actual results
- [ ] No rounding direction violation (EIP-4626: deposit rounds DOWN, withdraw rounds UP)

### Cross-Contract Propagation
- [ ] Strategy contracts receive full-width values from the vault, not pre-truncated uint128
- [ ] Return values from external yield sources (Aave, Compound, Yearn) safely widened before vault math
```

---

## PoC Skeleton

Use this Foundry template to prove truncation-based drain:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {VulnerableVault} from "../src/VulnerableVault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract SafeCastVaultDrainTest is Test {
    VulnerableVault vault;
    MockERC20 asset;

    address attacker = address(0xBAD);
    address victim   = address(0xABC);

    function setUp() public {
        asset = new MockERC20("Token", "TKN", 18);
        vault = new VulnerableVault(address(asset));

        // Victim deposits 10_000 tokens
        asset.mint(victim, 10_000e18);
        vm.prank(victim);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(victim);
        vault.deposit(10_000e18, victim);
    }

    function testTruncationDrain() public {
        // Simulate accumulated value that pushes totalAssets past uint128 boundary
        // (e.g. via a direct donation, interest accrual mock, or state manipulation)
        uint256 bigDonation = type(uint128).max; // 2^128 - 1
        asset.mint(address(vault), bigDonation + 1); // +1 causes truncation on next accrual

        // Trigger the vulnerable accrual function that stores uint128(totalAssets)
        vault.accrueYield(); // <-- the function containing the bare downcast

        // totalAssets is now truncated to a tiny value; attacker exploits the mispriced shares
        asset.mint(attacker, 1e18);
        vm.startPrank(attacker);
        asset.approve(address(vault), type(uint256).max);
        uint256 shares = vault.deposit(1e18, attacker);
        uint256 drained = vault.redeem(shares, attacker, attacker);
        vm.stopPrank();

        // Assert attacker received more than they deposited
        assertGt(drained, 1e18, "No drain — downcast may be guarded");

        // Assert victim lost funds
        uint256 victimAssets = vault.previewRedeem(vault.balanceOf(victim));
        assertLt(victimAssets, 10_000e18, "Victim unharmed — re-check totalAssets type");
    }
}
```

---

## False Positive Conditions

Flag the finding as a **false positive** (or downgrade severity) when:

| Condition | Reasoning |
|-----------|-----------|
| `SafeCast.toUint128(x)` used | Reverts before truncation — safe by design |
| `require(x <= type(uint128).max)` precedes every cast | Explicit bounds check equivalent to SafeCast |
| Storage type analysis proves `totalAssets` can never reach `2^N` | Document the proof; flag as informational |
| Protocol is explicitly capped (e.g., `maxDeposit` enforces a hard limit below `type(uint128).max`) | The cap prevents the truncation trigger; still flag if cap is mutable |
| Solmate / OZ `ERC4626` base used without overriding conversion functions | Base uses full `uint256` throughout — no packing by default |

---

## Pashov Vector Cross-References

| Vector | Relationship to SafeCast vault exploit |
|--------|----------------------------------------|
| **V32** — Small-Type Arithmetic Overflow Before Upcast | Precursor: arithmetic overflow on narrow type before widening assignment |
| **V70** — Unsafe Downcast / Integer Truncation | Direct match: bare `uint128(largeUint256)` without bounds check |
| **V33** — ERC4626 Missing Allowance Check in withdraw/redeem | Combine with V70: allowance bypass + share miscalculation = double exploit |
| **V56** — ERC4626 Preview Rounding Direction Violation | Amplifier: rounding errors magnify the truncation-induced price distortion |
| **V133** — ERC4626 Round-Trip Profit Extraction | Same vault share math surface; truncation creates permanent round-trip profit |
| **V167** — ERC4626 Inflation Attack (First Depositor) | Related entry point: inflation attack exploits the same `totalAssets/totalSupply` ratio |

> **Scan prompt:** Use `SCAN SafeCast Vault Exploit` (see `Audit_Assistant_Playbook.md`) to automate detection across the full codebase.

---

## Remediation

```solidity
// Before (vulnerable)
function _accrueYield(uint256 newYield) internal {
    state.totalAssets = uint128(_totalAssets() + newYield); // silent truncation
}

// After (safe)
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

function _accrueYield(uint256 newYield) internal {
    state.totalAssets = SafeCast.toUint128(_totalAssets() + newYield); // reverts if overflow
}
```

If the protocol genuinely needs values above `2^128`, widen the storage type to `uint256`:

```solidity
struct VaultState {
    uint256 totalAssets;   // no packing — correctness over gas savings
    uint256 totalShares;
}
```

---

## Integration with Audit Workflow

| Workflow phase | Action |
|----------------|--------|
| **Phase 1 — Triage** (Step 1.2) | Add `uint128` storage fields to Token Integration Profile |
| **Phase 2 — Entry Points** (Step 2.1) | Include `accrueYield`, `harvest`, `sync`, `update` as vault entry points |
| **Phase 5 — Deep Analysis** (Step 5.2, Vault/ERC-4626) | Run the 30-second grep sequence; cross-reference with the five canonical sites |
| **Phase 5 — Pashov triage** (Step 5.2b) | Promote V32 + V70 to Survive if any bare downcast found near vault math |
| **Phase 6 — Finding Documentation** | Use root cause category: Integer Overflow/Underflow; Semantic Phase: ACCOUNTING |
