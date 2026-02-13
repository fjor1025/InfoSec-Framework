# Comprehensive Rust Smart Contract Audit Methodology

> **Integration Note:** This file contains the Rust-specific audit methodology.
> For LLM conversation structure, see `Audit_Assistant_Playbook_Rust.md`.
> For the system prompt, see `CommandInstruction-Rust.md`.

---

## **Phase 1: Entry Point Identification & Scope Definition**

### **Step 1.0: Time-Boxing Strategy (For Large Codebases)**
Prevent analysis paralysis with structured time allocation:

```markdown
**Round 1 (40% of time): Quick Triage ALL Entry Points**
- 5 minutes max per function
- Build ownership spine, note red flags, move on
- Goal: Map the attack surface

**Round 2 (40% of time): Deep Dive TOP 5 Priority Functions**
- Full checklist, ownership analysis, attack simulation
- Document findings as you go
- Goal: Find critical vulnerabilities

**Round 3 (20% of time): Cross-Function & Error Paths**
- Interaction bugs between audited functions
- Error path testing, panic analysis
- Goal: Catch composition bugs and state corruption
```

**Time Tracking Template:**
```markdown
| Phase | Allocated | Actual | Functions Covered |
|-------|-----------|--------|-------------------|
| Triage | 4 hours | _ | execute, instantiate, query, ... |
| Deep Dive | 4 hours | _ | transfer, withdraw, stake, ... |
| Cross-Function | 2 hours | _ | withdraw+unstake interaction |
```

---

### **Step 1.1: Identify Audit Root Functions**
Find **all functions** that satisfy **≥2** of these Rust-specific criteria:

- [ ] `pub fn` (public visibility)
- [ ] Takes `&mut self` or `&mut State`
- [ ] Accepts user input / messages / requests
- [ ] Calls ≥2 internal functions
- [ ] Touches storage / DB / cache / memory arena
- [ ] Returns `Result<T, E>` or `Option<T>`
- [ ] Uses `#[entry_point]` or similar macros (blockchain-specific)

**Command to generate list:**
```bash
# Find ALL public mutable functions
grep -rn "pub fn\|pub(crate) fn" src/ | grep -v "test\|#\[cfg(test" | head -50

# Find functions taking &mut self (state-changing)
grep -rn "&mut self\|&mut deps\|DepsMut" src/ | grep "pub fn" | head -30

# Find blockchain entry points — CosmWasm
grep -rn "#\[entry_point\]" src/
grep -rn "pub fn instantiate\|pub fn execute\|pub fn query\|pub fn migrate\|pub fn reply\|pub fn sudo" src/

# Find blockchain entry points — Solana/Anchor
grep -rn "#\[program\]\|#\[access_control\]" src/
grep -rn "pub fn\|handler\|processor" src/ | grep -i "instruction\|process\|handler"

# Find blockchain entry points — Substrate
grep -rn "#\[pallet::call\]\|#\[pallet::hooks\]" src/
grep -rn "pub fn.*origin" src/ | grep -v test

# Find functions that move funds
grep -rn "transfer\|send\|withdraw\|deposit\|mint\|burn\|stake\|unstake\|swap\|claim\|distribute" src/ | grep "pub fn"

# Find admin/privileged functions
grep -rn "admin\|owner\|authority\|governance\|migrate\|upgrade\|pause\|unpause\|set_config\|update_config" src/ | grep "pub fn"

# Find external calls (cross-contract)
grep -rn "WasmMsg\|SubMsg\|invoke\|invoke_signed\|CpiContext\|T::Currency" src/

# Find .unwrap() and .expect() — potential panic points
grep -rn "\.unwrap()\|\.expect(" src/ | grep -v test | grep -v "// safe"

# Find unchecked arithmetic
grep -rn "[^_]+ [0-9]\|[^_]- [0-9]\|[^_]\* [0-9]\|[^_]/ [0-9]" src/ | grep -v "checked_\|saturating_\|test"

# Find unsafe blocks
grep -rn "unsafe" src/ | grep -v test
```

### **Step 1.2: Quick Protocol Understanding**
```markdown
## Rust-Specific Protocol Context

**Framework**: [CosmWasm/Substrate/Solana/Neon/SVM/Other]
**Storage Model**: [KV Store/DB/In-Memory/Persistent]
**Error Handling**: [Result/Option/panic!/Custom errors]
**State Management**: [Immutable/Arc<Mutex>/Rc<RefCell>]
**External Dependencies**: [Crates, FFI, System calls]

**Key Contracts/Modules**:
- `contract.rs`: [Main execution logic]
- `state.rs`: [State definitions and storage]
- `msg.rs`: [Message types and validation]
- `error.rs`: [Error types and handling]

**Concurrency Model**:
- [ ] Single-threaded (blockchain typical)
- [ ] Multi-threaded (if using async/threads)
- [ ] Reentrancy possibilities
```

### **Step 1.3: Prioritization Matrix (Rust Edition)**
```markdown
## Priority 1 (Attack Immediately)
- [ ] Functions that move funds (transfer, withdraw, send)
- [ ] Functions with admin powers (update_config, migrate, upgrade)
- [ ] Functions with external calls (IBC, cross-contract)
- [ ] Functions that mint/burn tokens
- [ ] Functions with `unsafe` blocks

## Priority 2 (Attack After)
- [ ] Query functions that could leak sensitive data
- [ ] Internal functions with pub visibility
- [ ] Functions with time dependencies (env.block.time)
- [ ] Functions using `.unwrap()` or `.expect()`

## Priority 3 (Check Later)
- [ ] Gas optimization opportunities
- [ ] Event emission issues
- [ ] Code style / clippy warnings
```

