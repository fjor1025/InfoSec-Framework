# Comprehensive Cairo/StarkNet Smart Contract Audit Methodology

> **Integration Note:** This file contains the Cairo-specific audit methodology.
> For LLM conversation structure, see `Audit_Assistant_Playbook_Cairo.md`.
> For the system prompt, see `CommandInstruction-Cairo.md`.
> For Solidity L1 methodology, see `../Solidity-EVM/`.

---

## **Phase 1: Entry Point Identification & Scope Definition**

### **Step 1.0: Time-Boxing Strategy (For Large Codebases)**
Prevent analysis paralysis with structured time allocation:

```markdown
**Round 1 (40% of time): Quick Triage ALL Entry Points**
- 5 minutes max per function
- Identify #[external(v0)] and #[l1_handler]
- Note felt252 operations, flag L1 handlers for deep dive
- Goal: Map the attack surface

**Round 2 (40% of time): Deep Dive TOP 5 Priority Functions**
- Full checklist, L1↔L2 analysis, arithmetic checks
- Document findings as you go
- Goal: Find critical vulnerabilities

**Round 3 (20% of time): Cross-Contract & L1↔L2 Paths**
- End-to-end message flows
- Cancellation and recovery paths
- Goal: Catch composition bugs
```

**Time Tracking Template:**
```markdown
| Phase | Allocated | Actual | Functions Covered |
|-------|-----------|--------|-------------------|
| Triage | 4 hours | _ | handle_deposit, transfer, withdraw... |
| Deep Dive | 4 hours | _ | #[l1_handler] functions, bridge logic |
| Cross-Contract | 2 hours | _ | L1↔L2 roundtrip, error paths |
```

---

### **Step 1.1: Identify Cairo Audit Root Functions**
Find **all functions** that satisfy **≥2** of these Cairo-specific criteria:

- [ ] `#[external(v0)]` attribute (public state-changing)
- [ ] `#[l1_handler]` attribute (L1→L2 message handler) **← PRIORITY**
- [ ] `#[constructor]` (initialization)
- [ ] Writes to `#[storage]`
- [ ] Performs arithmetic on `felt252`
- [ ] Calls `send_message_to_l1_syscall`
- [ ] Interacts with other contracts via dispatchers

**Commands to identify entry points:**
```bash
# Find all external functions
grep -r "#\[external" --include="*.cairo" .

# Find all L1 handlers (CRITICAL)
grep -r "#\[l1_handler\]" --include="*.cairo" .

# Find felt252 arithmetic
grep -r "felt252" --include="*.cairo" . | grep -E "\+|\-|\*|/"

# Find L2→L1 messages
grep -r "send_message_to_l1" --include="*.cairo" .
```

### **Step 1.2: Quick Protocol Understanding**
```markdown
## Cairo-Specific Protocol Context

**Cairo Version**: [Cairo 1.x / Cairo 2.x]
**StarkNet Version**: [0.13.x]
**Contract Framework**: [Raw Cairo / OpenZeppelin Cairo]

**Key Contracts:**
- `main.cairo`: [Main contract logic]
- `bridge.cairo`: [L1↔L2 bridge handlers]
- `token.cairo`: [Token implementation]

**L1 Components (if bridge):**
- `L1Bridge.sol`: [Solidity bridge contract]
- Deployed at: [L1 address]

**External Integrations:**
- Oracles: [Pragma / Empiric / Custom]
- DEX: [JediSwap / 10KSwap / Custom]
- Other L2 Contracts: [List]
```

### **Step 1.3: Prioritization Matrix (Cairo Edition)**
```markdown
## Priority 1 (Attack Immediately)
- [ ] ALL `#[l1_handler]` functions (from_address validation)
- [ ] Functions that move funds (transfer, withdraw, bridge)
- [ ] Functions with `felt252` arithmetic on balances
- [ ] Signature verification logic
- [ ] Admin/upgrade functions

## Priority 2 (Attack After)
- [ ] View functions returning sensitive data
- [ ] Functions with `send_message_to_l1_syscall`
- [ ] Storage initialization and upgrade logic
- [ ] Price/oracle calculations

