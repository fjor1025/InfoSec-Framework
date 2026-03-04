# Smart Contract Audit Methodology - Manual Workflow

> **Version:** 3.1 — Enhanced with evmresearch.io knowledge graph (300+ notes), CPIMP, Account Abstraction, Transient Storage, L2 Security, 2024–2025 exploit database, and **Pashov Audit Group 170 Attack Vectors**
> **Integration Note:** This file contains the audit *methodology* and heuristics.
> For conversation structure, see `../Audit_Assistant_Playbook.md`.
> For the system prompt, see `CommandInstruction.md`.
> For the 170-vector parallelized scan, see `pashov-skills/README.md`.

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
- Tokens: [ERC20s accepted — check for non-standard behaviors]
- Bridges: [Cross-chain connections]

**Deployment & Upgrade Context**:
- [ ] Proxy pattern used (Transparent/UUPS/Beacon/Diamond)
- [ ] Deployment atomicity (deploy + initialize in one tx? CPIMP risk?)
- [ ] Compiler version and pipeline flags (via-IR? optimizer runs?)
- [ ] Target chain(s) and opcode compatibility (PUSH0, CREATE2, SELFDESTRUCT)

**Account Abstraction Surface**:
- [ ] ERC-4337 integration (EntryPoint, Paymasters, Smart Accounts)
- [ ] EIP-7702 delegation compatibility
- [ ] ERC-7579 modular account hooks
- [ ] tx.origin / msg.sender assumptions that AA invalidates

**Token Integration Profile**:
- [ ] Fee-on-transfer tokens accepted?
- [ ] Rebasing tokens (stETH, aTokens) accepted?
- [ ] Low-decimal tokens (GUSD: 2 decimals) — vault inflation risk?
- [ ] Pausable/blocklist tokens (USDC, USDT) as collateral?
- [ ] Flash-mintable tokens in governance/oracle paths?
- [ ] Upgradeable proxy tokens (USDC, USDT) — future behavior unknown?

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
- [ ] Check all reentrancy variants: classic, cross-function, cross-contract, read-only, callback-based (ERC-777/ERC-1155), AA-reentrancy (ERC-4337/EIP-7702)
- [ ] Verify CEI (Checks-Effects-Interactions) compliance on ALL external call paths
- [ ] Build call graph: trace state changes around every external call
- [ ] EIP-1153 transient storage: values persist across external calls within a transaction — new cross-call reentrancy vector (SIR.trading $355K)
- [ ] Uniswap V4 hooks: arbitrary external code execution during swap paths
- [ ] Account Abstraction reentrancy: EIP-7702 delegated EOAs can execute arbitrary code when called, invalidating isContract() assumptions

## Frontrunning
- [ ] Function uses `msg.value` or user input
- [ ] Try: see tx in mempool → sandwich it

## Oracle Manipulation
- [ ] Function reads price/timestamp
- [ ] Try: manipulate oracle → profit
- [ ] Chainlink min/maxAnswer bounds: stale price returned instead of revert when price exceeds bounds
- [ ] Chainlink L2 sequencer uptime: must check sequencer uptime feed before consuming price data on L2
- [ ] AMM spot prices: manipulable within a single transaction — unsafe as oracles without TWAP
- [ ] Curve get_p() / CLM slot0: manipulable in-block price sources
- [ ] Flash loan + oracle manipulation combo paths (borrow → manipulate → extract → repay)

## Integer Overflow/Underflow
- [ ] Function does math (+, -, *, /)
- [ ] Try: input max values → check bounds

## Access Control Bypass
- [ ] Function has modifiers
- [ ] Try: call from different address
- [ ] Semantic Guard Analysis: Build usage graph of `require`/modifier guards across ALL functions
- [ ] Consistency Principle: If guard X protects function A, does it also protect functions B,C that touch the same state?
- [ ] Flag functions missing pause/access controls that peer functions enforce

## Gas Griefing
- [ ] Function has loops or unbounded operations
- [ ] Try: make it run out of gas
- [ ] Check 63/64 gas rule: can attacker provide just enough gas to execute the call but cause the sub-call to fail silently?
- [ ] Storage bloat: can attacker grow unbounded arrays/mappings at protocol's expense?
- [ ] Forced Ether via `selfdestruct` / `SENDALL` breaking balance invariants
- [ ] EIP-1153 transient storage reaching quadratic memory expansion gas costs
- [ ] Callback reverts in try/catch: gas-sensitive code where sub-call failure changes execution path
- [ ] msg.value in loops: reusing msg.value across iterations of a loop

## Slippage & Deadline Protection
- [ ] Missing slippage parameter on swap/deposit/withdraw operations
- [ ] Using `block.timestamp` as deadline (always passes — provides no protection)
- [ ] Hardcoded slippage tolerance that doesn't adapt to market conditions
- [ ] Missing maximum/minimum output amount checks
- [ ] Partial fill without user consent

## Flash Loan Attack
- [ ] Function checks collateral/health
- [ ] Function reads balances/prices that can change within tx
- [ ] Function assumes balances are "stable" within a block
- [ ] There's a callback that gives attacker control mid-execution
- [ ] ERC-4626 inflation attack: first depositor can inflate share price via direct transfer ("donation attack")
- [ ] Check for flash loan + oracle manipulation combo paths (borrow → manipulate → extract → repay)

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
## Historical Exploit Database Check (2016–2025)
For each function, ask: "Does this pattern resemble a known hack?"

