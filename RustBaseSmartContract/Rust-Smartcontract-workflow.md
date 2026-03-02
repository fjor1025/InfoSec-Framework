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

# Find Anchor account validation structs
grep -rn "#\[derive(Accounts)\]" src/
grep -rn "#\[account(" src/ | head -30

# Find Solana account deserialization (type cosplay risk — SVE-1010/1011)
grep -rn "try_from_slice\|try_deserialize\|BorshDeserialize" src/ | grep -v test

# Find CPI calls (arbitrary CPI risk — SVE-1016)
grep -rn "invoke\b\|invoke_signed\b\|CpiContext" src/ | grep -v test

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
- [ ] **Wormhole (2022)**: Signature verification bypass — `secp256k1` program return unchecked [SVE-1001]
- [ ] **Cashio (2022)**: Missing signer + ownership validation on infinite mint [SVE-1001/1002]
- [ ] **Mango Markets (2022)**: Oracle manipulation → self-liquidation (price manipulation + account draining)
- [ ] **Crema Finance (2022)**: Flash loan + tick array price manipulation via CPI
- [ ] **Slope Wallet (2022)**: Private key exposure via Sentry logging (supply-chain, not on-chain)
- [ ] **Jet Protocol v1 (2021)**: Incorrect `break` instead of `continue` in obligation loop [SVE-2001]
- [ ] **Solend (2022)**: Oracle stale price exploitation in liquidation
- [ ] **spl-token-swap**: Incorrect `checked_div` instead of `checked_ceil_div` for fee calculation [SVE-2004]
- [ ] **Raydium (2022)**: Insufficient account validation in AMM swap path
- [ ] **Nirvana Finance (2022)**: Flash loan → fake collateral → unchecked mint

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

**Solana (Anchor) — Comprehensive Patterns (solana-fender + x-ray SVE + OWASP + ClaudeSkills):**