## Priority 3 (Check Later)
- [ ] Gas optimization (storage access patterns)
- [ ] Event emission completeness
- [ ] Code style and best practices
```

### **Step 1.4: Mandatory Validation Checks**
_Per methodology — ALL must pass before reporting a finding_

| Check | Question | Cairo-Specific Considerations |
|-------|----------|-------------------------------|
| **Reachability** | Can this be called? | Is it `#[external(v0)]` or `#[l1_handler]`? |
| **State Freshness** | Works with current state? | Testing with realistic storage state? |
| **L1↔L2 Closure** | All message paths modeled? | L1 handlers, L2→L1 messages, cancellation |
| **Economic Realism** | Cost/timing feasible? | L1 calldata costs, sequencer fees |

---

## **Phase 2: Build Execution Spine with Cairo Patterns**

### **Step 2.1: Extract Call Graph**
```cairo
// Map the execution flow
#[external(v0)]
fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) {
    // SNAPSHOT: Read current state
    let sender = get_caller_address();
    let sender_balance = self.balances.read(sender);      // Storage read
    
    // VALIDATION: Check constraints
    assert(sender_balance >= amount, 'Insufficient balance'); // Bounds check
    
    // MUTATION: Update state
    self.balances.write(sender, sender_balance - amount);   // Arithmetic + write
    self.balances.write(to, self.balances.read(to) + amount);
    
    // COMMIT: Emit event
    self.emit(Transfer { from: sender, to, amount });
}
```

### **Step 2.2: Format Spine with Cairo Annotations**
```text
TRANSFER(to: ContractAddress, amount: u256)
├── [CONTEXT] get_caller_address() → ContractAddress
├── [SNAPSHOT] balances.read(sender) → u256
├── [VALIDATION] assert(sender_balance >= amount)
├── [MUTATION] balances.write(sender, sender_balance - amount)
│   └── ARITHMETIC: u256 subtraction (safe)
├── [MUTATION] balances.write(to, recipient_balance + amount)
│   └── ARITHMETIC: u256 addition (check overflow?)
└── [COMMIT] emit Transfer { from, to, amount }
```

### **Step 2.3: L1 Handler Spine (CRITICAL)**
```text
#[l1_handler] HANDLE_DEPOSIT(from_address, user, amount)
├── [VALIDATION] from_address == authorized_l1_bridge? ← CRITICAL CHECK
├── [VALIDATION] user != zero_address?
├── [SNAPSHOT] balances.read(user) → current_balance
├── [MUTATION] balances.write(user, current_balance + amount)
│   └── OVERFLOW RISK: What if current_balance + amount overflows?
└── [COMMIT] emit DepositProcessed { user, amount }

Missing Validations to Flag:
- [ ] from_address not validated (CRITICAL)
- [ ] user could be zero address (HIGH)
- [ ] No overflow check on balance update (HIGH)
```

---

## **Phase 3: Cairo-Specific Semantic Classification**

### **Classification Table with Cairo Patterns**
| Intent Tag | Cairo Indicators | Questions to Ask |
|------------|-----------------|------------------|
| **CONTEXT** | `get_caller_address()`, `get_contract_address()`, `get_tx_info()`, `get_block_info()` | • Is caller validated?<br>• Is block timestamp used safely? |
| **SNAPSHOT** | `storage.read()`, `LegacyMap::read()`, view calls | • Are reads before writes?<br>• Could storage be stale? |
| **VALIDATION** | `assert()`, `assert!()`, comparison operators | • Are ALL inputs validated?<br>• Is from_address checked for L1 handlers? |
| **ARITHMETIC** | `+`, `-`, `*`, `/` on felt252, u128, u256 | • Is felt252 used safely?<br>• Are bounds checked before arithmetic? |
| **MUTATION** | `storage.write()`, `LegacyMap::write()`, state changes | • Is update order correct?<br>• Could this enable reentrancy? |
| **L1_MESSAGE** | `send_message_to_l1_syscall()` | • Will L1 contract process this?<br>• Is there confirmation mechanism? |
| **COMMIT** | `self.emit()`, event emission | • Are all state changes logged?<br>• Are events emitted after mutations? |

---

## **Phase 4: Semantic Order Audit (Cairo Edition)**

### **Pass 1: L1 Handler Validation (CRITICAL)**
```markdown
### L1 Handler Security Checklist
For EVERY `#[l1_handler]` function:

- [ ] **from_address Validated**: Compared to stored authorized L1 address
- [ ] **Zero Address Check**: All ContractAddress params != 0
- [ ] **Amount Validation**: Amount > 0, within reasonable bounds
- [ ] **Idempotency**: Can handle replay gracefully?
- [ ] **Error Handling**: What happens on failure?