**Price/Oracle Manipulation:**
- [ ] Euler Finance (2023, $197M): Donate attack + health factor manipulation
- [ ] Cream Finance (2021): cToken exchange rate manipulation
- [ ] Harvest Finance (2020): Curve pool price manipulation
- [ ] Mango Markets (2022, $114M): Oracle price manipulation via thin markets
- [ ] yETH (Nov 2025, $9M): AMM math exploitation
- [ ] Bunni (Sep 2025, $8.4M): Composability cascade from Balancer

**Reentrancy Variants:**
- [ ] The DAO (2016): Classic reentrancy
- [ ] Curve (2023, $50-70M): Read-only reentrancy via `raw_call` (Vyper CVE-2023-46247)
- [ ] Lendf.Me (2020): ERC777 hooks reentrancy
- [ ] Fei/Rari (2022, $80M): Comptroller reentrancy
- [ ] dForce (2020, $3.7M): imBTC ERC-777 callback reentrancy
- [ ] SIR.trading (2025, $355K): EIP-1153 transient storage exploitation

**Access Control / Initialization:**
- [ ] Nomad Bridge (2022, $190M): Uninitialized trusted root
- [ ] Wormhole (2022, $320M): Signature verification bypass
- [ ] Ronin Bridge (2022, $625M): Insufficient validator threshold (5/9)
- [ ] Parity Wallet (2017, $280M): Unprotected `initWallet` + library kill
- [ ] WazirX (2024, $230M): Multisig signing infrastructure compromise (DPRK)

**Logic/Math Errors:**
- [ ] Compound (2021): Incorrect reward distribution
- [ ] Cover Protocol (2020): Infinite mint via shield mining
- [ ] YAM Finance (2020): Rebase calculation error
- [ ] Penpie (2024, $27M): Permissionless market added post-audit broke assumptions

**Flash Loan Specific:**
- [ ] bZx (2020): Oracle manipulation via Uniswap
- [ ] PancakeBunny (2021): Price manipulation + reward claim
- [ ] Rari/Fei (2022): Comptroller reentrancy
- [ ] Beanstalk (2022, $182M): Flash loan governance attack

**Supply Chain & Signing Infrastructure (DPRK Attribution):**
- [ ] Bybit (2025, $1.5B): Safe{Wallet} signing UI compromise, blind signing
- [ ] Radiant Capital (2024, $53M): Device compromise → multisig signing manipulation
- [ ] WazirX (2024, $230M): Multisig operational security failure
- [ ] Orbit Chain (2024, $82M): Insider threat / key compromise

**CPIMP (Cross-Proxy Intermediary Malware Pattern):**
- [ ] USPD (Dec 2025, $1M): First documented CPIMP exploitation
- [ ] EtherFi / Pendle / Orderly (Jul 2025 wave): Front-running proxy initialization

**Account Abstraction:**
- [ ] ERC-4337 pack() bug (Mar 2023): Post-signing UserOperation mutation via Yul encoding flaw
- [ ] EIP-7702 delegation phishing (2025, $12M+): Persistent EOA takeover via signed authorization tuple

**Bridge & Cross-Chain:**
- [ ] Ronin (2022, $625M): Validator set compromise (5/9 keys, DPRK-linked)
- [ ] Nomad (2022, $190M): Upgrade introduced verification threshold bug
- [ ] Orbit Chain (2024, $82M): Insider threat

**Governance:**
- [ ] Beanstalk (2022, $182M): Flash loan governance capture
- [ ] Tornado Cash: CREATE2 metamorphic proposal contract substitution

**Compiler:**
- [ ] Curve/Vyper (2023): CVE-2023-46247 reentrancy due to Vyper compiler bug
- [ ] Solidity SOL-2026-1: via-IR transient storage clearing helper collision

**Composability Cascades:**
- [ ] Furucombo (2021, $14M): Proxy authorization delegation exploit
- [ ] SushiSwap (2021, $3.3M): Router approval exploitation
- [ ] Balancer cascade (Nov 2025): Balancer → Euler → Morpho → Lista chain reaction

