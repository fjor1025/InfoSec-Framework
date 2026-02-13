# Smart Contract Audit Methodology - Manual Workflow

> **Integration Note:** This file contains the audit *methodology* and heuristics.
> For conversation structure, see `../Audit_Assistant_Playbook.md`.
> For the system prompt, see `CommandInstruction.md`.

---

## **Phase 1: Initial Triage & Scope Definition**

### **Step 1.1: Time-Boxing Strategy (For Large Codebases)**
Prevent analysis paralysis with structured time allocation:

```markdown
**Round 1 (40% of time): Quick Triage ALL Entry Points**
- 5 minutes max per function
- Build spine, note red flags, move on
- Goal: Map the attack surface

**Round 2 (40% of time): Deep Dive TOP 5 Priority Functions**
- Full checklist, attack simulation
- Document findings as you go
- Goal: Find critical vulnerabilities

**Round 3 (20% of time): Cross-Function & Edge Cases**
- Interaction bugs between audited functions
- Edge case testing on highest-value paths
- Goal: Catch composition bugs
```

**Time Tracking Template:**
```markdown
| Phase | Allocated | Actual | Functions Covered |
|-------|-----------|--------|-------------------|
| Triage | 4 hours | _ | deposit, withdraw, transfer, ... |
| Deep Dive | 4 hours | _ | withdraw, liquidate, ... |
| Cross-Function | 2 hours | _ | withdraw+liquidate interaction |
```

---

### **Step 1.2: Protocol Understanding Template**

## Protocol Summary

**Core Purpose**: [What does this protocol do in one sentence?]

**Key Contracts**:
- `Main.sol`: [Primary logic]
- `Token.sol`: [ERC20/ERC721 implementation]
- `Oracle.sol`: [Price feeds]
- `Governance.sol`: [Voting/upgrades]

**Value Flows**:
1. Users deposit → [Where does value go?]
2. Protocol earns → [How are fees taken?]
3. Users withdraw → [How is value returned?]

**Admin Powers**:
- [ ] Can pause/unpause
- [ ] Can upgrade contracts
- [ ] Can change parameters
- [ ] Can withdraw funds

**External Dependencies**:
- Oracle: [Chainlink/Uniswap/Other]
- Tokens: [ERC20s accepted]
- Bridges: [Cross-chain connections]

---

## **Phase 2: Entry Point Identification**

### **Step 2.1: Find ALL Attack Surfaces**
```
# Find all external functions
"(public|external)" | "view\|pure"

# check each contract for:
"function.*external\|function.*public"
```
### **Step 2.2: Prioritization Matrix**
```markdown
## Priority 1 (Attack Immediately)
- [ ] Functions that move funds (transfer, withdraw, send)
- [ ] Functions with admin powers (setParams, upgrade, pause)
- [ ] Functions with oracle calls (price updates)
- [ ] Functions that mint/burn tokens

## Priority 2 (Attack After)
- [ ] View functions that could be manipulated
- [ ] Internal functions with public visibility
- [ ] Functions with time dependencies

## Priority 3 (Check Later)
- [ ] Gas optimization opportunities
- [ ] Event emission issues
- [ ] Code style violations
```

### **Step 2.3: Entry Point Quick Assessment**
For EACH function found, ask:
1. **Can it be called by anyone?** (access controls)
2. **Does it move value?** (ETH/tokens)
3. **Does it change state?** (storage writes)
4. **Does it read external data?** (oracles/timestamps)
5. **Can it be reentered?** (external calls)

---

## **Phase 3: Mental Model Building**

### **Step 3.1: Draw the Data Flow**
```text
               [User Input]
                    ↓
           ┌─────────────────┐
           │  Validation     │ ← Access controls, limits
           └─────────────────┘
                    ↓
           ┌─────────────────┐
           │  State Reads    │ ← Storage, oracles, time
           └─────────────────┘
                    ↓
           ┌─────────────────┐
           │  Computation    │ ← Math, fees, interest
           └─────────────────┘
                    ↓
           ┌─────────────────┐
           │  State Writes   │ ← Storage updates
           └─────────────────┘
                    ↓
           ┌─────────────────┐
           │  External Calls │ ← Other contracts
           └─────────────────┘
```