### Red Flags:
```cairo
// CRITICAL: No from_address validation
#[l1_handler]
fn handle_deposit(ref self: ContractState, from_address: felt252, ...) {
    // Missing: assert(from_address == self.l1_bridge.read())
    ...
}
```
```

### **Pass 2: Arithmetic Safety**
```markdown
### Arithmetic Security Checklist

- [ ] **felt252 Operations**: ALL arithmetic on felt252 has bounds checks
- [ ] **Balance Updates**: Using u128/u256 instead of felt252?
- [ ] **Multiplication**: Could result exceed type bounds?
- [ ] **Division**: Denominator validated != 0?
- [ ] **Subtraction**: Checked that a >= b before a - b?

### Safe Patterns:
```cairo
// VULNERABLE: felt252 arithmetic
let balance: felt252 = self.balances_felt.read(user);
let new_balance = balance - amount;  // Can underflow to ~P!

// SECURE: u256 with explicit check
let balance: u256 = self.balances.read(user);
assert(balance >= amount, 'Insufficient balance');
let new_balance = balance - amount;  // Safe after check
```
```

### **Pass 3: Signature Verification**
```markdown
### Signature Security Checklist

- [ ] **Nonce Included**: Per-signer nonce in message hash?
- [ ] **Nonce Incremented**: Before or after execution?
- [ ] **Domain Separator**: Includes chain_id + contract_address?
- [ ] **Hash Function**: Using poseidon or pedersen appropriately?
- [ ] **OpenZeppelin**: Using OZ Account for standard operations?

### Secure Pattern:
```cairo
fn verify_signature(
    self: @ContractState,
    signer: ContractAddress,
    message_hash: felt252,
    signature: Array<felt252>,
    nonce: felt252
) -> bool {
    // Check nonce
    let current_nonce = self.nonces.read(signer);
    assert(nonce == current_nonce, 'Invalid nonce');
    
    // Build hash with domain separator
    let domain = self.get_domain_separator();
    let full_hash = poseidon_hash_span(
        array![domain, message_hash, nonce].span()
    );
    
    // Verify signature
    // ...
}
```
```

### **Pass 4: Storage Operations**
```markdown
### Storage Security Checklist

- [ ] **Read-Modify-Write**: Are patterns atomic?
- [ ] **Reentrancy**: Can callbacks modify state mid-operation?
- [ ] **Initialization**: Can storage be re-initialized?
- [ ] **Key Collisions**: Are LegacyMap keys unique?
- [ ] **Zero Values**: Are default values handled?

### Storage Patterns:
```cairo
// VULNERABLE: Read-modify-write with external call
let balance = self.balances.read(user);
self.external_contract.callback(user);  // Could re-enter!
self.balances.write(user, balance - amount);

// SECURE: Update before external call
let balance = self.balances.read(user);
self.balances.write(user, balance - amount);  // Update first
self.external_contract.callback(user);         // Then call
```
```

---

## **Phase 5: L1↔L2 Bridge Security**

### **Step 5.1: L1→L2 Message Flow Analysis**
```markdown
## L1→L2 Security Checklist

### Address Conversion
- [ ] L1 validates: `require(l2Address < STARKNET_FIELD_PRIME)`
- [ ] L2 validates: `assert(user != zero_address)`

### Message Handling
- [ ] L2 handler validates `from_address`
- [ ] Funds only credited after all validation passes
- [ ] Events emitted for tracking

### Failure Recovery
- [ ] L1 implements `startL1ToL2MessageCancellation`
- [ ] L1 implements `cancelL1ToL2Message`
- [ ] Cancellation delay documented and appropriate
- [ ] Users can recover funds if L2 never processes message

### Attack Scenarios to Test:
1. **Spoofed L1 Sender**: Deploy malicious L1 contract, send fake deposits
2. **Address Overflow**: Send L1 address >= STARKNET_PRIME
3. **Message Failure**: What if sequencer never includes message?
```

### **Step 5.2: L2→L1 Message Flow Analysis**
```markdown
## L2→L1 Security Checklist

### Message Sending
- [ ] State updated BEFORE sending message
- [ ] Cannot re-enter during message sending
- [ ] Message includes all necessary parameters

### L1 Consumption
- [ ] L1 validates message origin (StarkNet core)
- [ ] L1 handles message exactly once
- [ ] Funds only released after message verification

### Symmetric Validation
- [ ] Same access controls on L1 and L2
- [ ] Blocked users blocked on BOTH layers
- [ ] Whitelist/blacklist synchronized
```

### **Step 5.3: Bridge Invariant Testing**
```cairo
// Invariants that MUST hold:

// 1. Total L2 balance <= Total L1 deposits - Total L1 withdrawals
assert(l2_total_supply <= l1_total_deposited - l1_total_withdrawn);

// 2. Every L1 deposit has corresponding L2 credit (eventually)
// OR has been cancelled with funds returned

// 3. Every L2 withdrawal can be finalized on L1
// (symmetric validation ensures this)

// 4. No funds created from nothing
assert(user_balance_change == message_amount);
```

---

## **Phase 6: Attack Simulation**

### **Step 6.1: Known Cairo/StarkNet Exploit Patterns**

```markdown
## Historical Exploit Database - Cairo/StarkNet

**L1↔L2 Exploits:**
- [ ] **ZKLend Pattern**: L1 message validation bypass
- [ ] **Bridge Spoofing**: Unchecked from_address in L1 handler
- [ ] **Address Truncation**: L1 address > PRIME becomes zero

**Arithmetic Exploits:**
- [ ] **felt252 Overflow**: Balance wraps from 0 to ~P-1
- [ ] **felt252 Underflow**: Balance wraps from ~P to near 0
- [ ] **Multiplication Overflow**: a * b exceeds prime

**Signature Exploits:**
- [ ] **Replay Attack**: Same signature used multiple times
- [ ] **Cross-Chain Replay**: Mainnet signature used on testnet
- [ ] **Nonce Reuse**: Nonce not incremented properly

**General Exploits:**
- [ ] **Reentrancy**: Via contract callbacks
- [ ] **Storage Collision**: LegacyMap key overlap
- [ ] **Initialization**: Re-init constructor logic
```

### **Step 6.2: Cairo-Specific Edge Case Testing**
```cairo
// Edge values for testing
const FELT252_MAX: felt252 = 0x800000000000011000000000000000000000000000000000000000000000000;
const ZERO_ADDRESS: ContractAddress = 0.try_into().unwrap();
const STARKNET_PRIME: u256 = 0x800000000000011000000000000000000000000000000000000000000000001;

// Test cases:
// 1. Zero amounts
// 2. Maximum felt252 values
// 3. Zero addresses
// 4. L1 addresses at/above STARKNET_PRIME
// 5. Empty arrays/calldata
// 6. Replayed signatures
// 7. Invalid from_address in L1 handlers
```

### **Step 6.3: L1↔L2 Attack Scenarios**
```markdown
## Attack Scenario: L1 Handler Spoofing

1. Attacker deploys malicious contract on L1
2. Attacker calls StarkNet Core's sendMessageToL2()
3. Message includes attacker as from_address
4. L2 #[l1_handler] processes message
5. If from_address not validated: funds credited to attacker's chosen address

## Attack Scenario: Address Truncation

1. User has L1 address > STARKNET_FIELD_PRIME (edge case)
2. L1 bridge converts to felt252 (truncates or wraps)
3. L2 receives as zero address or unintended address
4. Funds credited to zero address (locked) or wrong user

## Attack Scenario: Message Failure Fund Lock

1. User deposits on L1, funds locked in bridge
2. L1→L2 message sent to sequencer
3. Sequencer never processes (gas spike, congestion, etc.)
4. Without cancellation mechanism: funds locked forever
```

---

## **Phase 7: Enhanced Detection Patterns (ClaudeSkills Integration)**

> These patterns are sourced from Trail of Bits' building-secure-contracts repository

### **Pattern C1: felt252 Arithmetic Overflow ⚠️ HIGH**
**Description**: Field element arithmetic wraps at prime P, enabling overflow/underflow attacks.

```cairo
// VULNERABLE: Direct felt252 arithmetic
#[external(v0)]
fn transfer(ref self: ContractState, to: ContractAddress, amount: felt252) {
    let balance: felt252 = self.balances.read(get_caller_address());
    // UNDERFLOW: If balance < amount, wraps to ~P
    self.balances.write(get_caller_address(), balance - amount);
}

// SECURE: Use bounded types with explicit checks
#[external(v0)]
fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) {
    let balance: u256 = self.balances.read(get_caller_address());
    assert(balance >= amount, 'Insufficient balance');
    self.balances.write(get_caller_address(), balance - amount);
}
```
**Tool Detection**: Caracal `unchecked-felt252-arithmetic`

### **Pattern C2: Unchecked L1 Handler from_address ⚠️ CRITICAL**
**Description**: L1 handlers without from_address validation allow any L1 contract to trigger deposits.

```cairo
// VULNERABLE: No from_address check
#[l1_handler]
fn handle_deposit(
    ref self: ContractState,
    from_address: felt252,  // NOT VALIDATED!
    user: ContractAddress,
    amount: u256
) {
    self.balances.write(user, self.balances.read(user) + amount);
}