### **Step 1.4: Mandatory Validation Checks**
_Per methodology — ALL must pass before reporting a finding_

| Check | Question | Rust-Specific Considerations |
|-------|----------|------------------------------|
| **Reachability** | Can this path execute on-chain? | Is function `pub`? Is entry point macro present? |
| **State Freshness** | Works with current state? | Are we testing with realistic storage state? |
| **Execution Closure** | All external calls modeled? | IBC callbacks, cross-contract calls, reply handlers |
| **Economic Realism** | Cost/timing feasible? | Gas costs, block time constraints, capital requirements |

---

## **Phase 2: Build Execution Spine with Rust Context**

### **Step 2.1: Extract Call Graph with Ownership Analysis**
```rust
// Instead of just mapping calls, track ownership changes
pub fn execute(&mut self, msg: ExecuteMsg) -> Result<Response, ContractError> {
    // &mut self → we can mutate state
    let state = self.load_state()?;            // Returns owned or ref
    self.validate(&state, &msg)?;               // & borrow
    let new_state = self.process(state, msg)?;  // Takes ownership
    self.commit(new_state)?;                    // Takes ownership
    Ok(Response::new())
}
```

### **Step 2.2: Format Spine with Ownership Annotations**
```text
EXECUTE(&mut self, ExecuteMsg)
├── [SNAPSHOT] load_state() → State (owned)
│   ├── storage::load() → State (owned)
│   └── State::from() → State (owned)
├── [VALIDATION] validate(&State, &ExecuteMsg) → Result<(), Error>
│   ├── check_permissions() → bool
│   └── validate_input() → Result<(), Error>
├── [MUTATION] process(State, ExecuteMsg) → Result<State, Error>
│   ├── apply_changes() → State
│   └── compute_fees() → Coin
└── [COMMIT] commit(State) → Result<(), Error>
    ├── storage::save() → ()
    └── emit_events() → ()
```

### **Step 2.3: Identify Critical Control Flow**
Mark Rust-specific patterns:

```text
EXECUTE()
├── match msg { ... } → Multiple arms
├── ? operator → Early returns on error
├── .unwrap() / .expect() → Potential panics
├── .map_err() → Error conversion
├── for loop / iterators → Gas considerations
└── async/.await → Concurrency risks
```

---

## **Phase 3: Rust-Specific Semantic Classification**

### **Classification Table with Rust Patterns**
| Intent Tag | Rust Indicators | Questions to Ask |
|------------|-----------------|------------------|
| **SNAPSHOT** | `&self`, `load`, `get`, `read`, `clone`, `copy`, `deserialize` | • Are we cloning too much?<br>• Is data being read atomically?<br>• Are we using the right borrow? |
| **VALIDATION** | `ensure!`, `assert!`, `require!`, `?`, `match` with error arms, `Result` checking | • Can validation be bypassed?<br>• Are all error paths covered?<br>• Do we panic anywhere? |
| **ACCOUNTING** | `env.block.*`, `env.time`, `deps.api.*`, clock reads, fee calculations | • Can time be manipulated?<br>• Are there rounding errors?<br>• Are accumulators safe? |
| **MUTATION** | `&mut self`, `insert`, `update`, `modify`, arithmetic ops, state changes | • Is value conserved?<br>• Are there overflow risks?<br>• Are changes atomic? |
| **COMMIT** | `save`, `store`, `set`, serialization, event emission, response building | • Are all changes persisted?<br>• Are events emitted correctly?<br>• Is response complete? |
| **ERROR HANDLING** | `Result`, `Option`, `unwrap`, `expect`, `map_err`, custom error types | • Can errors leave state corrupted?<br>• Are errors informative?<br>• Do we handle all cases? |

---

## **Phase 4: Semantic Order Audit (Rust Edition)**

### **Pass 1: Snapshot Phase - All SNAPSHOT functions**
```markdown
### Rust-Specific Checklist - Snapshot Phase
- [ ] **Ownership**: Are we cloning unnecessarily?
- [ ] **Borrowing**: Are we using `&` vs `&mut` correctly?
- [ ] **Gas Costs**: Are reads from storage optimized?
- [ ] **Atomicity**: Are related reads done together?
- [ ] **Deserialization**: Is data validated during load?

### Questions:
1. Could data change between read and use? (TOCTOU)
2. Are we deserializing untrusted data safely?
3. Is there any `unsafe` code in snapshot?
4. Are we reading the correct storage key?
```

### **Pass 2: Validation Phase - All VALIDATION functions**
```markdown
### Rust-Specific Checklist - Validation Phase
- [ ] **Error Coverage**: Are all error cases handled?
- [ ] **Panic Safety**: Any `.unwrap()` or `.expect()`?
- [ ] **Match Exhaustiveness**: Are all enum variants covered?
- [ ] **Input Validation**: Are all user inputs validated?
- [ ] **Gas Considerations**: Could validation be DoS'd?

### Questions:
1. Can an attacker trigger a panic?
2. Are there missing checks for edge cases?
3. Does validation happen before state mutation?
4. Are error messages informative but not leaking?
```