**Threat Actor Context:**
- DPRK (Lazarus Group): $2.02B stolen = 76% of all 2025 crypto losses
- 65% of 2025 losses from operational/human failures (signing, key management), NOT code bugs
- 40% of total Web3 losses from bridge exploits
```

**Mental Check:** "Have I seen this exact pattern get exploited before?"

---

### **Step 5.2: Protocol-Specific Attacks**
Based on protocol type:

**DeFi Lending Protocol**:
- [ ] Borrow without collateral
- [ ] Liquidate unfairly (11 borrower-liquidator asymmetry patterns)
- [ ] Manipulate interest rates
- [ ] Self-liquidation via flash loan (borrow → trigger own liquidation → profit from bonus)
- [ ] Fixed liquidation bonus revert below threshold (most underwater = unliquidatable)
- [ ] Pause repayments while liquidations active (captive liquidation)
- [ ] No grace period after unpause (instant liquidation race)
- [ ] Front-run liquidators with dust repayments (liquidation DoS)
- [ ] Pausable collateral tokens halting liquidations during price decline → bad debt
- [ ] 100% utilization depositor trapping
- [ ] Liquidation DoS via callback reverts, collateral hiding, data structure corruption

**DEX/AMM**:
- [ ] Sandwich attacks (51.56% of total MEV volume)
- [ ] Cross-chain sandwich (21.4% profit rate vs 0.8% same-chain)
- [ ] Impermanent loss exploitation
- [ ] Pool draining
- [ ] Just-in-time (JIT) liquidity extraction
- [ ] Newton-Raphson AMM solver divergence
- [ ] Tick boundary edge cases in concentrated liquidity (double-counting, fee miscalc)
- [ ] Uniswap V4 hooks — arbitrary code execution in swap paths

**NFT Marketplace**:
- [ ] Underpriced listings
- [ ] Royalty bypass
- [ ] Fake collections

**Bridge**:
- [ ] Fake deposits / message verification bypass
- [ ] Double spending / mint-burn asymmetry
- [ ] Validator set compromise (Ronin pattern)
- [ ] Upgrade-introduced verification bugs (Nomad pattern)
- [ ] ZK proof replay (unbound public inputs)
- [ ] Finality assumption violations
- [ ] Lock-and-mint concentrated target

**Staking/Farming**:
- [ ] Reward calculation errors
- [ ] Early/late withdrawal penalties
- [ ] Share price manipulation (ERC-4626 inflation)

**Governance**:
- [ ] Flash loan voting power acquisition (Beanstalk $182M)
- [ ] CREATE2 metamorphic proposal substitution (Tornado Cash)
- [ ] TimelockController no-expiry queued proposals
- [ ] Emergency function paradox (emergency powers becoming attack vector)
- [ ] Low-participation quorum manipulation

**Liquid Staking / Restaking**:
- [ ] LST depeg → lending protocol liquidation cascades
- [ ] Compounding slashing risk across N AVS services
- [ ] AVS-defined slashing conditions penalizing honest operators

**Stablecoins**:
- [ ] Algorithmic death spiral (reflexive depegging — Terra/UST $60B+)
- [ ] Delta-neutral funding rate inversion (Ethena USDe)
- [ ] Stablecoin trilemma: no design achieves decentralization + stability + capital efficiency

**Perpetual DEXs**:
- [ ] Oracle-based LP toxic flow (GMX-style adverse selection)
- [ ] Funding rate manipulation for economic extraction

**Yield Aggregators**:
- [ ] Strategy composition inherits vulnerabilities from every underlying protocol
- [ ] Composability cascade risk (Balancer Nov 2025 chain reaction)

**RWA (Real World Assets)**:
- [ ] Off-chain legal wrapper failure beyond smart contract reach
- [ ] Recovery agent burn-and-remint capability without multisig+timelock
- [ ] ERC-3643 T-REX identity registry bypass

### **Step 5.2b: Pashov 170-Vector Attack Surface (Parallelized Scan)**

> **Source:** [Pashov Audit Group Skills](https://github.com/pashov/skills) — 170 atomic attack vectors with per-vector FP gates
> **Reference Files:** `pashov-skills/attack-vectors/attack-vectors-{1,2,3,4}.md`
> **Confidence Scoring:** `pashov-skills/finding-validation.md`

Use these 170 vectors as a comprehensive checklist alongside the exploit pattern database above. Each vector includes:
- **D** (Detection): What the vulnerable pattern looks like
- **FP** (False Positive): What makes it NOT a vulnerability

**Vector Groups for Manual Triage:**

```markdown
## Signature & Cryptography (10 vectors)
V1, V21, V27, V37, V51, V127, V138, V157, V161, V170
- Signature malleability, replay, commit-reveal binding, abi.encodePacked collision
- Cross-reference: Step 5.1c (Signature & Replay Analysis)

## ERC Token Standard Edge Cases (28 vectors)
V2, V10-V14, V19, V33, V40, V49-V50, V63-V68, V80-V81, V83-V84, V104, V107, V109, V116, V126, V134, V148
- ERC20/721/1155/4626 rounding, callbacks, approval, burn auth, batch transfer
- Cross-reference: Step 5.1d (External Call Safety), Non-Standard Token Database

## Access Control & Initialization (8 vectors)
V15, V38, V79, V101, V113, V118, V139, V150
- Missing modifiers, delegation privilege escalation, uninitialized takeover
- Cross-reference: Step 5.1 (Access Control Bypass), Step 5.1g (AA)

## Reentrancy Variants (7 vectors)
V12, V52, V60, V83, V105, V153, V156
- Classic, cross-function, cross-contract, read-only, ERC-777, cross-chain
- Cross-reference: Step 5.1 (Reentrancy), SCAN Reentrancy Variants

## Oracle & Price Feed (9 vectors)
V55, V69, V86, V93, V124, V137, V141, V145, V164
- Chainlink staleness/bounds, TWAP manipulation, L2 sequencer, front-running
- Cross-reference: Step 5.1 (Oracle Manipulation), Step 5.1j (L2 Security)

## Flash Loan & MEV (6 vectors)
V3, V86, V90, V125, V131, V144
- Snapshot-based benefits, sandwich, governance flash vote, reward front-run
- Cross-reference: Step 5.1 (Flash Loan Attack)