// SECURE: Validate from_address
#[l1_handler]
fn handle_deposit(
    ref self: ContractState,
    from_address: felt252,
    user: ContractAddress,
    amount: u256
) {
    let authorized_bridge = self.l1_bridge_address.read();
    assert(from_address == authorized_bridge, 'Unauthorized L1 sender');
    assert(user != starknet::contract_address_const::<0>(), 'Invalid user');
    
    self.balances.write(user, self.balances.read(user) + amount);
}
```
**Tool Detection**: Caracal `unchecked-l1-handler-from`

### **Pattern C3: L1→L2 Address Conversion ⚠️ HIGH**
**Description**: L1 addresses >= STARKNET_FIELD_PRIME truncate to zero or unexpected values.

```solidity
// VULNERABLE: L1 contract doesn't validate address range
function depositToL2(address l2Recipient, uint256 amount) external {
    // WRONG: No check that l2Recipient < STARKNET_FIELD_PRIME
    starknetCore.sendMessageToL2(l2Contract, selector, payload);
}

// SECURE: Validate address is in valid range
uint256 constant STARKNET_FIELD_PRIME = 
    0x0800000000000011000000000000000000000000000000000000000000000001;

function depositToL2(uint256 l2Recipient, uint256 amount) external {
    require(l2Recipient != 0, "Zero address");
    require(l2Recipient < STARKNET_FIELD_PRIME, "Address out of range");
    starknetCore.sendMessageToL2(l2Contract, selector, payload);
}
```

### **Pattern C4: Signature Replay ⚠️ HIGH**
**Description**: Signatures without nonce/domain separation can be replayed.

```cairo
// VULNERABLE: No nonce, no domain separator
fn verify_signature(message: felt252, sig: Array<felt252>) -> bool {
    // Same signature works forever!
    // Same signature works on mainnet AND testnet!
}

// SECURE: Include nonce and domain separator
fn verify_signature(
    self: @ContractState,
    signer: ContractAddress,
    message: felt252,
    signature: Array<felt252>,
    nonce: felt252
) -> bool {
    // Check nonce
    let current_nonce = self.nonces.read(signer);
    assert(nonce == current_nonce, 'Invalid nonce');
    
    // Include domain separator
    let domain = self.get_domain_separator(); // chain_id + contract_address
    let full_hash = poseidon_hash_span(array![domain, message, nonce].span());
    
    // Verify signature against full_hash
    // ...
    
    // Increment nonce BEFORE any execution
    self.nonces.write(signer, current_nonce + 1);
    
    true
}
```
**Tool Detection**: Caracal `missing-nonce-validation`

### **Pattern C5: L1→L2 Message Failure Fund Lock ⚠️ HIGH**
**Description**: Without cancellation mechanism, failed L1→L2 messages lock funds permanently.

```solidity
// VULNERABLE: No cancellation mechanism
function depositToL2(uint256 amount) external {
    // Lock funds
    token.transferFrom(msg.sender, address(this), amount);
    // Send message (could fail to process on L2!)
    starknetCore.sendMessageToL2(l2Contract, selector, payload);
    // If L2 never processes: funds locked forever!
}

// SECURE: Implement cancellation
function startCancellation(bytes32 msgHash, uint256 nonce) external {
    starknetCore.startL1ToL2MessageCancellation(
        l2Contract, selector, payload, nonce
    );
}

function completeCancellation(bytes32 msgHash, uint256 nonce) external {
    starknetCore.cancelL1ToL2Message(
        l2Contract, selector, payload, nonce
    );
    // Return funds to user
    token.transfer(messageOwner[msgHash], amount);
}
```

### **Pattern C6: Overconstrained L1↔L2 Validation ⚠️ MEDIUM**
**Description**: Asymmetric validation between L1 and L2 traps user funds.

```markdown
## Example: User Can Deposit But Not Withdraw

L1 Bridge (Solidity):
- Deposit: No restrictions
- Withdraw: Requires whitelist

L2 Contract (Cairo):
- Handle deposit: No restrictions
- Initiate withdrawal: No restrictions