**Category A: Access Control (OWASP #3, SVE-1001)**
- [ ] **Missing Signer Check** (CRITICAL) [SVE-1001, SF-01]: Authority without `is_signer` — use `Signer<'info>`
- [ ] **Unauthorized Access** (HIGH) [SF-01]: `AccountInfo` used for authority/admin fields instead of `Signer<'info>`
- [ ] **Initialization Frontrunning** (MEDIUM) [SF-12]: Global singleton PDAs (static seeds) initializable by anyone

**Category B: Account Validation (OWASP #2, #6, SVE-1002/1007/1019)**
- [ ] **Missing Ownership Check** (HIGH) [SVE-1002, SF-02]: `try_from_slice()` without `.owner == program_id` check
- [ ] **Type Cosplay / Account Confusion** (HIGH) [SVE-1010/1011, SF-03]: Same-layout structs allow type confusion attacks
- [ ] **Account Data Matching** (LOW) [SF-08]: SPL token unpacked without verifying authority matches owner
- [ ] **Account Initialization** (MEDIUM) [SF-09]: No reinitialization guard (`is_initialized` check missing)
- [ ] **Invalid Sysvar Accounts** (HIGH) [SVE-1019, SF-15]: Sysvar not validated against `sysvar::*::ID`
- [ ] **Duplicate Mutable Accounts** (MEDIUM) [SF-07]: Two `Account<'info>` fields with no `key() !=` constraint
- [ ] **Unverified Parsed Account** (HIGH) [SVE-1007]: Account data parsed without key or owner validation

**Category C: CPI Security (OWASP #5, SVE-1016)**
- [ ] **Arbitrary CPI** (CRITICAL) [SVE-1016, SF-04]: User-controlled program ID in `invoke()` / `invoke_signed()`
- [ ] **Account Reloading** (HIGH) [SF-10]: Account used after CPI without `.reload()` — stale data
- [ ] **Reentrancy via CPI** (HIGH) [SF-18]: State updated after `invoke()`/CPI without guard

**Category D: PDA Security (OWASP #6, SVE-1014/1015)**
- [ ] **Improper PDA Validation** (CRITICAL) [SVE-1014, SF-05]: `create_program_address()` with user-supplied bump
- [ ] **PDA Sharing** (MEDIUM) [SVE-1015, SF-16]: Seeds only contain `mint`+`bump` — no user-unique component
- [ ] **Seed Collision** (MEDIUM) [SF-19]: PDA seeds without hardcoded string prefix (`b"prefix"`) across types
- [ ] **Bump Seed Canonicalization** (MEDIUM) [SF-05]: User-provided bump accepted without `find_program_address` validation

**Category E: Arithmetic Safety (OWASP #1, #4, SVE-1003–1006)**
- [ ] **Integer Overflow/Underflow** (MEDIUM) [SVE-1003/1004/1005/1006, SF-14]: Unchecked `+`, `-`, `*`, `/`
- [ ] **Precision Loss** (MEDIUM) [SF-17]: Division before multiplication `(a / b) * c` truncates
- [ ] **Incorrect Division Logic** [SVE-2004]: `checked_div` where `checked_ceil_div` is needed
- [ ] **Incorrect Token Calculation** [SVE-2005]: Using balances instead of reserves in swap math

**Category F: Account Lifecycle**
- [ ] **Closing Accounts** (MEDIUM) [SF-06]: Lamports zeroed without discriminator set + data zeroed → reinitialization
- [ ] **Rent-Exempt Balance** (LOW): Account below rent-exempt threshold may be garbage-collected

**Category G: Transaction Security**
- [ ] **Improper Instruction Introspection** (HIGH) [SF-11]: Hardcoded absolute index in `load_instruction_at_checked()`
- [ ] **Insecure Randomness** (MEDIUM) [SF-13]: Using `Clock::unix_timestamp` / `slot` / `SlotHashes` for randomness
- [ ] **Malicious Simulation** [SVE-1017]: Slot-based comparisons for transaction simulation detection

**Category H: Program Logic (SVE-2001–2005)**
- [ ] **Incorrect Loop Break Logic** [SVE-2001]: `break` instead of `continue` (jet-v1 exploit pattern)
- [ ] **Error Not Handled** (OWASP #7): Error returned from CPI without logging, rollback, or state cleanup

> **Legend**: SVE = sec3 x-ray Solana Vulnerability Enumeration, SF = solana-fender analyzer, OWASP = OWASP Solana Top 10

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

### **Step 6.5: Solana Static Analysis Tooling Integration**

Use these automated tools to supplement manual review. Run them BEFORE manual deep dives (Phase 4) to generate a prioritized signal list.

#### **Tool 1: solana-fender (AST-based, 19 analyzers)**
```bash
# Install and run solana-fender against your Anchor/native program
cargo install solana-fender  # or clone and build locally
solana-fender analyze --path programs/

# Key analyzers to focus on:
# - unauthorized_access (Signer vs AccountInfo)
# - arbitrary_cpi (unchecked program ID in invoke)
# - bump_seed_canonicalization (user-provided bump)
# - closing_accounts (reinitialization after close)
# - account_reloading (stale data after CPI)
# - type_cosplay (discriminator-less Borsh structs)
# - precision_loss (division before multiplication)
# - seed_collision (PDA seeds without static prefix)
```

**solana-fender Detection Map (19 patterns):**
```markdown
| Analyzer            | Category           | Severity | What It Flags |
|---------------------|--------------------|---------|-------------------------------------------------|
| unauthorized_access | Access Control     | High    | AccountInfo for authority fields, no is_signer |
| missing_owner       | Account Validation | Low     | SplTokenAccount::unpack without owner check     |
| type_cosplay        | Account Validation | High    | try_from_slice without discriminator validation  |
| arbitrary_cpi       | CPI Security       | Medium  | invoke/invoke_signed without program ID check   |
| bump_seed_canon     | PDA Security       | Medium  | create_program_address with user bump            |
| closing_accounts    | Account Lifecycle  | Medium  | Close without discriminator + data zero          |
| duplicate_mutable   | Account Validation | Medium  | Two Account fields, no key() != constraint       |
| account_data_match  | Account Validation | Low     | SPL unpack without authority == token.owner       |
| account_init        | Account Lifecycle  | Medium  | Init function without is_initialized check       |
| account_reloading   | CPI Security       | High    | Account used after CPI without .reload()         |
| instruction_intro   | Transaction Sec    | High    | Absolute index in load_instruction_at_checked    |
| init_frontrunning   | Access Control     | Medium  | Static-seed PDA init without authority constraint |
| insecure_randomness | Crypto Security    | Medium  | Clock::unix_timestamp/slot for randomness        |
| integer_overflow    | Arithmetic         | Medium  | Unchecked +, -, *, /                             |
| invalid_sysvar      | Account Validation | Low     | Sysvar used without ID validation                |
| pda_sharing         | PDA Security       | Low     | Seeds with only mint+bump (no user component)    |
| precision_loss      | Arithmetic         | Medium  | (a / b) * c pattern → truncated intermediate     |
| reentrancy          | CPI Security       | High    | CPI call without reentry guard                   |
| seed_collision      | PDA Security       | Medium  | PDA seeds without b"prefix" first element        |
```

#### **Tool 2: x-ray / sec3 (LLVM-IR static analysis, SVE IDs)**
```bash
# x-ray compiles Solana programs to LLVM-IR and runs rule-based detection
# Install: https://github.com/aspect-build/x-ray
x-ray scan --target programs/ --output report.json

# Priority mapping (higher = more critical):
# Priority 11: SVE-1017 (Malicious Simulation)
# Priority 10: SVE-1001 (Missing Signer), SVE-1002 (Missing Owner), SVE-2001 (Break Logic)
# Priority  9: SVE-1007 (Unverified Account), SVE-1014 (Bump Seed), SVE-1016 (Arbitrary CPI)
# Priority  8: SVE-1003/1004 (Add/Sub Overflow), SVE-1019 (Unvalidated Account)
# Priority  6: SVE-1005 (Mul Overflow), SVE-1010 (Full Type Cosplay)
# Priority  5: SVE-1006 (Div Overflow), SVE-1011 (Partial Cosplay), SVE-1015 (PDA Sharing)
```

**x-ray SVE Reference Table:**
```markdown
| SVE ID | Name                     | Priority | Category |
|--------|--------------------------|----------|------------------------------|
| 1001   | MissingSignerCheck       | 10       | Access Control               |
| 1002   | MissingOwnerCheck        | 10       | Account Validation           |
| 1003   | IntegerAddOverflow       | 8        | Arithmetic Safety            |
| 1004   | IntegerUnderflow         | 8        | Arithmetic Safety            |
| 1005   | IntegerMulOverflow       | 6        | Arithmetic Safety            |
| 1006   | IntegerDivOverflow       | 5        | Arithmetic Safety            |
| 1007   | UnverifiedParsedAccount  | 9        | Account Validation           |
| 1010   | TypeFullCosplay          | 6        | Structural Vulnerability     |
| 1011   | TypePartialCosplay       | 5        | Structural Vulnerability     |
| 1014   | BumpSeedNotValidated     | 9        | PDA Security                 |
| 1015   | InsecurePDASharing       | 5        | PDA Security                 |
| 1016   | ArbitraryCPI             | 9        | CPI Security                 |
| 1017   | MaliciousSimulation      | 11       | Transaction Security         |
| 1019   | UnvalidatedAccount       | 8        | Account Validation           |
| 2001   | IncorrectBreakLogic      | 10       | Program Logic (jet-v1)       |
| 2004   | IncorrectDivisionLogic   | 8        | Arithmetic (ceil_div)        |
| 2005   | IncorrectTokenCalculation| 9        | DeFi-Specific Logic          |
```

#### **Tool 3: Manual grep-based rapid signal generation**
```bash
# === SOLANA-SPECIFIC DANGER MAP ===
echo "=== MISSING SIGNER CHECKS ==="
grep -rn "AccountInfo" src/ | grep -i "authority\|admin\|owner\|signer" | grep -v "Signer<"

echo "=== UNCHECKED CPI CALLS ==="
grep -rn "invoke\b\|invoke_signed\b" src/ | grep -v test

echo "=== PDA WITHOUT find_program_address ==="
grep -rn "create_program_address" src/ | grep -v "find_program_address"

echo "=== USER-PROVIDED BUMP SEEDS ==="
grep -rn "fn.*bump.*:" src/ | grep -v test

echo "=== STALE ACCOUNT AFTER CPI ==="
grep -rn "CpiContext::new\|invoke(" src/ | grep -v test
# Then check: is .reload() called after CPI on used accounts?

echo "=== ACCOUNT CLOSE WITHOUT DISCRIMINATOR ==="
grep -rn "try_borrow_mut_lamports\|lamports.*= 0" src/ | grep -v test

echo "=== TYPE COSPLAY RISK (Borsh without discriminator) ==="
grep -rn "try_from_slice\|BorshDeserialize" src/ | grep -v "discriminant\|#\[account\]"

echo "=== DUPLICATE MUTABLE ACCOUNTS ==="
grep -rn "Account<'info" src/ | grep -v test | sort | uniq -c | sort -rn

echo "=== INSECURE RANDOMNESS ==="
grep -rn "unix_timestamp\|slot\(\)\|SlotHashes\|RecentBlockhashes" src/ | grep -v test

echo "=== ABSOLUTE INSTRUCTION INDEX ==="
grep -rn "load_instruction_at_checked\|load_instruction_at(" src/ | grep -v test

echo "=== PRECISION LOSS (div before mul) ==="
grep -rn "checked_div.*checked_mul\|/ .*\*" src/ | grep -v test

echo "=== INIT WITHOUT REINITIALIZATION GUARD ==="
grep -rn "fn.*init\|fn.*create\|fn.*setup" src/ | grep -v "is_initialized\|AccountAlreadyInitialized"

echo "=== SEED COLLISION RISK ==="
grep -rn "seeds = \[" src/ | grep -v "b\"\|\.as_bytes()"
```

#### **OWASP Solana Programs Top 10 Quick Checklist**
Cross-reference findings against OWASP categories:
```markdown
| OWASP # | Category                           | Tool Coverage |
|---------|------------------------------------|-----------------------------|
| 1       | Integer Overflow/Underflow          | x-ray SVE-1003–1006, SF-14 |
| 2       | Missing Account Verification       | x-ray SVE-1002/1007, SF-02 |
| 3       | Missing Signer Check               | x-ray SVE-1001, SF-01      |
| 4       | Arithmetic Accuracy (Precision)    | SF-17, SVE-2004/2005       |
| 5       | Arbitrary Signed Program Invocation| x-ray SVE-1016, SF-04      |
| 6       | Account Confusion / Type Cosplay   | x-ray SVE-1010/1011, SF-03 |
| 7       | Error Not Handled                  | Manual review, SF patterns  |
```

### **Step 6.6: General Rust Safety Tooling (Awesome-Rust-Checker)**

Use these research-grade static analyzers to detect memory safety, concurrency, and unsafe code bugs in ANY Rust codebase — not blockchain-specific. Run them on contracts that use `unsafe`, raw pointers, concurrency primitives, or FFI.

#### **Tool A: Rudra (SOSP 2021, 76 CVEs — Georgia Tech)**
Detects unsound `unsafe` usage patterns via MIR taint analysis and type-level checking.

```bash
# Install (requires specific nightly)
cargo install rudra
# Run on target crate
cargo rudra
```

**Three analysis modules:**

| Module | Bug Class | Severity | What It Finds |
|--------|-----------|----------|---------------|
| **UnsafeDataflow** | Panic safety (double-free, uninitialized mem) | Error–Info | `ptr::read` on non-Copy + generic call, `Vec::set_len(n)` + generic call, `Vec::from_raw_parts` + generic, `transmute` + generic |
| **UnsafeDestructor** | Unsafe code in Drop::drop() | Warning | Non-FFI unsafe function calls inside `impl Drop` bodies |
| **SendSyncVariance** | Incorrect Send/Sync impls on generics | Error–Info | `impl Send for Foo<T>` without `T: Send` bound, `impl Sync` without `T: Sync`, API-behavior analysis for concurrent containers |

**Key patterns Rudra catches:**

```rust
// Pattern R1: Panic Safety — Vec::set_len before init (Error)
unsafe {
    self.vec.set_len(self.vec.len() + to_push.len()); // Extends BEFORE writing
    for (i, x) in to_push.iter().enumerate() {
        ptr.offset(i as isize).write(x.clone());      // clone() can panic → double-free
    }
}
// FIX: Write elements THEN set_len

// Pattern R2: Panic Safety — ptr::read duplicates ownership (Warning)
unsafe { std::ptr::read(&box_val as *const _); }  // Duplicates Box ownership
some_generic_call();                                // If this panics → double-free
// FIX: Use ptr::read only on Copy types, or restructure

// Pattern R3: Unsound Send impl on generic wrapper (Error)
unsafe impl<T> Send for MyWrapper<T> {}  // T is NOT bounded by Send!
// If T contains Rc<Cell<_>>, sending across threads → data race
// FIX: unsafe impl<T: Send> Send for MyWrapper<T> {}

// Pattern R4: Unsafe destructor (Warning)
impl Drop for StrcCtx {
    fn drop(&mut self) {
        unsafe { CString::from_raw(self.ptr as *mut c_char); }  // RUSTSEC-2020-0032
    }
}
// AUDIT: Verify ptr is valid, not double-freed, not aliased
```

**Rudra UnsafeDataflow source classification:**
```markdown
| Source Type | Examples | Severity when + generic call |
|-------------|----------|------------------------------|
| Strong | Vec::from_raw_parts, Vec::set_len(n>0) | Error (High) |
| Strong | ptr::read, intrinsics::copy | Warning (Med) |
| Weak | transmute, ptr::write, ptr::as_ref | Info (Low) |
| Weak | slice::get_unchecked, slice::from_raw_parts | Info (Low) |
```

#### **Tool B: lockbud (TSE'24 — concurrency + memory)**
Detects deadlocks, atomicity violations, use-after-free, invalid free, and panic locations in Rust MIR.

```bash
# Install (requires nightly-2025-10-02)
cargo install lockbud
# Run specific detector
cargo lockbud -k deadlock       # Deadlock detection
cargo lockbud -k memory         # UAF + invalid free
cargo lockbud -k atomicity_violation  # Atomic TOCTOU
cargo lockbud -k panic          # Panic location map
cargo lockbud -k all            # All detectors
```

**Five detectors:**

| Detector | Bug Class | Confidence | Patterns |
|----------|-----------|------------|----------|
| **DoubleLock** | Self-deadlock | Probably/Possibly | Mutex held → same Mutex acquired (intra + inter-procedural) |
| **ConflictLock** | Lock-order inversion | Possibly | Thread A: lock(a)→lock(b), Thread B: lock(b)→lock(a) — cycle detection |
| **CondvarDeadlock** | Condvar misuse | Possibly | Lock held before both `wait` and `notify` on same Condvar |
| **AtomicityViolation** | Atomic TOCTOU | Possibly | `atomic.load()` then control/data-dependent `atomic.store()` without CAS |
| **UseAfterFree** | Raw ptr use after drop | Possibly | Raw ptr → pointee dropped → ptr used/escapes to global/return |
| **InvalidFree** | Drop of uninitialized | Possibly | `mem::uninitialized()` or `MaybeUninit::assume_init()` without prior `.write()` |
| **PanicLocations** | All panic points | Informational | Maps every `unwrap()`, `expect()`, `panic!()`, `assert!()`, `panic_fmt` |

**Supported lock types:** `std::sync::{Mutex,RwLock}`, `parking_lot::{Mutex,RwLock}`, `spin::{Mutex,RwLock}` — 9 guard variants.

```rust
// Pattern LB1: DoubleLock — self-deadlock (Probably)
let guard_a = mutex.lock().unwrap();
match *guard_a {
    State::A => {
        let guard_b = mutex.lock().unwrap();  // DEADLOCK on same mutex!
    }
}

// Pattern LB2: ConflictLock — lock-order inversion (Possibly)
fn thread_1(a: &Mutex<_>, b: &Mutex<_>) {
    let _ga = a.lock(); let _gb = b.lock();  // Order: a → b
}
fn thread_2(a: &Mutex<_>, b: &Mutex<_>) {
    let _gb = b.lock(); let _ga = a.lock();  // Order: b → a — DEADLOCK!
}

// Pattern LB3: Atomic TOCTOU (Possibly)
if counter.load(Ordering::SeqCst) == 0 {      // Read
    counter.store(1, Ordering::SeqCst);        // Write — not atomic RMW!
}
// FIX: counter.compare_exchange(0, 1, ...)

// Pattern LB4: Use-After-Free via raw ptr (Possibly)
let ptr = vec.as_ptr();
drop(vec);              // Pointee freed
unsafe { *ptr };        // UAF!

// Pattern LB5: Invalid free — MaybeUninit without write (Possibly)
let obj: Vec<i32> = unsafe { MaybeUninit::uninit().assume_init() };
// drop(obj) → frees garbage pointer → UB
// FIX: uninit.write(value) before assume_init()
```

#### **Tool C: RAPx — Rust Analysis Platform (SafeDrop + rCanary + Senryx)**
Comprehensive MIR analysis platform with field-sensitive, path-sensitive bug detection. Includes SafeDrop (UAF/DF), rCanary (memory leaks), Senryx (unsafe contract verification), and Opt (performance).

```bash
# Install (requires nightly-2025-12-06)
cargo install rapx
# Run specific analysis
cargo rapx -F          # SafeDrop: UAF, double-free, dangling pointers
cargo rapx -M          # rCanary: memory leak detection (uses Z3)
cargo rapx -V          # Senryx: unsafe API safety verification (uses Z3)
cargo rapx -O          # Opt: performance bug detection
cargo rapx -- -upg     # UPG: unsafety propagation graph (DOT visualization)
```

**Six analysis modules:**

| Module | Flag | Bug Class | Analysis Technique |
|--------|------|-----------|-------------------|
| **SafeDrop** | `-F` | Use-after-free, double-free, dangling ptr | MIR path-sensitive + alias analysis + owned-heap tracking |
| **rCanary** | `-M` | Memory leaks | Ownership-based flow analysis + Z3 constraint solving |
| **Senryx** | `-V` | Unsafe API contract violations | Path-sensitive symbolic execution + Z3, 20+ safety contracts |
| **Opt** | `-O` | Performance bugs | Dataflow pattern matching (6 sub-checkers) |
| **UPG** | `-upg` | Unsafety propagation | HIR/MIR unsafe block + call graph visualization |
| **Alias** | `-alias` | (Core) | Field-sensitive MOP/MFP alias pairs |

**SafeDrop detection patterns:**
```rust
// Pattern RX1: Use-After-Free via ManuallyDrop (Confidence-scored)
let md = ManuallyDrop::new(Box::new(42));
unsafe { ManuallyDrop::drop(&mut md); }
println!("{}", *md);  // UAF — referent already freed

// Pattern RX2: Double-Free via unwinding path
let v = vec![1, 2, 3];
let ptr = v.as_ptr();
drop(v);
unsafe { Vec::from_raw_parts(ptr, 3, 3); }  // Double-free on drop

// Pattern RX3: Dangling pointer — returning ptr to local
fn danger() -> *mut Vec<u8> {
    let mut v = vec![1, 2, 3];
    &mut v as *mut Vec<u8>  // Dangling — v dropped at end of scope
}
```

**Senryx safety property contracts (21 properties):**
```markdown
| Contract | What It Verifies |
|----------|-----------------|
| Align(Ty) | Pointer aligned for type T |
| NonNull | Pointer is non-null |
| Allocated(Ty, len) | Memory allocated for len elements |
| InBound(Ty, len) | Pointer + offset within bounds |
| NonOverlap | Source/dest memory regions don't overlap |
| Init(Ty, len) | Memory is initialized |
| ValidNum(range) | Numeric value within range |
| ValidPtr(Ty, len) | Aligned + allocated + non-null |
| Deref | Safe to dereference |
| Typed(Ty) | Value is valid for declared type |
| Owning | Caller owns the memory |
| Alive | Referent not dropped |
| Alias | No aliasing violation |
| Unwrap | Option/Result is Some/Ok |
```

#### **Tool D: rCanary (Standalone memory leak detector)**
Semi-automated Rust memory leak detector using ownership-based type + flow analysis with Z3.

```bash
# Install
cargo install rlc
# Run on target crate
cargo rlc
```

**Six leak patterns detected:**

| Pattern | Mechanism | Example |
|---------|-----------|---------|
| **Owned Instance** | `ManuallyDrop::new(Box::new(...))` never freed | Escapes OBRM |
| **Owned Pointer** | `Box::into_raw()` without `Box::from_raw()` | Raw ptr never reclaimed |
| **Owned Reference** | `ManuallyDrop::new(box).as_ref()` | Reference to leaked memory |
| **Proxy Type** | Struct with `*mut T` field, no `Drop` impl | No destructor for inner ptr |
| **Container Drain** | `clear()` resets indices without element drops | Owned items abandoned |
| **Static Leak** | `Box::leak()` → `&'static mut [T]` in struct field | Ownership chain destroyed |

```rust
// Pattern RC1: Box::into_raw without from_raw
let buf = Box::new([0u8; 1024]);
let ptr = Box::into_raw(buf);  // Ownership transferred to raw ptr
// ... ptr is never passed to Box::from_raw() → LEAK

// Pattern RC2: Proxy type without Drop
struct Buffer {
    ptr: *mut u8,     // Raw pointer to heap allocation
    len: usize,
}
// No impl Drop for Buffer → ptr never freed → LEAK
// FIX: impl Drop for Buffer { fn drop(&mut self) { unsafe { dealloc(self.ptr, ...) } } }

// Pattern RC3: Container clear without element drop
fn clear(&mut self) {
    self.head = 0;
    self.tail = 0;  // Elements with Drop not called → LEAK
}
// FIX: iterate and drop each element before resetting indices
```

#### **Tool E: MIRAI (Facebook/Meta — MIR Abstract Interpreter)**
Full-program abstract interpreter with taint analysis, constant-time verification, and panic reachability.

```bash
# Install
cargo install mirai
# Run on target crate
cargo mirai                              # Default: avoid false positives
MIRAI_FLAGS="--diag=verify" cargo mirai  # Stricter: flag incomplete analysis
MIRAI_FLAGS="--constant_time SecretTag" cargo mirai  # Constant-time analysis
```

**Bug classes detected:**

| Class | Detection Method | Use Case |
|-------|-----------------|----------|
| **Reachable panics** | Abstract interpretation + Z3 | DoS in contracts, chain halt in Substrate |
| **Taint flow violations** | Configurable tag-based taint analysis | Unsanitized input → privileged operations |
| **Timing side channels** | `--constant_time` flag + tag tracking | Crypto key comparison, signature verification |
| **Precondition violations** | Function summary analysis | Callers not satisfying documented API contracts |
| **Integer overflow** | Interval domain + symbolic execution | All arithmetic operations checked |

**MIRAI annotation macros (mirai-annotations crate):**
```rust
use mirai_annotations::*;

// Precondition: verified at call sites
fn withdraw(amount: u64) {
    precondition!(amount > 0, "amount must be positive");
    precondition!(amount <= self.balance, "insufficient balance");
}

// Taint tracking: mark input as untrusted
fn process_input(data: &[u8]) {
    add_tag!(&data, Tainted);            // Mark as tainted
    let parsed = parse(data);
    verify!(does_not_have_tag!(&parsed, Tainted)); // Must sanitize before use
}

// Constant-time verification: detect branching on secrets
fn verify_mac(key: &[u8], msg: &[u8], tag: &[u8]) -> bool {
    add_tag!(&key, SecretTaint);
    // If key influences a branch condition → MIRAI warns (timing side channel)
    compute_hmac(key, msg) == tag  // Branch on secret → timing leak!
}
```

**Diagnostic levels:**
```markdown
| Level | Behavior |
|-------|----------|
| default | Suppress diagnostics from incomplete analysis (fewest false positives) |
| verify | Report incompletely analyzed functions (missing summaries) |
| library | Require explicit preconditions for all public functions |
| paranoid | Report all possible errors, continue after incomplete calls |
```

#### **General Rust Safety Tooling Decision Matrix**

```markdown
| When to Use | Tool | Why |
|-------------|------|-----|
| Codebase uses `unsafe` blocks | Rudra | Catches unsound patterns with 76-CVE track record |
| Codebase uses `unsafe` blocks | RAPx -V (Senryx) | Verifies 21 safety contracts on unsafe API calls |
| Codebase has concurrency (Mutex, RwLock, atomics) | lockbud | DoubleLock + ConflictLock + Atomic TOCTOU |
| Codebase uses raw pointers + unsafe | lockbud -k memory | UAF + invalid free via MIR analysis |
| Codebase uses raw pointers + unsafe | RAPx -F (SafeDrop) | Field-sensitive UAF/DF/dangling detection |
| Suspect memory leaks (ManuallyDrop, into_raw, FFI) | RAPx -M (rCanary) | Ownership + Z3-based leak detection |
| Constant-time requirements (crypto, signatures) | MIRAI --constant_time | Tag-based timing side channel detection |
| Need full panic reachability map | MIRAI | Abstract interpretation across all paths |
| Need panic location inventory | lockbud -k panic | Lists all unwrap/expect/panic sites |
| Performance-sensitive Rust code | RAPx -O (Opt) | Unnecessary clones, missing reserve, bounds checks |
| Custom `impl Send/Sync` on generic types | Rudra | SendSyncVariance catches unsound impls (76 CVEs!) |
| Complex Drop logic with unsafe | Rudra | UnsafeDestructor detects unsafe in Drop::drop() |
| Visualize unsafety propagation | RAPx -upg | DOT graph of unsafe → caller chains |
```

#### **General Rust grep-based rapid signal generation**
```bash
# === GENERAL RUST SAFETY DANGER MAP ===
echo "=== UNSAFE BLOCKS ==="
grep -rn "unsafe\s*{" src/ | grep -v test | grep -v "// SAFETY:"

echo "=== IMPL SEND/SYNC ON GENERICS (Rudra pattern) ==="
grep -rn "unsafe impl.*Send\|unsafe impl.*Sync" src/ | grep -v test

echo "=== RAW POINTERS ==="
grep -rn "\*mut \|\*const \|as \*mut\|as \*const" src/ | grep -v test

echo "=== PTR::READ/WRITE ON NON-COPY (Rudra pattern) ==="
grep -rn "ptr::read\|ptr::write\|ptr::copy" src/ | grep -v test

echo "=== VEC::SET_LEN (Rudra Error-level) ==="
grep -rn "set_len\|from_raw_parts" src/ | grep -v test

echo "=== MANUAL DROP / MEM::FORGET ==="
grep -rn "ManuallyDrop\|mem::forget\|into_raw\|from_raw" src/ | grep -v test

echo "=== UNINIT MEMORY ==="
grep -rn "MaybeUninit\|mem::uninitialized\|mem::zeroed" src/ | grep -v test

echo "=== LOCK USAGE (lockbud target) ==="
grep -rn "Mutex::new\|RwLock::new\|\.lock()\|\.read()\|\.write()" src/ | grep -v test

echo "=== ATOMICS (lockbud TOCTOU target) ==="
grep -rn "AtomicBool\|AtomicU\|AtomicI\|Ordering::" src/ | grep -v test

echo "=== TRANSMUTE ==="
grep -rn "transmute\b" src/ | grep -v test

echo "=== PANIC POINTS ==="
grep -rn "\.unwrap()\|\.expect(\|panic!\|unreachable!\|todo!\|unimplemented!" src/ | grep -c -v test

echo "=== UNSAFE DROP IMPLS (Rudra pattern) ==="
grep -rn "impl.*Drop" src/ | grep -v test

echo "=== FFI / EXTERN ==="
grep -rn "extern \"C\"\|#\[no_mangle\]\|c_char\|c_void" src/ | grep -v test
```

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

### **Step 9.2b: Solana-Specific False Positive Filters**
Critical checks to prevent over-reporting on Solana programs:

```markdown
1. **Anchor auto-validation**: `Account<'info, T>` automatically checks owner + discriminator.
   Don't report missing owner check if the struct uses `Account<'info, T>`.
2. **Anchor Signer type**: `Signer<'info>` automatically validates `is_signer`.
   Don't report missing signer check if the struct uses `Signer<'info>`.
3. **Anchor Program type**: `Program<'info, Token>` validates the program ID.
   Don't report arbitrary CPI if `Program<'info, T>` is used.
4. **Anchor seeds + bump**: `#[account(seeds = [...], bump)]` validates canonical PDA.
   Don't report PDA issues if Anchor's `seeds` constraint is used.
5. **overflow-checks = true**: If `Cargo.toml` has `[profile.release] overflow-checks = true`,
   the compiler traps arithmetic overflow. x-ray skips overflow checks for these programs.
6. **Account names starting with `_`**: x-ray ignores accounts prefixed with `_` or `_no_check`.
   These are intentionally unvalidated — flag only if security-critical.
7. **Query/view functions**: On Solana, view functions still execute instructions — 
   panics in view functions ARE a concern (unlike CosmWasm queries).
8. **PDA init with `init` constraint**: Anchor's `init` constraint handles initialization +
   rent payment atomically — don't report reinitialization for these.
9. **has_one constraint**: `#[account(has_one = authority)]` validates the relationship —
   don't duplicate report with missing signer check if `has_one` + `Signer` are both used.
10. **CpiContext safe methods**: Anchor's `anchor_spl::token::transfer()`, `mint_to()`, `burn()`
    are type-safe CPI wrappers — don't flag as arbitrary CPI.
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

#### Pattern S5: Account Reloading After CPI ⚠️ HIGH
**Description**: Accounts passed to CPI become stale. Using them without `.reload()` reads pre-CPI data. [SF-10]

```rust
// VULNERABLE: Stale data after CPI
let cpi_ctx = CpiContext::new(program, accounts);
anchor_spl::token::transfer(cpi_ctx, amount)?;
let balance = ctx.accounts.vault.amount;  // STALE — still pre-transfer value!

// SECURE: Reload after CPI
anchor_spl::token::transfer(cpi_ctx, amount)?;
ctx.accounts.vault.reload()?;  // Refresh from on-chain state
let balance = ctx.accounts.vault.amount;  // Current value
```
**Tool Detection**: solana-fender `account_reloading`

#### Pattern S6: Closing Accounts Without Cleanup ⚠️ MEDIUM
**Description**: Zeroing lamports without setting discriminator + zeroing data allows reinitialization attacks. [SF-06]

```rust
// VULNERABLE: Close without cleanup
**account.try_borrow_mut_lamports()? = 0;
// Account can be found on-chain with zero lamports but valid data
// Attacker re-funds and reinitializes

// SECURE: Full close procedure
let data = &mut account.try_borrow_mut_data()?;
// 1. Set closed discriminator
data[..8].copy_from_slice(&CLOSED_ACCOUNT_DISCRIMINATOR);
// 2. Zero remaining data
for byte in data[8..].iter_mut() { *byte = 0; }
// 3. Then zero lamports
**account.try_borrow_mut_lamports()? = 0;

// ANCHOR: Use close constraint
#[account(mut, close = user)]
pub vault: Account<'info, VaultAccount>,  // Anchor handles full cleanup
```
**Tool Detection**: solana-fender `closing_accounts`

#### Pattern S7: Duplicate Mutable Accounts ⚠️ MEDIUM
**Description**: Two `Account<'info>` fields without key-inequality constraint allow passing the same account twice. [SF-07]

```rust
// VULNERABLE: No constraint preventing same account
#[derive(Accounts)]
pub struct Transfer<'info> {
    #[account(mut)]
    pub from: Account<'info, TokenAccount>,
    #[account(mut)]
    pub to: Account<'info, TokenAccount>,
    // Attacker passes from == to → self-transfer doubles balance
}

// SECURE: Add key inequality constraint
#[derive(Accounts)]
pub struct Transfer<'info> {
    #[account(mut)]
    pub from: Account<'info, TokenAccount>,
    #[account(mut, constraint = from.key() != to.key())]
    pub to: Account<'info, TokenAccount>,
}
```
**Tool Detection**: solana-fender `duplicate_mutable_accounts`

#### Pattern S8: Type Cosplay (Account Confusion) ⚠️ HIGH
**Description**: Deserializing Borsh data without discriminator check allows type confusion — any account with matching size can masquerade as another type. [SVE-1010/1011, SF-03]

```rust
// VULNERABLE: No discriminator validation
let user = User::try_from_slice(&account.data.borrow())?;
// If Vault struct has same byte layout as User, attacker can pass a Vault account as User!

// SECURE: Check discriminator after deserialization
let user = User::try_from_slice(&account.data.borrow())?;
if user.discriminant != AccountDiscriminant::User {
    return Err(ErrorCode::InvalidAccountType.into());
}

// ANCHOR: Use #[account] — Anchor auto-adds 8-byte discriminator
#[account]
pub struct User {
    pub authority: Pubkey,
    pub balance: u64,
}
// Anchor automatically validates discriminator on deserialization
```
**Tool Detection**: x-ray SVE-1010/1011, solana-fender `type_cosplay`

#### Pattern S9: Seed Collision ⚠️ MEDIUM
**Description**: PDA seeds without a unique hardcoded string prefix can collide across program address types. [SF-19]

```rust
// VULNERABLE: No static prefix — two PDA types could collide
#[account(seeds = [user.key().as_ref(), vault.key().as_ref()], bump)]
pub pda_a: Account<'info, TypeA>,

#[account(seeds = [user.key().as_ref(), vault.key().as_ref()], bump)]
pub pda_b: Account<'info, TypeB>,
// Same seeds → same PDA → type confusion!

// SECURE: Unique string prefix per PDA type
#[account(seeds = [b"type_a", user.key().as_ref()], bump)]
pub pda_a: Account<'info, TypeA>,

#[account(seeds = [b"type_b", user.key().as_ref()], bump)]
pub pda_b: Account<'info, TypeB>,
```
**Tool Detection**: solana-fender `seed_collision`

#### Pattern S10: Precision Loss (Division Before Multiplication) ⚠️ MEDIUM
**Description**: Integer division truncates — dividing before multiplying loses precision. [SF-17, SVE-2004]

```rust
// VULNERABLE: Division truncates intermediate value
let result = (amount / x) * y;  // If amount=7, x=3, y=2 → (2)*2=4 (should be ~4.67)
let result = amount.checked_div(x)?.checked_mul(y)?;  // Same truncation issue

// SECURE: Multiply first, then divide
let result = (amount * y) / x;  // 7*2/3 = 14/3 = 4 (closer to correct)
let result = amount.checked_mul(y)?.checked_div(x)?;

// For fee calculations: use ceiling division
let fee = (amount * fee_rate + DENOMINATOR - 1) / DENOMINATOR;  // Round up
```
**Tool Detection**: solana-fender `precision_loss`, x-ray SVE-2004

#### Pattern S11: Insecure Randomness ⚠️ MEDIUM
**Description**: On-chain data (`Clock`, `SlotHashes`) is validator-manipulable and must not be used for security-critical randomness. [SF-13]

```rust
// VULNERABLE: Predictable/manipulable randomness
let clock = Clock::get()?;
let random = clock.unix_timestamp % 100;  // Validator can manipulate unix_timestamp
let random = clock.slot % 256;             // Slot is predictable

// ALSO VULNERABLE: SlotHashes and RecentBlockhashes
// These sysvars are on-chain-observable before transaction execution

// SECURE: Use verifiable random function (VRF)
// Switchboard VRF
let vrf_result = ctx.accounts.vrf.get_result()?;
// Chainlink VRF
// Pyth Entropy
```
**Tool Detection**: solana-fender `insecure_randomness`

#### Pattern S12: Initialization Frontrunning ⚠️ MEDIUM
**Description**: Global singleton PDAs with static seeds (`b"config"`) can be frontrun — anyone can call `initialize` first. [SF-12]

```rust
// VULNERABLE: No authority constraint on global init
#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(init, payer = signer, seeds = [b"config"], bump)]
    pub config: Account<'info, Config>,
    #[account(mut)]
    pub signer: Signer<'info>,
    pub system_program: Program<'info, System>,
}
// Anyone can call initialize and become the config authority!

// SECURE: Validate deployer authority
#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(init, payer = signer, seeds = [b"config"], bump)]
    pub config: Account<'info, Config>,
    #[account(mut, constraint = signer.key() == program_data.upgrade_authority.unwrap())]
    pub signer: Signer<'info>,
    #[account(constraint = program.programdata_address()? == Some(program_data.key()))]
    pub program: Program<'info, MyProgram>,
    pub program_data: Account<'info, ProgramData>,
    pub system_program: Program<'info, System>,
}
```
**Tool Detection**: solana-fender `initialization_frontrunning`

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

### **General Rust Safety Detection Patterns (Awesome-Rust-Checker)**

> These patterns are sourced from academic Rust static analyzers (Rudra, lockbud, RAPx, rCanary, MIRAI)
> and provide detection patterns for memory safety, concurrency, and unsafe code bugs applicable to ALL Rust codebases.

#### Pattern RUST1: Unsound Send/Sync on Generic Types ⚠️ CRITICAL (Rudra)
**Description**: `unsafe impl Send/Sync` for generic wrappers without bounding type parameters allows data races. Rudra found 76 CVEs from this pattern alone.

```rust
// VULNERABLE: T is not bounded by Send — data race if T contains Rc<Cell<_>>
struct Wrapper<T> { inner: T }
unsafe impl<T> Send for Wrapper<T> {}  // Rudra: SendSyncVariance Error
unsafe impl<T> Sync for Wrapper<T> {}  // Rudra: SendSyncVariance Error

// SECURE: Bound T appropriately
unsafe impl<T: Send> Send for Wrapper<T> {}
unsafe impl<T: Send + Sync> Sync for Wrapper<T> {}

// EDGE CASE: Concurrent queue pattern — impl Sync needs T: Send (not T: Sync)
// If the container only moves T in/out (never exposes &T), T: Send suffices for Sync
```
**Tool Detection**: Rudra `SendSyncVariance`, severity Error (API_SEND_FOR_SYNC, RELAX_SEND)

#### Pattern RUST2: Panic Safety in Unsafe Code ⚠️ HIGH (Rudra)
**Description**: Unsafe lifetime-bypassing operations followed by generic function calls that may panic cause double-free or uninitialized memory access.

```rust
// VULNERABLE: set_len before elements are initialized — if clone() panics, uninitialized memory is exposed
unsafe {
    vec.set_len(vec.len() + count);  // Length extended before writing
    for (i, x) in items.iter().enumerate() {
        vec.as_mut_ptr().offset(i as isize).write(x.clone()); // clone() can panic!
    }
}
// If clone() panics at index 3, indices 3..count contain uninitialized memory
// When vec is dropped, Drop runs on garbage → UB

// SECURE: Write elements first, then extend length
unsafe {
    let base = vec.as_mut_ptr().add(vec.len());
    for (i, x) in items.iter().enumerate() {
        base.add(i).write(x.clone());
    }
    vec.set_len(vec.len() + count);  // Only after all writes succeed
}
```
**Tool Detection**: Rudra `UnsafeDataflow` — set_len = Error, ptr::read = Warning, transmute = Info

#### Pattern RUST3: Self-Deadlock (DoubleLock) ⚠️ HIGH (lockbud)
**Description**: Acquiring a lock while already holding the same lock on a single thread causes immediate deadlock.

```rust
// VULNERABLE: Mutex re-entry — thread blocks forever
fn process(data: &Mutex<State>) {
    let state = data.lock().unwrap();
    if state.needs_update {
        let state2 = data.lock().unwrap();  // DEADLOCK — already holding lock
    }
}

// VULNERABLE: Lock acquired in match arm while held
let guard = mutex.lock().unwrap();
match *guard {
    Mode::A => { mutex.lock().unwrap(); }  // DEADLOCK
    _ => {}
}

// SECURE: Release lock before re-acquiring
fn process(data: &Mutex<State>) {
    let needs_update = { data.lock().unwrap().needs_update };  // Lock released
    if needs_update {
        let mut state = data.lock().unwrap();  // Safe — first lock released
        state.update();
    }
}
```
**Tool Detection**: lockbud `-k deadlock`, confidence Probably/Possibly

#### Pattern RUST4: Lock-Order Inversion (ConflictLock) ⚠️ HIGH (lockbud)
**Description**: Two code paths acquiring the same pair of locks in opposite order creates a potential mutual deadlock.

```rust
// VULNERABLE: Opposite lock ordering across functions
fn transfer_a_to_b(a: &Mutex<_>, b: &Mutex<_>) {
    let _ga = a.lock(); let _gb = b.lock();  // Order: a → b
}
fn transfer_b_to_a(a: &Mutex<_>, b: &Mutex<_>) {
    let _gb = b.lock(); let _ga = a.lock();  // Order: b → a — DEADLOCK RISK
}

// SECURE: Establish consistent lock ordering
fn transfer(first: &Mutex<_>, second: &Mutex<_>) {
    let id_first = first as *const _ as usize;
    let id_second = second as *const _ as usize;
    if id_first < id_second {
        let _g1 = first.lock(); let _g2 = second.lock();
    } else {
        let _g1 = second.lock(); let _g2 = first.lock();
    }
}
```
**Tool Detection**: lockbud `-k deadlock` (ConflictLock cycle detection)

#### Pattern RUST5: Atomic TOCTOU Race ⚠️ MEDIUM (lockbud)
**Description**: Check-then-act on atomic variables without a single atomic RMW operation enables time-of-check/time-of-use races.

```rust
// VULNERABLE: Load-check-store is NOT atomic
if counter.load(Ordering::SeqCst) < MAX {
    counter.store(counter.load(Ordering::SeqCst) + 1, Ordering::SeqCst);
    // Another thread could modify counter between load and store!
}

// SECURE: Use atomic compare-exchange
loop {
    let current = counter.load(Ordering::SeqCst);
    if current >= MAX { break; }
    match counter.compare_exchange(current, current + 1, Ordering::SeqCst, Ordering::SeqCst) {
        Ok(_) => break,
        Err(_) => continue,  // Retry on contention
    }
}
// OR: counter.fetch_add(1, Ordering::SeqCst)
```
**Tool Detection**: lockbud `-k atomicity_violation`, confidence Possibly

#### Pattern RUST6: Use-After-Free via Raw Pointer ⚠️ CRITICAL (lockbud/RAPx)
**Description**: Raw pointer used or escaping after its pointee has been dropped.

```rust
// VULNERABLE: Raw ptr escapes to global after pointee drop
static mut GLOBAL: *const String = std::ptr::null();
fn init() {
    let s = String::from("hello");
    unsafe { GLOBAL = &s as *const String; }
    // s dropped here — GLOBAL is dangling!
}

// VULNERABLE: Raw ptr returned from function with local pointee
fn danger() -> *const Vec<u8> {
    let v = vec![1, 2, 3];
    &v as *const Vec<u8>  // v dropped → dangling pointer returned
}

// SECURE: Ensure pointee outlives pointer usage
fn safe() -> Box<Vec<u8>> {
    Box::new(vec![1, 2, 3])  // Heap-allocated, ownership transferred to caller
}
```
**Tool Detection**: lockbud `-k memory` (UseAfterFree), RAPx `-F` (SafeDrop)

#### Pattern RUST7: Invalid Free (Uninitialized Memory Drop) ⚠️ CRITICAL (lockbud)
**Description**: Dropping a value created from `MaybeUninit::assume_init()` without prior `.write()` frees garbage pointers.

```rust
// VULNERABLE: assume_init without write — drop will free garbage
let val: Vec<i32> = unsafe { MaybeUninit::uninit().assume_init() };
// val is dropped → Vec tries to free garbage internal pointer → UB

// VULNERABLE: Deprecated mem::uninitialized
let val: String = unsafe { std::mem::uninitialized() };
// val is dropped → String tries to free garbage pointer → UB

// SECURE: Write before assuming init
let mut uninit = MaybeUninit::<Vec<i32>>::uninit();
uninit.write(Vec::new());           // Initialize first
let val = unsafe { uninit.assume_init() };  // Now safe to use and drop
```
**Tool Detection**: lockbud `-k memory` (InvalidFree), checks for `.write()` on all CFG paths

#### Pattern RUST8: Memory Leak via Ownership Escape ⚠️ MEDIUM (rCanary/RAPx)
**Description**: Heap-allocated values that escape OBRM (Ownership-Based Resource Management) via ManuallyDrop, into_raw, or mem::forget are never freed.

```rust
// VULNERABLE: Box::into_raw without matching from_raw
let buf = Box::new([0u8; 4096]);
let ptr = Box::into_raw(buf);  // Ownership goes to raw ptr
// ptr is stored but never passed to Box::from_raw() → LEAK

// VULNERABLE: ManuallyDrop prevents automatic cleanup
let data = ManuallyDrop::new(Box::new(expensive_data));
// data is never manually dropped → LEAK

// VULNERABLE: Proxy type without Drop impl
struct Buffer { ptr: *mut u8, len: usize }
// Buffer.ptr allocated via alloc() but Buffer has no Drop impl → LEAK

// SECURE: Ensure cleanup path exists
let ptr = Box::into_raw(buf);
// ... use ptr ...
let _ = unsafe { Box::from_raw(ptr) };  // Reclaim ownership, drop frees memory

// SECURE: Proxy type with Drop
impl Drop for Buffer {
    fn drop(&mut self) {
        unsafe { std::alloc::dealloc(self.ptr, Layout::from_size_align(self.len, 1).unwrap()); }
    }
}
```
**Tool Detection**: rCanary/RAPx `-M` (6 leak pattern categories), Z3-based ownership tracking

#### Pattern RUST9: Unsafe Destructor ⚠️ MEDIUM (Rudra)
**Description**: Non-FFI unsafe function calls inside `Drop::drop()` implementations may cause double-free, UAF, or other UB if the destructor logic is unsound.

```rust
// FLAGGED: Unsafe call in Drop (Rudra: UnsafeDestructor Warning)
// RUSTSEC-2020-0032 pattern
impl Drop for MyHandle {
    fn drop(&mut self) {
        unsafe {
            CString::from_raw(self.ptr as *mut c_char);  // Takes ownership of ptr
            // If self.ptr was already freed or invalid → double-free / UAF
        }
    }
}

// AUDIT CHECKLIST for unsafe Drop:
// - Is the pointer guaranteed valid at drop time?
// - Can the destructor run twice (via ManuallyDrop)?
// - Is the pointer aliased elsewhere?
// - Could panic unwind cause partial drop + re-drop?
```
**Tool Detection**: Rudra `UnsafeDestructor` (Warning level), filters out FFI-only `extern` calls

#### Pattern RUST10: Timing Side Channel ⚠️ HIGH (MIRAI)
**Description**: Secret data influencing branch conditions leaks information via execution time differences.

```rust
// VULNERABLE: Early return on mismatch leaks position of first wrong byte
fn verify_mac(expected: &[u8], actual: &[u8]) -> bool {
    if expected.len() != actual.len() { return false; }
    for i in 0..expected.len() {
        if expected[i] != actual[i] { return false; }  // Timing leak!
    }
    true
}

// SECURE: Constant-time comparison
fn verify_mac_ct(expected: &[u8], actual: &[u8]) -> bool {
    use subtle::ConstantTimeEq;
    expected.ct_eq(actual).into()  // No early return — constant time
}
```
**Tool Detection**: MIRAI `--constant_time SecretTag` + `add_tag!(&key, SecretTaint)`

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

## Solana-Specific Completion Checklist:
- [ ] All 19 solana-fender analyzer categories reviewed
- [ ] x-ray SVE scan completed (if LLVM toolchain available)
- [ ] OWASP Solana Top 10 categories cross-referenced
- [ ] All Account structs reviewed for Signer/Account/Program types
- [ ] All CPI calls validated for program ID checks
- [ ] All PDA derivations use canonical bumps
- [ ] All account closures zero discriminator + data
- [ ] Accounts reloaded after CPI before reuse
- [ ] No insecure randomness sources in security-critical paths
- [ ] Instruction introspection uses relative indexing

## General Rust Safety Completion Checklist (Awesome-Rust-Checker):
- [ ] All `unsafe impl Send/Sync` for generics checked for bound correctness (Rudra)
- [ ] All `unsafe` blocks reviewed for panic-safety (generic calls after lifetime bypass)
- [ ] All `Drop` impls with unsafe code audited for soundness (Rudra)
- [ ] Concurrency primitives checked for deadlock potential (lockbud)
- [ ] Atomic variables checked for TOCTOU patterns (lockbud)
- [ ] Raw pointer lifetimes verified — no UAF, no dangling (lockbud/RAPx)
- [ ] MaybeUninit usage checked for write-before-assume_init (lockbud)
- [ ] ManuallyDrop/Box::into_raw have matching cleanup paths (rCanary)
- [ ] Custom containers with raw ptrs have Drop impls (rCanary)
- [ ] Crypto operations verified for constant-time behavior (MIRAI)
- [ ] Panic reachability assessed for critical paths (MIRAI/lockbud)
```