### **Pass 3: Accounting Phase - All ACCOUNTING functions**
```markdown
### Rust-Specific Checklist - Accounting Phase
- [ ] **Time Manipulation**: Can `env.block.time` be trusted?
- [ ] **Integer Safety**: Are we using `checked_*` methods?
- [ ] **Precision**: Are decimal calculations safe?
- [ ] **External Data**: Are oracle reads validated?
- [ ] **Fee Calculation**: Are fees computed correctly?

### Questions:
1. Could timestamp manipulation cause issues?
2. Are there overflow/underflow risks?
3. Are decimal calculations using safe libraries?
4. Can accounting be triggered multiple times?
```

### **Pass 4: Mutation Phase - All MUTATION functions**
```markdown
### Rust-Specific Checklist - Mutation Phase
- [ ] **Ownership**: Are we taking ownership correctly?
- [ ] **Value Conservation**: Is total value preserved?
- [ ] **Arithmetic Safety**: Using `checked_add`, `saturating_*`?
- [ ] **State Consistency**: Are all related fields updated?
- [ ] **Gas Optimization**: Are we batching writes?

### Questions:
1. Could a panic leave state partially updated?
2. Are there rounding errors in calculations?
3. Does mutation respect all invariants?
4. Are we using the most efficient data structures?
```

### **Pass 5: Commit Phase - All COMMIT functions**
```markdown
### Rust-Specific Checklist - Commit Phase
- [ ] **Storage Safety**: Are writes atomic where needed?
- [ ] **Event Emission**: Are all events emitted?
- [ ] **Response Building**: Is response complete?
- [ ] **Gas Costs**: Are there unbounded writes?
- [ ] **Serialization**: Is data serialized correctly?

### Questions:
1. Could a storage failure leave state inconsistent?
2. Are events emitted after state changes?
3. Is the response message correct?
4. Are we using optimal serialization format?
```

### **Pass 6: Error Handling Phase - All ERROR paths**
```markdown
### Rust-Specific Checklist - Error Handling
- [ ] **Error Recovery**: Can errors be recovered from?
- [ ] **State Cleanup**: Is state cleaned on error?
- [ ] **Error Messages**: Are they safe (no secrets)?
- [ ] **Error Types**: Are they meaningful?
- [ ] **Panic Boundaries**: Where can panics occur?

### Questions:
1. Do errors leave temporary state uncleaned?
2. Can errors leak sensitive information?
3. Are custom error types used appropriately?
4. Is there any unwrap/expect in production code?
```

---

## **Phase 5: State Mutation Tracking with Ownership**

### **State Mutation Table with Rust Types**
```markdown
| Variable | Type | Snapshot (Borrow) | Validation | Mutation (Ownership) | Commit | Error Cleanup |
|----------|------|-------------------|------------|---------------------|--------|---------------|
| balances | BTreeMap | &self.balances | checks bounds | self.balances.insert() | storage::save() | removed on error? |
| total_supply | Uint128 | self.total_supply | ensure(<=max) | self.total_supply += amount | saved | rolled back? |
| config | Config | &self.config | validate() | self.config.update() | saved | ✅ |
| pending | Vec<Pending> | &self.pending | check_permissions() | self.pending.push() | saved | ❌ (stuck!) |
```

### **Ownership Flow Analysis**
For each state transition, track ownership changes:

```rust
// Example analysis:
fn process(&mut self, msg: Msg) -> Result<(), Error> {
    let item = self.load_item()?;           // Ownership: self → item (owned)
    self.validate(&item)?;                  // Borrow: &item
    let updated = self.modify(item, msg)?;  // Takes ownership: item → updated
    self.save(updated)?;                    // Takes ownership: updated → storage
    Ok(())
}
// Ownership chain: self → item → updated → storage
```

### **Borrow Checker Violation Detection**
Look for these patterns:
1. **Mutable aliasing**: `&mut self` while also holding `&self.some_field`
2. **Moving while borrowed**: Moving data that's still borrowed
3. **Partial moves**: Moving part of a struct while using another part
4. **Drop order issues**: Resources freed in wrong order

---

## **Phase 6: Rust-Specific Attack Simulation**

### **Step 6.1: Memory & Concurrency Attacks**
```markdown
## Memory Safety Attacks
- [ ] **Buffer Overflow**: Vec/array indexing without bounds check
- [ ] **Use-After-Free**: References kept after data moved/dropped
- [ ] **Double Free**: Multiple owners trying to free same resource
- [ ] **Iterator Invalidation**: Modifying collection while iterating

## Concurrency Attacks (if async/multi-threaded)
- [ ] **Race Conditions**: Multiple threads accessing same data
- [ ] **Deadlocks**: Mutex locking order issues
- [ ] **Data Races**: Unsafe code allowing simultaneous mutable access
- [ ] **Reentrancy**: Async callbacks modifying state

## Blockchain-Specific Attacks
- [ ] **Frontrunning**: Transaction ordering manipulation
- [ ] **MEV Extraction**: Sandwich attacks, etc.
- [ ] **Gas Griefing**: Making calls expensive for others
- [ ] **Storage Bloat**: Filling storage to increase costs
```

### **Step 6.1b: Known Rust/Blockchain Exploit Pattern Matching**
Before inventing new attacks, check if the code resembles past exploits:

```markdown
## Historical Exploit Database - Rust Smart Contracts

**CosmWasm Exploits:**
- [ ] **Astroport (2023)**: Integer overflow in LP token calculation
- [ ] **Mars Protocol (2022)**: Incorrect decimal handling in oracle
- [ ] **Anchor Protocol (2022)**: bLUNA/LUNA exchange rate manipulation
- [ ] **Mirror Protocol (2021)**: Oracle staleness not checked
- [ ] **TerraSwap**: Slippage tolerance bypass

**Solana Exploits:**
- [ ] **Wormhole (2022)**: Signature verification bypass (secp256k1)
- [ ] **Cashio (2022)**: Missing signer validation on mint
- [ ] **Slope Wallet (2022)**: Private key exposure via logging
- [ ] **Mango Markets (2022)**: Oracle manipulation + self-liquidation
- [ ] **Crema Finance (2022)**: Flash loan + price manipulation

**Substrate/Polkadot Exploits:**
- [ ] **Acala (2022)**: aUSD mint bug via misconfigured honzon
- [ ] **Moonbeam XCM**: Cross-chain message validation issues
- [ ] **Parallel Finance**: Collateral ratio manipulation

**General Rust/Memory Exploits:**
- [ ] **Panic-based DoS**: Triggering unwrap/expect in production
- [ ] **Integer overflow**: Unchecked arithmetic operations
- [ ] **Serialization attacks**: Malformed Borsh/JSON input
- [ ] **Type confusion**: Incorrect type casting with unsafe

**Cross-Contract/IBC Exploits:**
- [ ] **IBC replay attacks**: Message nonce/sequence issues
- [ ] **Callback reentrancy**: State modified during callback
- [ ] **Cross-chain oracle manipulation**: Stale prices across chains
```

**Mental Check:** "Have I seen this exact pattern get exploited before?"

### **Step 6.1c: Framework-Specific Attack Vectors**
Based on the target framework:

**CosmWasm:**
- [ ] IBC packet spoofing/replay
- [ ] Reply handler reentrancy
- [ ] Submessage failure handling
- [ ] Migrate function access control
- [ ] Query vs Execute state visibility

**Solana (Anchor) - Enhanced with ClaudeSkills Patterns:**
- [ ] Account validation bypass
- [ ] PDA seed collision
- [ ] CPI privilege escalation
- [ ] Rent-exempt balance manipulation
- [ ] Signer authority confusion
- [ ] **Arbitrary CPI** (CRITICAL): User-controlled program ID in `invoke()`
- [ ] **Improper PDA Validation** (CRITICAL): Non-canonical bump exploitation
- [ ] **Missing Ownership Check** (HIGH): Deserializing without owner check
- [ ] **Missing Signer Check** (CRITICAL): Authority without `is_signer`
- [ ] **Sysvar Spoofing** (HIGH): Pre-Solana 1.8.1 `load_instruction_at()` issue

**Substrate - Enhanced with ClaudeSkills Patterns:**
- [ ] Extrinsic weight manipulation
- [ ] Storage migration issues
- [ ] **Arithmetic Overflow** (CRITICAL): Primitives wrap in release mode
- [ ] **Don't Panic DoS** (CRITICAL): Array indexing, `unwrap()`, `as` casts
- [ ] **Weights and Fees** (CRITICAL): Zero-weight exploits, unbounded input
- [ ] **Verify First, Write Last** (HIGH): Pre-v0.9.25 storage issues
- [ ] **Unsigned Transaction Validation** (HIGH): `ValidateUnsigned` vulnerabilities
- [ ] Runtime upgrade vulnerabilities
- [ ] Governance manipulation
- [ ] Cross-pallet reentrancy

---

### **Step 6.2: Rust-Specific Edge Case Testing**
For EACH function, test with:

```rust
// Edge values for testing
let zero = 0;
let one = 1;
let max = Uint128::MAX;
let max_minus_one = Uint128::MAX - 1;

// Special addresses
let zero_address = Addr::unchecked("");
let contract_self = env.contract.address;
let admin_address = ADMIN;

// Empty/edge collections
let empty_vec: Vec<u8> = vec![];
let empty_string = "";
let empty_binary = Binary::default();

// Malformed data
let invalid_utf8 = b"\xff\xfe";
let超大_json = "A".repeat(10_000);  // Large input
```

### **Step 6.3: Error Path Testing**
```markdown
## Test Every Error Path
1. **Early Returns**: What happens on `?` early return?
2. **Panic Paths**: Where can `.unwrap()` or `.expect()` panic?
3. **Match Arms**: Are all enum variants handled?
4. **Result Handling**: Are all `Result` variants considered?
5. **Option Handling**: Are `None` cases handled?

## State Corruption Scenarios
- Error after partial state update
- Panic in the middle of multi-step operation
- Out-of-gas during execution
- External call failure
```

### **Step 6.4: Gas Optimization Analysis**
```rust
// Common gas issues in Rust contracts
let issues = vec![
    "Unbounded loops (for item in collection.iter())",
    "Excessive cloning (.clone() in loops)",
    "Inefficient data structures (Vec vs BTreeMap)",
    "Multiple storage writes instead of batching",
    "Deserializing large objects multiple times",
    "String concatenation in loops",
    "Recursive functions without bounds",
];
```

---

## **Phase 7: Finding Documentation (Rust Edition)**

### **Step 7.1: Rust-Specific Finding Template**
```markdown
## [HIGH/MEDIUM/LOW] Rust-Specific Issue

### Description
[What is the bug? Include Rust-specific context]

### Location
- **File**: `src/contract.rs`
- **Function**: `execute()`
- **Lines**: L123-L145
- **Ownership Pattern**: [Borrow/Move/Clone]

### Rust-Specific Details
- **Memory Safety**: [Safe/Unsafe/Borrow violation]
- **Error Handling**: [Panic/Result/Option handling]
- **Concurrency**: [Single-threaded/Potential race]
- **Gas Impact**: [High/Medium/Low]

### Proof of Concept
```rust
#[test]
fn test_exploit() {
    // Setup
    let mut contract = Contract::default();
    
    // Attack
    let msg = Msg::Exploit { /* malicious data */ };
    let result = contract.execute(msg);
    
    // Verification
    assert!(result.is_err());  // Or succeeds unexpectedly
    // Check state corruption
}
```

### Rust-Specific Fix
```rust
// Before (vulnerable)
let data = self.data.unwrap();  // May panic