Result: User deposits freely, but L1 blocks their withdrawal!

## Fix: Symmetric Validation
- Same whitelist/blacklist on BOTH L1 and L2
- Test full roundtrip: deposit on L1 → withdraw on L1
```

---

## **Universal Red Flags (Cairo Edition)**

```markdown
## Immediate Red Flags - Stop and Investigate

### L1↔L2 Security
- [ ] ANY #[l1_handler] without from_address validation
- [ ] L1 bridge without address range validation
- [ ] Missing cancellation mechanism for L1→L2 deposits
- [ ] Asymmetric access controls between L1 and L2

### Arithmetic Safety
- [ ] felt252 used for balances or amounts
- [ ] Subtraction without >= check
- [ ] Multiplication without overflow consideration
- [ ] Division without zero-check

### Signature Security
- [ ] No nonce in signature hash
- [ ] No domain separator (chain_id, contract_address)
- [ ] Nonce incremented AFTER execution (reentrancy risk)

### Access Control
- [ ] No owner/admin pattern on critical functions
- [ ] Upgrade functions without access control
- [ ] Constructor can be re-called (initialization issue)

### Storage
- [ ] Read-modify-write with external calls between
- [ ] Potential key collisions in LegacyMap
- [ ] Zero values treated as valid when shouldn't be
```

---

## **Invariants Template (Cairo Edition)**

```cairo
// Invariants that MUST hold for any Cairo smart contract:

// 1. No free money
assert(total_supply == sum_of_all_balances);

// 2. L1↔L2 balance consistency
assert(l2_total <= l1_deposits - l1_withdrawals);

// 3. Ownership consistency
assert(item.owner == recorded_owner);

// 4. Access controls enforced
assert(caller == admin || has_permission(caller));

// 5. Arithmetic safety
assert(result_u256 <= u256::MAX);
assert(a >= b); // before subtraction

// 6. L1 handler authorization
assert(from_address == authorized_l1_contract);

// 7. Signature validity
assert(nonce == current_nonce);
assert(domain_separator == expected_domain);

// 8. No stuck funds
assert(can_withdraw || has_valid_recovery_mechanism);
```

---

## **Severity Classification (Cairo Edition)**

```markdown
## CRITICAL (Immediate fund loss or protocol break)
- Unchecked from_address in L1 handler (token minting)
- Signature forgery/replay allowing unauthorized operations
- L1 bridge vulnerability causing fund theft
- felt252 overflow draining user balances

## HIGH (Significant fund loss or protocol damage)
- L1→L2 address truncation (funds to zero address)
- Message failure without cancellation (locked funds)
- Arithmetic overflow in non-balance calculations
- Access control bypass on admin functions

## MEDIUM (Limited loss or DoS)
- Asymmetric L1/L2 validation (trapped funds)
- Missing events for critical operations
- Gas inefficiency enabling DoS
- Reentrancy with limited impact

## LOW (Minor issues)
- Suboptimal storage access patterns
- Missing input validation on non-critical params
- Code style issues
- Documentation gaps