### **Step 3.2: Identify Key Invariants**
For ANY protocol, these invariants MUST hold:
```solidity
// 1. No free money
assert(totalAssets >= totalLiabilities);

// 2. No double spending
assert(balanceOf[user] <= totalSupply);

// 3. Time moves forward
assert(block.timestamp >= lastUpdated);

// 4. Access controls work
assert(msg.sender == owner || hasRole(msg.sender, role));

// 5. Math doesn't overflow
assert(a + b >= a); // Addition check
assert(a - b <= a); // Subtraction check
```

### **Step 3.3: Map State Variables**
Create a quick table:
```markdown
| Variable | Type | Who Sets? | Who Updates? | Validated? |
|----------|------|-----------|--------------|------------|
| balanceOf | mapping | mint() | transfer() | ✅ |
| totalSupply | uint256 | mint() | burn() | ❌ |
| paused | bool | owner | owner | ❌ |
| feeRate | uint256 | owner | owner | ❌ |
```

### **Step 3.4: Storage Layout Verification (For Proxies/Upgradeable Contracts)**
If the contract uses proxy/upgrade patterns, storage collisions are CRITICAL:

```markdown
**Storage Slot Mapping:**
| Slot | Variable | Contract | Size | Gap? |
|------|----------|----------|------|------|
| 0 | _initialized | Initializable | 1 byte | - |
| 0 | _initializing | Initializable | 1 byte | - |
| 1-50 | __gap[50] | Initializable | 50 slots | ✅ |
| 51 | _owner | Ownable | 20 bytes | - |
| 52-101 | __gap[50] | Ownable | 50 slots | ✅ |
| 102 | balances | Token | 32 bytes | - |
```

**Proxy Storage Checklist:**
- [ ] Implementation uses `initializer` modifier (not constructor)
- [ ] All inherited contracts have storage gaps (`__gap`)
- [ ] No storage variables added between existing ones in upgrades
- [ ] `delegatecall` target is trusted/immutable
- [ ] Admin slots use EIP-1967 standard locations

**Common Storage Collision Patterns:**
```solidity
// DANGEROUS: New variable inserted before existing ones
contract V2 {
    uint256 newVar;      // <-- Collides with balances!
    mapping balances;    // Now at wrong slot
}

// SAFE: New variables added at end
contract V2 {
    mapping balances;    // Same slot as V1
    uint256 newVar;      // New slot at end
}
```

---

## **Phase 4: Deep Dive Audit**

### **Step 4.1: Choose ONE Function to Audit**
Start with the highest priority function. Use this checklist:

```markdown
## Function: [functionName]

### 1. Signature Check
- [ ] Function visibility (public/external)
- [ ] Modifiers (onlyOwner, nonReentrant, whenNotPaused)
- [ ] Parameters and their types

### 2. Storage Reads (Snapshot Phase)
Lines that read from storage:
- [ ] `balanceOf[address]`
- [ ] `totalSupply`
- [ ] `paused`
- [ ] `lastUpdated`
- [ ] Other mappings/structs

Questions:
- Could this data be stale?
- Is it reading the right slot?
- Could it be frontrun?

### 3. External Data (Accounting Phase)
Lines that read external data:
- [ ] `block.timestamp` / `block.number`
- [ ] `msg.sender` / `msg.value`
- [ ] Oracle calls (`chainlink.latestAnswer()`)
- [ ] Other contract calls

Questions:
- Can timestamp be manipulated?
- Is oracle secure/resistant?
- Are external calls safe?

### 4. Validation Checks
Lines that check conditions:
- [ ] `require(condition, "error")`
- [ ] `assert(condition)`
- [ ] `if (!condition) revert()`
- [ ] Access control checks

Questions:
- Are all inputs validated?
- Are limits enforced?
- Can checks be bypassed?

### 5. State Changes (Mutation Phase)
Lines that write to storage:
- [ ] `balanceOf[address] = value`
- [ ] `totalSupply += amount`
- [ ] `paused = true`
- [ ] Other assignments

Questions:
- Is value conserved?
- Could there be overflow/underflow?
- Are changes atomic?

### 6. External Calls
Lines that call other contracts:
- [ ] `otherContract.functionCall()`
- [ ] `address.call{value: x}("")`
- [ ] `token.transfer(to, amount)`

Questions:
- Could this be reentered?
- Is return value checked?
- Is gas limited?

### 7. Events & Cleanup
Lines that emit events or clean up:
- [ ] `emit EventName(...)`
- [ ] `delete variable`
- [ ] Storage slot clearing

Questions:
- Are events emitted for all changes?
- Is temporary storage cleaned?
- Are events emitted before or after state changes?
```

### **Step 4.2: Trace Internal Calls**
For EACH internal function called:
1. Open it
2. Apply the same 7-step checklist
3. Note its purpose: (Snapshot/Validation/Accounting/Mutation/Commit)
4. Return to main function

### **Step 4.3: Check Cross-Function Interactions**
Ask:
1. Can this function be called WITH another function in the same transaction?
2. Can state changed by this function affect another function?
3. Are there ordering dependencies?

---

## **Phase 5: Attack Simulation**

### **Step 5.1: Standard Attack Vectors**
For EVERY function, test these:

```markdown
## Reentrancy
- [ ] Function makes external call
- [ ] State is updated AFTER the call
- [ ] Try: call → reenter → exploit

## Frontrunning
- [ ] Function uses `msg.value` or user input
- [ ] Try: see tx in mempool → sandwich it

## Oracle Manipulation
- [ ] Function reads price/timestamp
- [ ] Try: manipulate oracle → profit

## Integer Overflow/Underflow
- [ ] Function does math (+, -, *, /)
- [ ] Try: input max values → check bounds

## Access Control Bypass
- [ ] Function has modifiers
- [ ] Try: call from different address

## Gas Griefing
- [ ] Function has loops or unbounded operations
- [ ] Try: make it run out of gas

## Flash Loan Attack
- [ ] Function checks collateral/health
- [ ] Function reads balances/prices that can change within tx
- [ ] Function assumes balances are "stable" within a block
- [ ] There's a callback that gives attacker control mid-execution

**Flash Loan Attack Spine:**
```text
FLASH LOAN ATTACK TEMPLATE:
├── [BORROW] flashLoan(huge_amount)
│   └── Temporarily gain massive capital (no collateral needed)
├── [MANIPULATE] (within same tx)
│   ├── Inflate collateral value (oracle/pool manipulation)
│   ├── Drain liquidity (sandwich the pool)
│   ├── Manipulate share price (donation attack)
│   └── Exploit price-dependent logic
├── [EXTRACT] (still same tx)
│   ├── Withdraw against inflated position
│   ├── Borrow more than entitled
│   └── Liquidate others unfairly
├── [REPAY] (end of tx)
│   └── Return flash loan + fee
└── [PROFIT]
    └── Keep extracted value minus fees
```

**Flash Loan Sources to Consider:**
- Aave V2/V3 (`flashLoan`, `flashLoanSimple`)
- dYdX (`SoloMargin.operate`)
- Uniswap V2/V3 (`swap` with callback)
- Balancer (`flashLoan`)
- MakerDAO (`flash`)
```

### **Step 5.1b: Known Exploit Pattern Matching**
Before inventing new attacks, check if the code resembles past exploits:

```markdown
## Historical Exploit Database Check
For each function, ask: "Does this pattern resemble a known hack?"

**Price/Oracle Manipulation:**
- [ ] Euler Finance (2023): Donate attack + health factor manipulation
- [ ] Cream Finance (2021): cToken exchange rate manipulation
- [ ] Harvest Finance (2020): Curve pool price manipulation

**Reentrancy Variants:**
- [ ] The DAO (2016): Classic reentrancy
- [ ] Curve (2023): Read-only reentrancy via `raw_call`
- [ ] Lendf.Me (2020): ERC777 hooks reentrancy

**Access Control / Initialization:**
- [ ] Nomad Bridge (2022): Uninitialized trusted root
- [ ] Wormhole (2022): Signature verification bypass
- [ ] Ronin Bridge (2022): Insufficient validator threshold
- [ ] Parity Wallet (2017): Unprotected `initWallet`

**Logic/Math Errors:**
- [ ] Compound (2021): Incorrect reward distribution
- [ ] Cover Protocol (2020): Infinite mint via shield mining
- [ ] YAM Finance (2020): Rebase calculation error

**Flash Loan Specific:**
- [ ] bZx (2020): Oracle manipulation via Uniswap
- [ ] PancakeBunny (2021): Price manipulation + reward claim
- [ ] Rari/Fei (2022): Comptroller reentrancy
```

**Mental Check:** "Have I seen this exact pattern get exploited before?"

---

### **Step 5.2: Protocol-Specific Attacks**
Based on protocol type:

**DeFi Lending Protocol**:
- [ ] Borrow without collateral
- [ ] Liquidate unfairly
- [ ] Manipulate interest rates

**DEX/AMM**:
- [ ] Sandwich attacks
- [ ] Impermanent loss exploitation
- [ ] Pool draining

**NFT Marketplace**:
- [ ] Underpriced listings
- [ ] Royalty bypass
- [ ] Fake collections

**Bridge**:
- [ ] Fake deposits
- [ ] Double spending
- [ ] Validation bypass

**Staking/Farming**:
- [ ] Reward calculation errors
- [ ] Early/late withdrawal penalties
- [ ] Share price manipulation

### **Step 5.3: Edge Case Testing**
```solidity
// Test with these values:
amount = 0
amount = 1
amount = type(uint256).max
amount = type(uint256).max - 1

address = address(0)
address = address(this)  // contract itself
address = address(0xdead)  // burned address

time = 0
time = block.timestamp - 1  // just before
time = block.timestamp + 1  // just after
```

---

## **Phase 6: Finding Documentation**

### **Step 6.1: Finding Template**
```markdown
# Title: Concise Vulnerability Title

**Severity:** Critical/High/Medium/Low
**Impact:** Fund Theft / Permanent DoS / Griefing / Privilege Escalation
**Likelihood:** High/Medium/Low (How easy to trigger?)
**Affected Components:** Contracts, Files, Function Signatures

---

## Root Cause Category
- [ ] Reentrancy
- [ ] Access Control
- [ ] Oracle Manipulation
- [ ] Integer Overflow/Underflow
- [ ] Logic Error
- [ ] Initialization
- [ ] Storage Collision
- [ ] Signature Replay
- [ ] Other: ___

## Semantic Phase
[SNAPSHOT/ACCOUNTING/VALIDATION/MUTATION/COMMIT]

---

## Invariant Violated
*What specific security rule or expected property of the system is broken?*
Example: "totalSupply must always equal sum of all balances"

---

## Attack Path (Execution Spine)
*High-level step-by-step sequence:*
1. Attacker calls X with parameters Y
2. State Z is read (stale/manipulated)
3. Validation V is bypassed because...
4. Mutation M occurs incorrectly
5. Attacker extracts profit

---

## Detailed Step-by-Step Explanation
*Technical deep-dive of each step with line references*

---

## Validation Checks (MUST ALL PASS)
- [x] **Reachability:** Can this execution path occur on-chain? [proof]
- [x] **State Freshness:** Does attack work with current state? [proof]
- [x] **Execution Closure:** Are all external calls modeled? [proof]
- [x] **Economic Realism:** Is cost/timing feasible? [proof]

---

## Proof of Concept
```solidity
// Concrete exploit code
function testExploit() public {
    // 1. Setup: Initial state
    // 2. Attack: Execute exploit
    // 3. Verify: Assert profit/damage
}
```

---

## Suggested Fix
```solidity
// Code fix with explanation
```

---

## References
- Similar past exploits: [list if any]
- Related audit findings: [links]
- Relevant documentation: [links]
```