// After (fixed)
let data = self.data.ok_or(ContractError::DataMissing)?;

// Before (unsafe iteration)
for i in 0..vec.len() {
    vec[i] = new_value;  // No bounds check
}

// After (safe)
if let Some(element) = vec.get_mut(index) {
    *element = new_value;
}
```

---

## **Phase 8: Protocol-Specific Attacks (Rust Edition)**

Based on protocol type, apply targeted attack vectors:

### **DeFi Lending Protocol (CosmWasm/Solana)**
```markdown
- [ ] Borrow without sufficient collateral
- [ ] Liquidate unfairly (oracle manipulation → forced liquidation)
- [ ] Manipulate interest rates via large deposit/withdraw
- [ ] Flash loan → inflate collateral → borrow → repay
- [ ] Share price manipulation (first depositor attack)
- [ ] Decimal precision mismatch between asset types
- [ ] Health factor rounding in attacker's favor
```

### **DEX / AMM**
```markdown
- [ ] Sandwich attacks (frontrun swap → backrun)
- [ ] LP token price manipulation via donation
- [ ] Pool draining via computed swap amounts
- [ ] Slippage tolerance bypass
- [ ] Impermanent loss exploitation via oracle delay
- [ ] Fee calculation rounding (always in protocol's favor?)
- [ ] First LP provider gets disproportionate shares
```

### **Staking / Farming / Rewards**
```markdown
- [ ] Reward calculation overflow/underflow
- [ ] Stake → claim → unstake in same block
- [ ] Reward per share accumulator precision loss
- [ ] Double claiming via reentrancy
- [ ] Staking with zero amount but receiving rewards
- [ ] Unbonding period bypass
- [ ] Reward distribution to zero-stake periods
```

### **Bridge / Cross-Chain**
```markdown
- [ ] Fake deposit proofs (IBC packet spoofing)
- [ ] Double spending across chains
- [ ] Validator set manipulation
- [ ] Nonce/sequence replay attacks
- [ ] Token denomination confusion across chains
- [ ] Message relay delay exploitation
- [ ] Missing finality checks
```

### **NFT / Marketplace**
```markdown
- [ ] Underpriced listings via race condition
- [ ] Royalty bypass patterns
- [ ] Collection verification bypass
- [ ] Auction sniping / griefing
- [ ] Metadata manipulation post-mint
```

### **Governance / DAO**
```markdown
- [ ] Flash-borrow governance tokens → vote → return
- [ ] Proposal execution before timelock expires
- [ ] Quorum manipulation via vote delegation
- [ ] Emergency action without proper authorization
- [ ] Proposal replay after governance migration
```

---

## **Phase 9: Validation & Verification (Rust Edition)**

### **Step 9.1: Cross-Check Findings**

1. **Verify** it works with current/realistic chain conditions
2. **Calculate** maximum possible loss (worst-case scenario)
3. **Check** if it's already known, patched, or documented as accepted risk
4. **Test** with the exact framework version used by the project

### **Step 9.2: False Positive Check (Rust-Specific)**
Ask these questions before reporting:

```markdown
1. Is there a validation/check I missed in a different module/file?
2. Is this protected by the framework automatically?
   - CosmWasm: Does the framework handle this in the entry point wrapper?
   - Solana: Does Anchor's account validation catch this?
   - Substrate: Does the runtime's `ensure_*` or weight system prevent this?
3. Does the Rust type system prevent this at compile time?
4. Is `.unwrap()` actually safe here because the `Option` is always `Some`?
   - Was it previously validated?
   - Is it a constant/configuration that's always set?
5. Is unchecked arithmetic safe because values are bounded elsewhere?
6. Does the protocol assume this risk and document it?
7. Is this by design? (e.g., admin powers, known limitations)
8. Is the panic in a query (not execute) path? (queries can panic safely in some frameworks)
```

### **Step 9.3: Impact Assessment**
```markdown
## Exploit Requirements
- **Cost to Exploit**: [Gas fees + compute units + upfront capital]
- **Technical Skill**: [Low/Medium/High]
- **Time Window**: [Seconds/Hours/Days/Permanent]
- **Detection Chance**: [Low/Medium/High]
- **Prerequisites**: [Specific accounts/roles/state needed]

## Worst-Case Scenario
- **Funds at Risk**: $[X] or [N] tokens
- **Users Affected**: [Number or percentage]
- **Recovery Possible**: [Yes/No/Partial]
- **Mitigations Available**: [Admin intervention/Pause/Upgrade/None]
- **Chain Impact**: [Single contract/Protocol-wide/Chain-wide]
```

### **Step 9.4: Submission Checklist**
```markdown
- [ ] Report is clear and concise
- [ ] Root cause is identified with exact code location
- [ ] Impact is properly calculated with realistic assumptions
- [ ] PoC test compiles and demonstrates the issue
- [ ] Fix is suggested and verified to not break other functionality
- [ ] No duplicate of known issues (checked project's issue tracker)
- [ ] Follows bug bounty program rules and scope
- [ ] Severity matches the program's classification criteria
- [ ] Ownership/borrowing claims are verified
- [ ] Arithmetic claims are verified with edge values
- [ ] Framework-specific mitigations are checked and ruled out
```

---

## **Enhanced One-Page Cheat Sheet for Rust**

```text
┌─────────────────────────────────────────────────────────────────┐
│                  RUST SMART CONTRACT AUDIT                      │
├─────────────────────────────────────────────────────────────────┤
│ 1. FIND ENTRY POINTS:                                           │
│    • pub fn with &mut self                                      │
│    • Entry point macros (#[entry_point], #[pallet::call])       │
│    • User input handling                                        │
│                                                                 │
│ 2. BUILD OWNERSHIP SPINE:                                       │
│    • Track & vs &mut vs owned                                   │
│    • Map data flow through functions                            │
│                                                                 │
│ 3. AUDIT BY PHASE:                                              │
│    • SNAPSHOT: Check borrowing, cloning, gas                    │
│    • VALIDATION: Check error handling, no panics                │
│    • ACCOUNTING: Check time/math safety                         │
│    • MUTATION: Check ownership, value conservation              │
│    • COMMIT: Check persistence, events                          │
│    • ERROR PATHS: Check cleanup, no corruption                  │
│                                                                 │
│ 4. RUST-SPECIFIC CHECKS:                                        │
│    • No .unwrap()/.expect() in production paths                 │
│    • Arithmetic uses checked_* or saturating_*                  │
│    • Bounds checking on all indices                             │
│    • Match exhaustiveness                                       │
│    • Clone only when necessary                                  │
│                                                                 │
│ 5. ATTACK SIMULATION:                                           │
│    • Edge values (0, 1, max, max-1)                            │
│    • Malformed data (invalid UTF-8, 超大 inputs)               │
│    • Error path testing                                         │
│    • Gas DoS via unbounded operations                          │
└─────────────────────────────────────────────────────────────────┘

KEY RUST INSIGHTS:
• Ownership violations → Memory safety issues
• Panics → Denial of Service
• Unchecked arithmetic → Overflow/Underflow
• Unbounded operations → Gas DoS
• Error path gaps → State corruption
```

---

## **Universal Red Flags (Rust Edition)**

```rust
// RED FLAG 1: Unchecked arithmetic
balance + amount  // Could overflow
// FIX: balance.checked_add(amount).ok_or(ContractError::Overflow)?

// RED FLAG 2: Panic in production code
let data = config.unwrap();  // Panics if None
// FIX: let data = config.ok_or(ContractError::ConfigMissing)?;

// RED FLAG 3: Unbounded iteration
for item in items.iter() {  // Could be millions
    process(item)?;
}
// FIX: Add pagination or limits

// RED FLAG 4: Missing access control
pub fn admin_action(&mut self, msg: Msg) -> Result<Response, ContractError> {
    // No sender check!
    self.do_sensitive_action()?;
}
// FIX: ensure!(info.sender == self.admin, ContractError::Unauthorized);

// RED FLAG 5: External call before state update (reentrancy risk)
let response = self.call_external()?;  // External call
self.state.balance -= amount;           // State update AFTER
// FIX: Update state BEFORE external calls

// RED FLAG 6: Unsafe block without justification
unsafe {
    std::ptr::read(ptr)  // Why is this needed?
}
// FIX: Avoid unsafe unless absolutely necessary, document why

// RED FLAG 7: Unchecked deserialization
let msg: ExecuteMsg = from_binary(&data)?;  // No size limit
// FIX: Add size limits, validate structure

// RED FLAG 8: Hardcoded addresses/values
const ADMIN: &str = "cosmos1abc...";  // What if this changes?
// FIX: Store in state, allow migration

// RED FLAG 9: Missing reply handler error handling
#[entry_point]
pub fn reply(deps: DepsMut, _env: Env, msg: Reply) -> Result<Response, ContractError> {
    // Not checking msg.result.is_err()!
}
// FIX: Handle both success and error cases

// RED FLAG 10: Clone in a loop
for item in large_vec.iter() {
    let cloned = item.clone();  // Expensive!
    process(cloned)?;
}
// FIX: Use references or take ownership if possible
```

---

## **Common Bug Patterns Checklist (Rust Edition)**

```markdown
## Always Check For:

### Memory & Ownership
- [ ] Unnecessary cloning (performance + gas)
- [ ] Ownership transferred when borrow would suffice
- [ ] Mutable borrow while immutable borrow exists
- [ ] Use of unsafe without clear justification

### Error Handling
- [ ] `.unwrap()` or `.expect()` in production paths
- [ ] Errors that don't clean up temporary state
- [ ] Missing match arms for Result/Option
- [ ] Error messages leaking sensitive info

### Arithmetic & Math
- [ ] Unchecked arithmetic (+, -, *, /)
- [ ] Integer overflow/underflow
- [ ] Division by zero
- [ ] Rounding errors in financial calculations
- [ ] Decimal precision loss

### Access Control
- [ ] Missing sender validation
- [ ] Admin functions callable by anyone
- [ ] Incorrect permission checks
- [ ] Privilege escalation via callbacks

### State Management
- [ ] Partial state updates on error
- [ ] State corruption via panic
- [ ] Missing atomicity for related updates
- [ ] Storage key collisions

### External Interactions
- [ ] Reentrancy via callbacks/replies
- [ ] Unchecked return values from external calls
- [ ] Missing timeout on cross-chain calls
- [ ] Oracle staleness not validated

### Gas & DoS
- [ ] Unbounded loops
- [ ] Unbounded storage growth
- [ ] Expensive operations in hot paths
- [ ] User-controlled iteration counts

### Serialization
- [ ] Malformed input handling
- [ ] Size limits on deserialized data
- [ ] Type confusion in generic handlers
- [ ] Migration compatibility issues
```

---

## **Invariants Template (Rust Edition)**

For ANY Rust smart contract, these invariants MUST hold:

```rust
// 1. No free money
assert!(total_assets >= total_liabilities);

// 2. No double spending  
assert!(user_balance <= total_supply);

// 3. Ownership consistency
assert!(item.owner == claimed_owner);

// 4. Access controls work
assert!(info.sender == config.admin || has_permission(&info.sender));

// 5. Arithmetic safety
assert!(result <= Uint128::MAX);  // No overflow
assert!(a.checked_sub(b).is_some());  // No underflow

// 6. State consistency (multi-field)
assert!(sum_of_balances == total_tracked);

// 7. No stuck funds
assert!(can_withdraw || has_valid_reason);

// 8. Time monotonicity
assert!(env.block.time >= last_updated_time);
```

---

## **Severity Classification (Rust Edition)**

```markdown
## HIGH (Critical)
- Direct loss of funds (theft, drain)
- Permanent fund lock
- Admin key compromise / privilege escalation
- Protocol insolvency
- Panic causing chain halt (if critical path)

## MEDIUM (Significant)
- Theft of yield/rewards
- Temporary DoS (>1 hour)
- Governance manipulation
- Partial fund lock
- State corruption requiring admin fix
- Gas griefing with significant impact

## LOW (Minor)
- Gas inefficiencies
- Missing events
- Non-critical panics (in optional paths)
- Minor rounding errors (<0.01%)

---

## **Enhanced Detection Patterns (ClaudeSkills Integration)**

> These patterns are sourced from Trail of Bits' building-secure-contracts repository
> and provide specific, actionable code patterns for vulnerability detection.

### **Solana-Specific Detection Patterns**

#### Pattern S1: Arbitrary CPI ⚠️ CRITICAL
**Description**: User-controlled program ID in Cross-Program Invocation enables attackers to redirect calls to malicious programs.

```rust
// VULNERABLE: Program ID from user-provided account
pub fn process(accounts: &[AccountInfo]) -> ProgramResult {
    let target_program = next_account_info(accounts)?;
    invoke(&instruction, account_infos)?;  // target_program.key is user-controlled!
}

// SECURE: Validate program ID
pub fn process(accounts: &[AccountInfo]) -> ProgramResult {
    let target_program = next_account_info(accounts)?;
    if target_program.key != &spl_token::ID {
        return Err(ProgramError::IncorrectProgramId);
    }
    invoke(&instruction, account_infos)?;
}
```
**Tool Detection**: Trail of Bits lint `unchecked-cpi-program-id`

#### Pattern S2: Improper PDA Validation ⚠️ CRITICAL
**Description**: Using `create_program_address()` with user-provided bump allows non-canonical PDA exploitation.

```rust
// VULNERABLE: User provides bump seed
let (pda, _) = Pubkey::create_program_address(
    &[b"vault", user.key.as_ref(), &[user_provided_bump]],  // Attacker controls bump!
    program_id,
)?;

// SECURE: Use find_program_address for canonical bump
let (vault_pda, bump) = Pubkey::find_program_address(
    &[b"vault", user.key.as_ref()],
    program_id,
);
if vault_account.key != &vault_pda {
    return Err(ProgramError::InvalidAccountData);
}
```
**Tool Detection**: Trail of Bits lint `improper-pda-validation`

#### Pattern S3: Missing Ownership Check ⚠️ HIGH
**Description**: Deserializing account data without owner validation allows attacker-controlled fake accounts.

```rust
// VULNERABLE: No owner check before deserialize
let vault: Vault = Vault::try_from_slice(&vault_account.data.borrow())?;
// vault could be fake account with attacker-controlled data!

// SECURE: Validate owner first
if vault_account.owner != program_id {
    return Err(ProgramError::IncorrectProgramId);
}
let vault: Vault = Vault::try_from_slice(&vault_account.data.borrow())?;

// ANCHOR: Use Account<'info, T> for automatic validation
#[derive(Accounts)]
pub struct Withdraw<'info> {
    #[account(mut)]
    pub vault: Account<'info, VaultAccount>,  // Anchor checks owner
}
```
**Tool Detection**: Trail of Bits lint `missing-ownership-check`

#### Pattern S4: Missing Signer Check ⚠️ CRITICAL
**Description**: Authority operations without `is_signer` validation allow unauthorized access.

```rust
// VULNERABLE: Authority check without signer validation
if vault_data.authority != *authority.key {
    return Err(ProgramError::InvalidAccountData);
}
// Attacker can provide any authority key without signing!

// SECURE: Check is_signer first
if !authority.is_signer {
    return Err(ProgramError::MissingRequiredSignature);
}
if vault_data.authority != *authority.key {
    return Err(ProgramError::InvalidAccountData);
}

// ANCHOR: Use Signer<'info> type
#[derive(Accounts)]
pub struct Withdraw<'info> {
    #[account(mut, has_one = authority)]
    pub vault: Account<'info, VaultAccount>,
    pub authority: Signer<'info>,  // Anchor validates is_signer
}
```
**Tool Detection**: Trail of Bits lint `missing-signer-check`

---

### **Substrate-Specific Detection Patterns**

#### Pattern SUB1: Arithmetic Overflow ⚠️ CRITICAL
**Description**: Rust primitive types wrap in release mode, enabling overflow attacks.

```rust
// VULNERABLE: Primitive arithmetic wraps
let balance: u128 = 100;
let result = balance + amount;  // Wraps on overflow in release!

// SECURE: Use checked/saturating operations
let result = balance.checked_add(amount)
    .ok_or(Error::<T>::Overflow)?;
// OR
let result = balance.saturating_add(amount);

// SAFE METHODS:
// checked_add/sub/mul/div → Returns Option<T>
// saturating_add/sub/mul → Caps at MIN/MAX
// overflowing_add/sub/mul → Returns (T, bool)
```

#### Pattern SUB2: Don't Panic (DoS) ⚠️ CRITICAL
**Description**: Panics in runtime halt the entire blockchain.

```rust
// VULNERABLE: Can panic
let value = array[index];           // Out of bounds panic
let data = result.unwrap();          // Panic on None/Err
let val = option.expect("msg");      // Panic on None
let small: u32 = big as u32;         // Silent truncation, may panic

// SECURE: Handle errors gracefully
let value = array.get(index)
    .ok_or(Error::<T>::IndexOutOfBounds)?;
let data = result
    .map_err(|_| Error::<T>::InvalidData)?;
let small: u32 = big.try_into()
    .map_err(|_| Error::<T>::ValueTooLarge)?;
ensure!(denominator != 0, Error::<T>::DivisionByZero);
```

#### Pattern SUB3: Weights and Fees ⚠️ CRITICAL
**Description**: Incorrect weight functions allow cheap DoS attacks.

```rust
// VULNERABLE: Fixed weight for variable-cost operation
#[pallet::weight(10_000)]  // Same cost for 1 or 1000 items!
pub fn process_items(origin: OriginFor<T>, items: Vec<Item>) -> DispatchResult {
    for item in items { /* expensive */ }
}

// VULNERABLE: Zero weight
#[pallet::weight(0)]  // FREE expensive operation!
pub fn compute(origin: OriginFor<T>) -> DispatchResult { /* expensive */ }

// SECURE: Weight proportional to input with bounds
#[pallet::weight({
    let bounded = items.len().min(T::MaxItems::get() as usize);
    T::DbWeight::get().reads_writes(bounded as u64, bounded as u64)
})]
pub fn process_items(origin: OriginFor<T>, items: Vec<Item>) -> DispatchResult {
    ensure!(items.len() <= T::MaxItems::get() as usize, Error::<T>::TooManyItems);
    for item in items { /* ... */ }
}
```

#### Pattern SUB4: Verify First, Write Last ⚠️ HIGH
**Description**: Storage writes before validation persist on error (pre-v0.9.25).

```rust
// VULNERABLE: Write before validation
pub fn claim(origin: OriginFor<T>) -> DispatchResult {
    <ClaimCount<T>>::mutate(|c| *c += 1);  // Writes first!
    
    let reward = Self::calculate_reward()?;
    ensure!(reward > 0, Error::<T>::NoReward);  // If fails, count still incremented
    Self::transfer(reward)?;
}

// SECURE: Validate first, write last
pub fn claim(origin: OriginFor<T>) -> DispatchResult {
    // ALL VALIDATION
    let reward = Self::calculate_reward()?;
    ensure!(reward > 0, Error::<T>::NoReward);
    
    // THEN ALL WRITES
    <ClaimCount<T>>::mutate(|c| *c += 1);
    Self::transfer(reward)?;
    
    // FINALLY EVENTS
    Self::deposit_event(Event::Claimed { reward });
}
```
- Code style issues

## INFO (Suggestions)
- Code improvements
- Better documentation
- Clippy warnings
- Test coverage gaps
```

---

## 🎯 **Final Pro Tips (Rust Edition)**

1. **Start with the money**: Follow the value flow first — deposits, withdrawals, transfers, minting, burning
2. **Think like a Rustacean attacker**: What inputs cause panics? What arithmetic overflows? What ownership violations?
3. **Check boundaries**: 0, 1, `Uint128::MAX`, `Uint128::MAX - 1`, empty strings, empty vecs
4. **Assume everything can be manipulated**: Price, time, message ordering, account data
5. **Follow the `?` operator**: Every `?` is a potential exit point — what state was partially modified?
6. **Read `Cargo.toml` first**: Know the framework version, dependencies, and feature flags
7. **Grep before you think**: `grep -rn "unwrap\|expect\|unsafe\|as u" src/` gives you the danger map in 5 seconds
8. **Compare to the Solidity equivalent**: Most DeFi bugs are logic bugs, not language bugs — the same attack works across chains
9. **Sleep on it**: Complex ownership and lifetime bugs reveal themselves after breaks
10. **Test the error path**: The happy path is tested by devs. The error path after partial state mutation is where bugs hide.

### **Audit Completion Checklist**
```markdown
## Before Submitting ANY Finding:
- [ ] All 4 validation checks pass (Reachability, State Freshness, Execution Closure, Economic Realism)
- [ ] PoC test compiles and runs
- [ ] Fix doesn't break other functionality
- [ ] Not a duplicate of known issues
- [ ] Follows program scope and rules

## Before Closing the Audit:
- [ ] All entry points audited (use the entry point list from Phase 1)
- [ ] All admin functions reviewed for access control
- [ ] All arithmetic operations checked for safety
- [ ] All .unwrap()/.expect() reviewed for panic safety
- [ ] Cross-function interactions tested
- [ ] Error paths traced for state corruption
- [ ] Framework-specific checklist completed
- [ ] Known exploit patterns checked against codebase
```