## INFO (Suggestions)
- Use OpenZeppelin implementations where available
- Consider upgradeability patterns
- Add comprehensive test coverage
```

---

## **Quick Reference Card**

```
┌─────────────────────────────────────────────────────────────────┐
│                 CAIRO AUDIT QUICK REFERENCE                      │
├─────────────────────────────────────────────────────────────────┤
│ 1. FIND ALL ENTRY POINTS:                                       │
│    • #[external(v0)] functions                                  │
│    • #[l1_handler] functions ← CRITICAL PRIORITY                │
│    • #[constructor]                                             │
│                                                                 │
│ 2. L1 HANDLER CHECKLIST:                                        │
│    ✓ from_address == authorized_l1_bridge?                      │
│    ✓ ContractAddress params != zero?                            │
│    ✓ Amounts validated and within bounds?                       │
│                                                                 │
│ 3. ARITHMETIC CHECKLIST:                                        │
│    ✓ Using u128/u256 instead of felt252 for balances?          │
│    ✓ a >= b checked before subtraction?                         │
│    ✓ Division denominator != 0?                                 │
│                                                                 │
│ 4. SIGNATURE CHECKLIST:                                         │
│    ✓ Nonce included and incremented?                            │
│    ✓ Domain separator (chain_id + contract)?                    │
│    ✓ Using OpenZeppelin Account?                                │
│                                                                 │
│ 5. L1↔L2 BRIDGE CHECKLIST:                                      │
│    ✓ L1 validates address < STARKNET_PRIME?                     │
│    ✓ Cancellation mechanism exists?                             │
│    ✓ Symmetric validation on both layers?                       │
│                                                                 │
│ 6. TOOLS:                                                       │
│    • Caracal: caracal detect --target ./src                     │
│    • Foundry: snforge test                                      │
│    • Detectors: unchecked-l1-handler-from, unchecked-felt252    │
└─────────────────────────────────────────────────────────────────┘
```

---

## **Phase 8: Protocol-Specific Attack Patterns (Cairo/StarkNet)**

> Adapt these attack categories to the target protocol type. Not all apply to every audit.

### **DeFi Lending (StarkNet)**
```markdown
- [ ] Flash loan integration: Can flash-loaned funds manipulate collateral values?
- [ ] Oracle manipulation: Can price feeds be front-run via sequencer ordering?
- [ ] Liquidation threshold bypass: Can felt252 arithmetic errors skip liquidation?
- [ ] Interest rate manipulation: Are rate calculations safe from rounding abuse?
- [ ] Bad debt socialization: What happens when collateral < debt after felt252 math?
```

### **DEX / AMM (StarkNet)**
```markdown
- [ ] Price manipulation via sequencer: Can sequencer ordering be exploited?
- [ ] LP share calculation: Rounding errors in felt252/u256 mint/burn math?
- [ ] First depositor attack: Can initial LP get inflated shares?
- [ ] Sandwich attacks: Sequencer can observe and reorder transactions
- [ ] Fee calculation: Are fees computed before or after swap in felt252?
```

### **Staking / Farming**
```markdown
- [ ] Reward distribution: Does felt252 division truncate rewards unfairly?
- [ ] Stake/unstake timing: Can users stake just before reward distribution?
- [ ] Reward token draining: Can accumulated rewards be claimed multiple times?
- [ ] Delegation attacks: Can delegated stake be manipulated?
```

### **Bridge (L1↔L2)**
```markdown
- [ ] Message replay: Can L1→L2 messages be consumed multiple times?
- [ ] Message censorship: Can sequencer censor specific L1 messages?
- [ ] Fund locking: What if L2→L1 message is never consumed on L1?
- [ ] Address spoofing: Can from_address in l1_handler be forged?
- [ ] Withdrawal race: Multiple withdrawal requests for same deposit?
```

### **NFT / Marketplace**
```markdown
- [ ] Royalty bypass: Can royalties be circumvented via direct transfer?
- [ ] Metadata manipulation: Can metadata URI be changed after mint?
- [ ] Approval front-running: Can approvals be exploited before transfer?
- [ ] Enumeration DoS: Can large collections cause gas issues?
```

### **Governance**
```markdown
- [ ] Vote manipulation: Can votes be double-counted across snapshots?
- [ ] Proposal execution: Can malicious proposals bypass timelock?
- [ ] Quorum gaming: Can quorum be reached with flash-loaned tokens?
- [ ] Delegation abuse: Can delegated votes be redirected mid-vote?
```

---

## **Phase 9: Validation & Verification**

### **Step 9.1: False Positive Elimination (Cairo-Specific)**
Before finalizing ANY finding, run these Cairo-specific checks:

```markdown
## Cairo False Positive Checklist
- [ ] **felt252 wrapping**: Did I verify the arithmetic actually wraps in practice, not just in theory?
- [ ] **Storage default**: Is the zero default value actually dangerous, or is it handled upstream?
- [ ] **L1↔L2 validation**: Is the l1_handler actually callable without validation, or does the L1 contract restrict callers?
- [ ] **Reentrancy**: Does the external call actually allow reentry, or does StarkNet's execution model prevent it in this case?
- [ ] **Sequencer ordering**: Is the sequencer actually adversarial, or is there a fair ordering mechanism?
- [ ] **Access control**: Is the function really unprotected, or is there a component/trait providing access control?
- [ ] **Gas feasibility**: Can the attack actually complete within StarkNet's gas limits?
```

### **Step 9.2: Impact Assessment Template**
```markdown
## Impact Assessment for [Finding Title]

**Direct Impact:**
- Funds at risk: [exact amount or formula]
- Users affected: [all / subset / admin only]
- Reversibility: [reversible / irreversible / requires upgrade]

**Cairo-Specific Impact:**
- Storage corruption: [permanent / recoverable via migration]
- L1↔L2 state: [L1 side affected? L2 side affected? Both?]
- Contract upgradeability: [can be fixed via proxy upgrade?]