### **Step 6.2: Severity Classification**
```markdown
## HIGH (Critical)
- Direct loss of funds (>$100k)
- Protocol insolvency
- Permanent fund lock
- Admin key compromise

## MEDIUM (Significant)
- Theft of yield/profits
- Temporary DoS (>1 hour)
- Governance manipulation
- Partial fund lock

## LOW (Minor)
- Gas inefficiencies
- Missing events
- Typos/comments
- Non-critical edge cases

## INFO (Suggestions)
- Code improvements
- Better documentation
- Gas optimization suggestions
```

---

## **Phase 7: Validation & Verification**

### **Step 7.1: Cross-Check Findings**

1. **Verify** it works with current block conditions
2. **Calculate** maximum possible loss
3. **Check** if it's already known/patched

### **Step 7.2: False Positive Check**
Ask:
1. Is there a modifier/check I missed?
2. Is this protected at a different layer?
3. Does the protocol assume this risk?
4. Is this actually by design?

### **Step 7.3: Impact Assessment**
```markdown
## Exploit Requirements
- **Cost to Exploit**: [Gas fees + upfront capital]
- **Technical Skill**: [Low/Medium/High]
- **Time Window**: [Seconds/Hours/Days/Permanent]
- **Detection Chance**: [Low/Medium/High]

## Worst-Case Scenario
- **Funds at Risk**: $[X]
- **Users Affected**: [Number or percentage]
- **Recovery Possible**: [Yes/No]
- **Mitigations Available**: [List]
```

---

### **Step 7.4: Submission Checklist**
```markdown
- [ ] Report is clear and concise
- [ ] Impact is properly calculated
- [ ] Fix is suggested
- [ ] No duplicate of known issues
- [ ] Follows program rules
- [ ] Contact info included
- [ ] Disclosure preferences stated
```

---

### **Universal Red Flags**
```solidity
// RED FLAG 1: External call before state update
otherContract.call();  // DANGER
balances[msg.sender] -= amount;  // Should be first

// RED FLAG 2: Unchecked math
balances[to] += amount;  // Could overflow

// RED FLAG 3: Missing access control
function withdrawAll() external {  // No onlyOwner!
    msg.sender.call{value: address(this).balance}("");
}

// RED FLAG 4: Dangerous delegatecall
address(target).delegatecall(data);  // Can change anything

// RED FLAG 5: Oracle without validation
price = oracle.latestAnswer();  // Could be stale/wrong
```

### **Common Bug Patterns Checklist**
```markdown
## Always Check For:
- [ ] Reentrancy (CEI pattern violation)
- [ ] Integer overflow/underflow
- [ ] Access control bypass
- [ ] Oracle manipulation
- [ ] Frontrunning possibilities
- [ ] Gas griefing attacks
- [ ] Signature replay attacks
- [ ] Upgradeability risks
- [ ] Initialization vulnerabilities
- [ ] ERC20 approval race conditions
```

---

## 🎯 **Final Pro Tips**

1. **Start with the money**: Follow the value flow first
2. **Think like an attacker**: What's the easiest way to steal?
3. **Check boundaries**: 0, 1, max, max-1
4. **Assume everything can be manipulated**: Price, time, order
5. **Sleep on it**: Complex bugs reveal themselves after breaks
6. **Write it down**: If you can't explain it simply, you don't understand it
7. **Stay updated**: New vulnerabilities emerge constantly