## Proxy & Upgrades (18 vectors)
V6, V18, V20, V28, V36, V46, V48, V53, V58, V106, V113, V118, V123, V139, V149, V155, V162, V168
- UUPS, Beacon, Diamond, storage collision, CPIMP, metamorphic
- Cross-reference: Step 5.1e (Proxy Safety), Step 5.1h (CPIMP)

## Math & Precision (14 vectors)
V4, V26, V32, V35, V45, V56, V66-V67, V70, V120, V133, V135-V136, V167
- Division-before-multiply, truncation, downcast, inflation attack, off-by-one
- Cross-reference: Step 5.1 (Integer Overflow), Step 5.3 (Edge Cases)

## DoS & Griefing (11 vectors)
V10, V22, V25, V30, V42, V54, V77, V82, V110, V129, V146
- Unbounded loops, push payment revert, return bomb, dust griefing
- Cross-reference: Step 5.1 (Gas Griefing)

## Cross-Chain & LayerZero (18 vectors)
V7, V24, V38-V39, V42, V44, V47, V59, V71, V114, V117, V119, V140, V142-V143, V156, V159-V160
- lzCompose spoofing, DVN diversity, peer validation, rate limits, message library
- Cross-reference: Step 5.1j (L2 & Cross-Chain Security)

## Assembly & Low-Level (12 vectors)
V34, V62, V74, V76, V78, V85, V91-V92, V99, V158, V166, V169
- Scratch space corruption, dirty bits, returndatasize, free memory pointer, calldataload
- Cross-reference: Step 5.1f (Compiler & Bytecode Verification)

## Account Abstraction (5 vectors)
V100, V108, V122, V150, V163
- validateUserOp, paymaster, counterfactual wallet, banned opcodes
- Cross-reference: Step 5.1g (Account Abstraction Security)

## Deployment & Configuration (7 vectors)
V31, V72, V88, V96, V102-V103, V132
- Immutable misconfiguration, nonce gaps, non-atomic bootstrap, hardcoded addresses
- Cross-reference: Step 5.1h (CPIMP), Step 5.1j (L2)
```

**Triage Method:** For each vector group, classify vectors as Skip/Borderline/Survive based on codebase relevance. Only deep-dive surviving vectors. See `pashov-skills/agents/vector-scan-agent.md` for the full triage workflow.

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
- [ ] Reentrancy (classic / cross-function / cross-contract / read-only / callback / AA-reentrancy)
- [ ] Access Control
- [ ] Oracle Manipulation
- [ ] Integer Overflow/Underflow
- [ ] Logic Error (developer assumption gap)
- [ ] Initialization / CPIMP
- [ ] Storage Collision (proxy / EIP-7702 / transient)
- [ ] Signature Replay (same-chain / cross-chain / EIP-7702 / BLS)
- [ ] Account Abstraction (ERC-4337 / EIP-7702 / ERC-7579)
- [ ] Compiler / Bytecode Divergence
- [ ] Token Standard Non-Compliance
- [ ] Liquidation Mechanism Failure
- [ ] Governance / Timelock
- [ ] L2 / Cross-Chain
- [ ] MEV / Transaction Ordering
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

### **Step 6.3: Multi-Layer Severity Matrix**
Cross-reference guard analysis, invariant detection, and specialized vulnerability checks for composite severity:

```markdown
| Guard Status | Invariant Status | Specialized Vuln | Composite Severity |
|-------------|-----------------|-----------------|--------------------|
| Missing guard | Breaks invariant | Additional vuln found | CRITICAL |
| Missing guard | Breaks invariant | No additional | CRITICAL |
| Missing guard | No break | Additional vuln found | HIGH |
| Missing guard | No break | No additional | HIGH |
| Guard present | Breaks invariant | Additional vuln found | HIGH |
| Guard present | Breaks invariant | No additional | HIGH |
| Guard present | No break | Additional vuln found | MEDIUM-HIGH |
| Guard present | No break | No additional | LOW/INFO |
```

**How to use:** For each finding, assess three layers:
1. **Guard layer**: Is the function missing a `require`/modifier that peer functions enforce? (Semantic Guard Analysis)
2. **Invariant layer**: Does the issue break a protocol invariant? (State Invariant Detection)
3. **Vulnerability layer**: Is there an additional exploitable pattern? (Reentrancy, oracle, flash loan, etc.)

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
- [ ] Reentrancy (CEI pattern violation — all 6+ variants)
- [ ] Integer overflow/underflow (unchecked blocks, Yul div-by-zero returns 0)
- [ ] Access control bypass
- [ ] Oracle manipulation (Chainlink min/maxAnswer, AMM spot price, L2 sequencer)
- [ ] Frontrunning possibilities (sandwich, JIT, cross-chain)
- [ ] Gas griefing attacks (63/64 rule, storage bloat, msg.value in loops)
- [ ] Signature replay attacks (EIP-712, EIP-7702, BLS, Merkle second-preimage)
- [ ] Upgradeability risks (CPIMP, storage collision, process-layer)
- [ ] Initialization vulnerabilities (constructor skip, re-initialization)
- [ ] ERC20 approval race conditions (approve/Permit2)
- [ ] Account Abstraction surface (ERC-4337, EIP-7702, ERC-7579)
- [ ] Transient storage assumptions (EIP-1153 cross-call persistence)
- [ ] Compiler pipeline divergence (via-IR, optimizer, SOL-2026-1)
- [ ] Slippage/deadline protection (block.timestamp-as-deadline gives no protection)
- [ ] Non-standard token behaviors (fee-on-transfer, rebasing, pausable, low-decimal, flash-mintable)
- [ ] Developer assumption gaps (8 subtypes: step ordering, empty arrays, unchecked returns, unexpected matching, uniqueness, mutual exclusivity, boundedness, sentinel reliability)
- [ ] Governance attacks (flash loan voting, metamorphic proposals)
- [ ] L2/cross-chain (opcode divergence, sequencer, message verification)
- [ ] Liquidation mechanism failures (5 economic + 13 operational failure modes)
```