**Severity Justification:**
- Likelihood: [High/Medium/Low] — [reasoning]
- Impact: [High/Medium/Low] — [reasoning]
- Final: [CRITICAL/HIGH/MEDIUM/LOW]
```

### **Step 9.3: Submission Checklist**
```markdown
## Pre-Submission Verification
- [ ] Finding passes ALL 4 mandatory validation checks
- [ ] Attack scenario is step-by-step reproducible
- [ ] PoC test code compiles (or is clearly pseudocode marked as such)
- [ ] Fix recommendation is specific and correct
- [ ] Severity matches the impact assessment
- [ ] No speculative language ("might", "could potentially")
- [ ] Code references include exact file, function, and line numbers
- [ ] Cairo-specific category is correctly identified
- [ ] ClaudeSkills pattern reference included if applicable
```

---

## **Final Pro Tips**

```markdown
## 10 Cairo Audit Pro Tips

1. **felt252 subtraction is your #1 target.** Unlike Solidity's SafeMath era, Cairo's
   felt252 wraps silently. Every subtraction is a potential critical finding.

2. **l1_handler = open front door.** Treat every l1_handler as an external function
   callable by anyone who can send an L1 message. The from_address is the ONLY
   way to validate the caller.

3. **Storage is a hash map — think collisions.** Pedersen hash-based storage addressing
   means LegacyMap keys must be carefully namespaced.

4. **get_caller_address() returns 0 from sequencer.** If your access control uses
   get_caller_address(), test what happens when it returns zero.

5. **Cairo reentrancy is real.** Unlike some chains, StarkNet allows reentrancy via
   external contract calls. Always check CEI (Checks-Effects-Interactions) pattern.

6. **Read the Scarb.toml first.** Dependencies tell you what components are used.
   OpenZeppelin? Custom access control? This shapes your attack surface.

7. **Trace the money, not the code.** In DeFi audits, follow the token flow:
   where do tokens enter, where are they stored, and how do they exit?

8. **Check assert vs panic.** Cairo's `assert` triggers a panic on failure —
   but does the contract handle this gracefully in all contexts?

9. **Proxy contracts change everything.** If the contract is upgradeable via a proxy,
   the admin key is the most critical finding. Who holds it?

10. **Cross-reference L1 and L2.** Bridge vulnerabilities exist at the boundary.
    Read both the Solidity L1 contract and the Cairo L2 handler together.
```

## **Audit Completion Checklist**

```markdown
## Final Review Before Submission

### Coverage
- [ ] ALL #[external(v0)] functions analyzed
- [ ] ALL l1_handler functions analyzed
- [ ] ALL storage variables mapped
- [ ] Cross-contract calls traced
- [ ] Event emissions verified

### Cairo-Specific
- [ ] felt252 arithmetic checked in ALL paths
- [ ] Storage key isolation verified
- [ ] L1↔L2 message flow validated end-to-end
- [ ] Reentrancy analysis complete
- [ ] Access control audit complete (including zero caller)

### Finding Quality
- [ ] Each finding passes all 4 validation checks
- [ ] Each finding has concrete attack scenario
- [ ] Each finding has specific fix recommendation
- [ ] No speculative findings remain
- [ ] Severity classifications are defensible

### Deliverables
- [ ] All findings formatted per template
- [ ] Executive summary prepared
- [ ] Risk matrix populated
- [ ] Recommendations prioritized
```

---

## 📚 **Learning Resources**

### Essential Reading
1. **Cairo Book**: https://book.cairo-lang.org/
2. **StarkNet Documentation**: https://docs.starknet.io/
3. **OpenZeppelin Cairo**: https://github.com/OpenZeppelin/cairo-contracts
4. **Trail of Bits Cairo Patterns**: building-secure-contracts/not-so-smart-contracts/cairo/
5. **StarkNet Security**: https://docs.starknet.io/documentation/architecture_and_concepts/Security/

### Tools
1. **Caracal**: https://github.com/crytic/caracal
2. **Starknet Foundry**: https://foundry-rs.github.io/starknet-foundry/
3. **Cairo-lint**: https://github.com/keep-starknet-strange/cairo-lint

### Practice
1. **StarkNet by Example**: https://starknet-by-example.voyager.online/
2. **Damn Vulnerable DeFi - StarkNet**: (if available)
3. **Past Audit Reports**: Search for StarkNet protocol audits