### **Step 5.1c: Signature & Replay Analysis**
For functions that use off-chain signatures:

```markdown
## Signature Replay Taxonomy
- [ ] **Same-chain replay**: Can a valid signature be reused on the same contract?
- [ ] **Cross-chain replay**: Does the domain separator include `block.chainid`?
- [ ] **Cross-contract replay**: Does the domain include `address(this)`?
- [ ] **Nonce-skipping**: Can nonces be used out of order? Is nonce incremented on failure?
- [ ] **Expired signatures**: Is there a deadline/expiry? Is it enforced?
- [ ] **EIP-712 compliance**: Proper structured data hashing? Domain separator correct?
- [ ] **`ecrecover` safety**: Does it check for `address(0)` return? Malleable signatures (s-value)?
- [ ] **Permit/Permit2**: Are permit signatures properly validated? Front-running risk?
- [ ] **EIP-7702 delegation replay**: Authorization tuples with chainId=0 valid on ALL chains
- [ ] **ERC-4337 cross-wallet replay**: isValidSignature authenticating bytes32 hash without binding to specific account address
- [ ] **BLS rogue-key attacks**: If BLS signatures used, PoP hash function must be domain-separated from signature hash
- [ ] **ECDSA nonce security**: RFC 6979 deterministic nonce generation? Biased-nonce lattice attack risk?
- [ ] **Merkle proof second-preimage**: Double hashing leaves? Leaf hashes structurally distinct from internal nodes?
- [ ] **Blind signing**: Hardware wallet signing UI compromise — device cannot interpret complex multisig transaction semantics (Bybit $1.5B)
```

### **Step 5.1d: External Call Safety**
For ALL external token/contract interactions:

```markdown
## External Call Checklist
- [ ] **Return values checked**: `transfer()`/`transferFrom()` return value? Use SafeERC20?
- [ ] **Fee-on-transfer tokens**: Does accounting assume received == sent amount? Use balance-diff measurement
- [ ] **Rebasing tokens**: Does balance change between reads without transfers? (stETH daily rebase, aTokens)
- [ ] **Non-standard ERC20**: Missing return value (`USDT`/`BNB`/`OMG`), decimals != 18, blocklist tokens
- [ ] **Unsafe approvals**: Using `approve()` without resetting to 0 first (USDT requires)? Infinite approval risk? Consider Permit2 as resolution
- [ ] **Callbacks**: Can token callbacks (ERC-777 `tokensReceived`, ERC-1155 `onReceived`, ERC-721 `onReceived`) be exploited?
- [ ] **Push vs Pull**: Is the protocol pushing funds (can fail) vs letting users pull (safer)?

## Non-Standard Token Behavior Database (65.8% of deployed ERC-20s are non-standard)
- [ ] **Transfer amount fidelity**: 4 mechanisms cause received != specified: fee-on-transfer, max-uint256 reinterpretation, transfer caps, rebasing
- [ ] **cUSDCv3 max-uint256**: Reinterprets max-uint256 as "transfer full balance" — not max amount
- [ ] **Pausable collateral**: USDC/USDT globally pausable — halts liquidations during price decline → bad debt
- [ ] **Blocklist tokens**: USDC/USDT can blocklist addresses — breaks withdrawal, liquidation, transfer
- [ ] **Low-decimal tokens**: GUSD (2 decimals) makes ERC-4626 vault inflation attacks 10^16x cheaper
- [ ] **Flash-mintable tokens**: Temporary supply inflation affects governance weight and totalSupply-based pricing
- [ ] **Upgradeable proxy tokens**: USDC/USDT upgradeability means token behavior can change post-integration
- [ ] **Non-standard permit**: DAI/RAI/GLM permit silently returns on bad signatures (doesn't revert)
- [ ] **ERC-20 approve race**: Structural race condition in allowance adjustment — unfixed in standard
- [ ] **Dual ETH/WETH paths**: Native currency ERC-20 wrappers (Celo/Polygon/zkSync) create double-counting
- [ ] **ERC-20 approval incompatibility**: USDT/BNB/OZ/permit behaviors mutually incompatible — needs token-specific branching or Permit2
- [ ] **ERC-2612 permit phishing**: Off-chain signature approval bypasses wallet warnings ($35M+ exploited)
- [ ] **Rebasing in AMMs**: Cached reserves diverge from actual balances → free arbitrage at predictable timing
```

### **Step 5.1e: Proxy & Upgrade Safety**
For ALL upgradeable/proxy contracts:

```markdown
## Proxy Safety Checklist
- [ ] **Proxy pattern identified**: Transparent / UUPS / Beacon / Diamond (EIP-2535) / Minimal
- [ ] **Storage collisions**: Are storage slots consistent between implementation versions?
- [ ] **Uninitialized implementation**: Can the implementation be initialized directly?
- [ ] **Function selector clashes**: Any selector collisions between proxy admin and implementation?
- [ ] **Unsafe upgrade paths**: Can an upgrade break storage layout or remove critical functions?
- [ ] **`delegatecall` target trust**: Is the target immutable or can it be changed by attacker?
- [ ] **EIP-1967 slots**: Standard admin/implementation/beacon slot locations used?
- [ ] **EIP-7201 namespaced storage**: Structured collision avoidance for upgradeable contracts?
- [ ] **CPIMP risk**: Is proxy deployment + initialization atomic? (see Step 5.1h)
- [ ] **Post-deployment verification**: Read ERC-1967 implementation slot directly (eth_getStorageAt) — event spoofing and block explorer misdirection possible
- [ ] **EIP-6780 SELFDESTRUCT restriction**: Dencun-era change eliminates metamorphic patterns — but NOT on all L2s
- [ ] **Proxy architecture tradeoffs**: Upgrade authority concentration vs selector routing cost vs blast radius scope
- [ ] **Process-layer vulnerability**: Deployment sequencing, upgrade windows, and re-initialization are structurally invisible to code-level analysis
```

### **Step 5.1f: Compiler & Bytecode Verification**
For ALL contracts, verify compiler trust boundary:

```markdown
## Compiler Safety Checklist
- [ ] **Pragma version**: Exact pragma locked? Floating pragma creating deployment risk?
- [ ] **Pipeline flags**: Is via-IR enabled? Different pipeline → different bytecode from same source
- [ ] **SOL-2026-1 check**: If via-IR + transient storage variables, check for clearing helper collision (fixed in 0.8.34)
- [ ] **Optimizer settings**: Optimizer runs count documented? Optimizer can remove "redundant" checks
- [ ] **ABIEncoderV2**: Legacy encoder vs new encoder behavior differences?
- [ ] **Bytecode verification**: Does deployed bytecode match the audited source? (etherscan vs local compilation)
- [ ] **Vyper contracts**: If any Vyper: check compiler version against CVE-2023-46247 (reentrancy), check argument evaluation order (undefined for builtins)
- [ ] **Cross-language specs**: Testing with spec language different from implementation reveals compiler-assumption bugs
```

### **Step 5.1g: Account Abstraction Security (ERC-4337 / EIP-7702 / ERC-7579)**
For ANY contract interacting with smart accounts or AA infrastructure:

```markdown
## ERC-4337 (EntryPoint & Smart Accounts)
- [ ] **EntryPoint singleton trust**: Does protocol interact with EntryPoint? Single point of failure for all AA accounts
- [ ] **Signature validation**: Does smart account return SIG_VALIDATION_FAILED (not revert) on failure? Reverts break bundler simulation
- [ ] **Cross-wallet replay**: Does isValidSignature bind the hash to a specific account address (EIP-712 domain)?
- [ ] **Counterfactual wallet takeover**: Does factory CREATE2 salt depend on owner credentials? If not, attacker can pre-deploy
- [ ] **Paymaster drainage**: Paymasters deferring token collection to postOp — EntryPoint continues when postOp reverts
- [ ] **Gas penalty exploitation**: Can users inflate callGasLimit beyond actual execution cost to drain paymaster deposits?
- [ ] **Transient storage in bundles**: Multi-UserOperation bundles — transient values from one sender persist into subsequent validation
- [ ] **pack() data integrity**: Check for post-signing mutation of UserOperation fields (March 2023 Yul encoding flaw)

## EIP-7702 (Delegated EOAs)
- [ ] **Delegation phishing**: Signed authorization tuple → persistent EOA takeover ($12M+ exploited in 2025)
- [ ] **chainId=0**: Cross-chain amplification — single authorization valid on all chains
- [ ] **Constructor skip**: Delegation doesn't execute constructor — storage uninitialized unless batched
- [ ] **Storage collision on re-delegation**: Migrating between delegate contracts — existing storage NOT cleared
- [ ] **tx.origin invalidation**: tx.origin now returns the delegating EOA, not necessarily a "real" EOA
- [ ] **msg.sender code check**: Delegated EOAs have code (0xef0100 prefix) — breaks isContract() / extcodesize checks
- [ ] **ERC-4337 composability**: Delegated EOAs + bundlers/paymasters = attacker-controlled code at zero cost
- [ ] **Detection**: Only reliable check is reading msg.sender.code[0..2] for 0xef0100 designator bytes

## ERC-7579 (Modular Smart Accounts)
- [ ] **delegatecall modules**: Modules execute in account storage context — unrestricted storage access
- [ ] **Module lock**: Malicious modules can revert on uninstallation → permanently lock account
- [ ] **ERC-7484 registry**: Singleton registry trust — module attestation bypass risks
```

### **Step 5.1h: CPIMP (Cross-Proxy Intermediary Malware Pattern)**
For ALL proxy deployments:

```markdown
## CPIMP Checklist (July 2025 wave — EtherFi, Pendle, Orderly affected)
- [ ] **Deployment atomicity**: Is proxy deployment + initialization done in ONE transaction?
  - SAFE: Passing _data to ERC1967Proxy constructor (atomic deploy+init)
  - UNSAFE: Separate deploy tx → initialize tx (front-runnable window)
- [ ] **Front-running window**: Time between proxy deployment and initialize() call?
- [ ] **Re-initialization**: Can initialize() be called again? Does initializer modifier prevent this?
  - Note: initializer modifier does NOT prevent pre-initialization CPIMP attacks
- [ ] **Post-deployment verification**: Read ERC-1967 implementation storage slot directly (eth_getStorageAt)
  - Block explorer displays and emitted events can be deceived
- [ ] **CREATE2 for circular deps**: If multi-contract system with circular address dependencies, use CREATE2 for atomic deployment
```

### **Step 5.1i: Transient Storage Security (EIP-1153)**
For ANY contract using TSTORE/TLOAD:

```markdown
## Transient Storage Checklist
- [ ] **Cross-call persistence**: Transient values persist across external calls within a transaction — breaks temporary state isolation assumption
- [ ] **Reentrancy lock bypass**: If using transient storage for reentrancy locks, verify they actually prevent re-entry across all call paths
- [ ] **Multi-contract interactions**: Transient state from contract A visible to contract A during callbacks from contract B
- [ ] **ERC-4337 bundle contamination**: In multi-UserOperation bundles, transient values from one sender persist into subsequent sender validation — requires manual cleanup
- [ ] **Compiler bug (SOL-2026-1)**: via-IR pipeline may emit wrong opcode when clearing both persistent and transient variables of the same type (fixed in Solidity 0.8.34)
- [ ] **Composability assumptions**: Protocols assuming TSTORE provides single-call isolation — it doesn't, it's transaction-scoped
```

### **Step 5.1j: L2 & Cross-Chain Security**
For protocols deployed on L2s or across multiple chains:

```markdown
## L2 Security Checklist
- [ ] **Sequencer centralization**: 59.4% of L2 incidents are sequencer disruptions — check for sequencer downtime handling
- [ ] **Sequencer uptime oracle**: On L2, must check Chainlink L2 sequencer uptime feed before consuming price feeds
- [ ] **Opcode divergence**: PUSH0, CREATE/CREATE2, SELFDESTRUCT behave differently across L2s (OpDiffer found 26 bugs in 9 implementations)
- [ ] **EIP-6780 adoption**: SELFDESTRUCT restriction varies by L2 — metamorphic contract patterns still exploitable on some L2s
- [ ] **Upgrade authority**: 86% of L2s allow instant upgrades without user exit windows (L2BEAT Stage 1 vs Stage 2)
- [ ] **DA saturation attacks**: Mismatches between EVM gas costs and ZK proving costs create L2-specific DoS
- [ ] **Forced inclusion bypass**: Sequencer can front-run forced inclusion transactions

## Cross-Chain / Bridge Checklist
- [ ] **Message verification**: #1 vulnerability class in DeFi audits (61 findings in empirical data)
- [ ] **Lock-and-mint architecture**: All locked assets in single source-chain contract = maximum-value target
- [ ] **Mint-burn asymmetry**: Destination minting without verified source-chain locking
- [ ] **Finality assumptions**: Relay before source chain confirms = reorg attack window
- [ ] **ZK bridge proof replay**: Public inputs not bound to transaction-specific parameters
- [ ] **Bridge upgrade vectors**: Upgrade logic can introduce verification threshold bugs (Nomad, Ronin 2024)
- [ ] **Trust boundary divergence**: Different chains have different trust models — composability breaks security assumptions
```

---

---

## **OWASP Smart Contract Top 10 (2025) Coverage Map**

Use this to verify your audit covers all major risk categories:

| OWASP ID | Category | Methodology Coverage | Workflow Section |
|----------|----------|---------------------|------------------|
| SC01 | Access Control | Semantic Guard Analysis, modifier mapping | Step 5.1 (Access Control Bypass) |
| SC02 | Oracle Manipulation | Oracle/price feed attacks | Step 5.1 (Oracle Manipulation), Step 5.1b |
| SC03 | Logic Errors | Behavioral decomposition, semantic phases | Step 4.1 (7-step checklist), Phase 2 (workflow2) |
| SC04 | Input Validation | Edge case testing, bounds checking | Step 5.3, Step 5.1d (External Call Safety) |
| SC05 | Reentrancy | CEI analysis, call graph, all variants | Step 5.1 (Reentrancy), Phase 4 (workflow2) |
| SC06 | Unchecked External Calls | Return value checks, weird ERC20 | Step 5.1d (External Call Safety) |
| SC07 | Flash Loan Attacks | Flash loan spine, ERC-4626 inflation | Step 5.1 (Flash Loan Attack) |
| SC08 | Integer Overflow | Solidity 0.8+ unchecked, unsafe casting | Step 5.1 (Integer Overflow), Step 5.3 |
| SC09 | Insecure Randomness | Block variable predictability | Step 4.1 (External Data - Accounting Phase) |
| SC10 | DoS Attacks | Gas griefing, 63/64 rule, storage bloat | Step 5.1 (Gas Griefing) |

**Extended coverage (beyond OWASP Top 10):**
| Category | Methodology Coverage | Workflow Section |
|----------|---------------------|------------------|
| Proxy/Upgrade Vulnerabilities | Storage collision, uninitialized impl, CPIMP | Step 3.4, Step 5.1e, Step 5.1h |
| Signature Replay Attacks | EIP-712, cross-chain, nonce, permit, EIP-7702, BLS | Step 5.1c |
| Token Integration (Weird ERC20) | Fee-on-transfer, rebasing, blocklist, 20+ non-standard behaviors | Step 5.1d |
| MEV/Frontrunning | Sandwich, JIT liquidity, cross-chain sandwich | Step 5.1 (Frontrunning), Step 5.2 |
| Account Abstraction | ERC-4337, EIP-7702, ERC-7579 | Step 5.1g |
| CPIMP | Cross-Proxy Intermediary Malware Pattern | Step 5.1h |
| Transient Storage | EIP-1153 cross-call persistence, compiler bugs | Step 5.1i |
| Compiler Verification | via-IR, optimizer, pipeline divergence | Step 5.1f |
| L2/Cross-Chain | Sequencer, opcode divergence, bridge security | Step 5.1j |
| Governance | Flash loan voting, metamorphism, timelock | Step 5.2 (Governance) |
| Liquidation Mechanics | 5 failure mechanisms, 13 DoS patterns, self-liquidation | Step 5.2 (DeFi Lending) |
| Slippage & Deadline | Missing protection, block.timestamp-as-deadline | Step 5.1 (Slippage & Deadline) |

---

## **State Invariant Detection Checklist**

For every protocol, systematically check these invariant categories:

```markdown
## Supply & Balance Invariants
- [ ] totalSupply == sum of all individual balances
- [ ] Protocol balance >= sum of all user claims
- [ ] Shares * pricePerShare == expected underlying value
- [ ] Balance invariant: sum of user balances equals total supply (most fundamental DeFi accounting check)

## Conservation Rules
- [ ] No value created from nothing (mint without backing)
- [ ] No value destroyed unaccountably (burn without proper accounting)
- [ ] Fees + distributions + remaining == original amount
- [ ] Complementary function pair symmetry: deposit/withdraw, add/delete mirror ALL state mutations

## Ratio & Relationship Invariants
- [ ] Collateral-to-debt ratio maintained across all operations
- [ ] Exchange rate monotonicity (if expected)
- [ ] Share price cannot be manipulated by small deposits
- [ ] ERC-4626 share-to-asset ratio: first depositor inflation attack check

## Monotonic Counters & Checkpoints
- [ ] Nonces only increase
- [ ] Timestamps only advance
- [ ] Epoch/round counters only increment
- [ ] Accumulated rewards only grow (or have valid decrease reason)

## Synchronized Updates
- [ ] Related state variables updated atomically
- [ ] Cross-contract state remains consistent after operations
- [ ] Index updates don't miss any participants
- [ ] No code path updates A without B when A and B must be synchronized

## State Transition Invariants
- [ ] Valid state transitions explicitly enforced (not relying on implicit ordering)
- [ ] Multi-step operations: each step validates its preconditions
- [ ] No bypass through internal call paths that skip validation

## Universal Vulnerability Kernel (appears in 15+ of 31 DeFi protocol types)
- [ ] Reentrancy protection on all value-moving functions
- [ ] Oracle manipulation resistance
- [ ] Vault share inflation defense
- [ ] Slippage protection
- [ ] Precision loss tracking
- [ ] Access control on privileged operations

## Fuzzing Invariants
- [ ] Calling function X times with value Y == calling it once with value X*Y
- [ ] Handler functions satisfy preconditions (prevent trivial reverts giving fuzzers false confidence)
```

---

## 🎯 **Final Pro Tips**

1. **Start with the money**: Follow the value flow first
2. **Think like an attacker**: What's the easiest way to steal?
3. **Check boundaries**: 0, 1, max, max-1
4. **Assume everything can be manipulated**: Price, time, order
5. **Sleep on it**: Complex bugs reveal themselves after breaks
6. **Write it down**: If you can't explain it simply, you don't understand it
7. **Stay updated**: New vulnerabilities emerge constantly — CPIMP, EIP-7702, transient storage are 2025 additions
8. **Build guard graphs**: Map which functions share state but not guards — the gaps are where bugs hide
9. **Infer invariants from code, not docs**: The code is its own specification — extract what MUST be true, then find where it isn't
10. **Layer your analysis**: Guard consistency × invariant integrity × specialized vuln = composite severity
11. **Specification > code correctness**: 92% of exploited contracts in 2025 passed security reviews — the spec gap is the real enemy
12. **Bug heuristic methodology**: Cross "easy to get wrong" patterns (callbacks, gas-sensitive code, try/catch) with high-impact targets (bridges, liquidation)
13. **Complementary function pairs**: Diff the state mutation sets of inverse functions (deposit/withdraw, add/delete) — asymmetry = bug
14. **X*Y == Σ(Y)**: Calling a function X times with value Y should equal calling it once with value X*Y — violations reveal rounding/accumulation bugs
15. **Audit coverage expires**: Penpie added permissionless markets post-audit; Socket's deployment pipeline bypassed review — assumptions change
16. **65% of losses are operational**: Code-level security addresses at most 35% of the actual incident surface (2025 data)
17. **Combinatorial tool coverage**: Automated tools catch ~60% of exploitable vulns; the remaining 40% requires human expertise in economic modeling and compositional reasoning
