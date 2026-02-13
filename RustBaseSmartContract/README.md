# Rust Smart Contract Audit Framework

> **A complete, standalone methodology for auditing Rust-based smart contracts**

This framework provides structured audit workflows for **CosmWasm**, **Solana/Anchor**, **Substrate**, and general Rust smart contracts. It is designed to work independently of the Solidity framework while following the same philosophical approach.

---

## 🎯 What This Framework Provides

| Component | Purpose |
|-----------|---------|
| **Audit_Assistant_Playbook_Rust.md** | Cognitive framework — how to structure LLM conversations |
| **CommandInstruction-Rust.md** | System prompt — copy into new audit chats |
| **Rust-Smartcontract-workflow.md** | Methodology — checklists, phases, attack patterns |

---

## 📁 Framework Structure

```
RustBaseSmartContract/
├── README.md                           # This file
├── Audit_Assistant_Playbook_Rust.md    # LLM conversation structure
├── CommandInstruction-Rust.md          # System prompt for audit sessions
└── Rust-Smartcontract-workflow.md      # Audit methodology & checklists
```

---

## 🚀 Quick Start

### 1. Prepare Your Codebase

Build a single merged file with all in-scope Rust code:

```bash
# Navigate to your project
cd /path/to/rust-contract

# Create merged.txt
(
  echo "INDEX"
  find src -name "*.rs" -type f | sort
  echo ""
  find src -name "*.rs" -type f -exec sh -c '
    echo "FILE: {}"
    cat "{}"
    echo "END FILE: {}"
    echo ""
  ' sh {} +
) > merged.txt
```

### 2. Start Your Audit Session

1. Open a new LLM chat
2. Pin `merged.txt` and any project documentation
3. Copy the entire content of `CommandInstruction-Rust.md` as the system prompt
4. Begin with the Protocol Mapper role

### 3. Follow the Audit Lifecycle

```
[1] Exploration      → Understand the protocol (Protocol Mapper)
[2] Hypothesis       → Generate attack scenarios (Hypothesis Generator)  
[3] Validation       → Test hypotheses (Code Path Explorer)
[4] Deep Analysis    → Working chat for survivors
[5] Review           → Adversarial review before reporting
```

---

## 🦀 Rust-Specific Focus Areas

### Ownership & Borrowing
- Track `&` vs `&mut` vs owned throughout functions
- Identify unnecessary `.clone()` calls
- Map data flow and ownership transfers

### Panic Safety
- Flag all `.unwrap()` and `.expect()` in production code
- Check index access without bounds verification
- Verify `match` exhaustiveness

### Arithmetic Safety
- Require `checked_add`, `checked_sub`, `checked_mul`, `checked_div`
- Or use `saturating_*` methods where appropriate
- Check for division by zero

### Error Handling
- Trace `?` operator early returns
- Verify state cleanup on error paths
- Check for partial state updates on failure

---

## 🔗 Framework-Specific Considerations

### CosmWasm
- Entry points: `instantiate`, `execute`, `query`, `migrate`, `reply`
- IBC callback handling
- Submessage failure propagation
- Storage key management (`cw-storage-plus`)

### Solana (Anchor)
- Account validation and constraints
- PDA derivation and seed management
- CPI (Cross-Program Invocation) privileges
- Rent-exempt balance requirements

### Substrate
- Extrinsic weight calculation
- Storage migrations
- Pallet interactions and hooks
- Governance and upgrade paths

---

## 📋 Semantic Phases (Rust Edition)

| Phase | Rust Indicators | Key Questions |
|-------|-----------------|---------------|
| **SNAPSHOT** | `&self`, `load`, `get`, `clone` | Cloning too much? Atomic reads? |
| **VALIDATION** | `ensure!`, `assert!`, `?`, error arms | Can be bypassed? All paths covered? |
| **ACCOUNTING** | `env.block.*`, time, fees | Time manipulation? Rounding errors? |
| **MUTATION** | `&mut self`, `insert`, arithmetic | Value conserved? Overflow risks? |
| **COMMIT** | `save`, `store`, events | All changes persisted? Events correct? |
| **ERROR** | `Result`, `Option`, `unwrap` | State corrupted on error? Cleanup? |

---

## 🚨 Universal Red Flags

```rust
// 1. Unchecked arithmetic
balance + amount  // → use checked_add

// 2. Panic in production
data.unwrap()  // → use ok_or(Error)?

// 3. Unbounded iteration
for item in items.iter() { }  // → add pagination

// 4. Missing access control
pub fn admin_fn(&mut self) { }  // → check sender

// 5. External call before state update
call_external()?;
self.balance -= amount;  // → update first

// 6. Clone in loop
for x in vec.iter() { x.clone() }  // → use references
```

---

## 📚 Known Exploit Database

### CosmWasm
- **Astroport (2023)**: Integer overflow in LP tokens
- **Anchor Protocol (2022)**: Exchange rate manipulation
- **Mirror Protocol (2021)**: Oracle staleness

### Solana
- **Wormhole (2022)**: Signature verification bypass
- **Cashio (2022)**: Missing signer validation
- **Mango Markets (2022)**: Oracle manipulation

### Substrate
- **Acala (2022)**: aUSD mint misconfiguration
- **Moonbeam**: XCM validation issues

---

## ✅ Validation Checklist

Before confirming ANY finding, verify:

| Check | Question |
|-------|----------|
| **Reachability** | Can this path execute on-chain? |
| **State Freshness** | Works with realistic current state? |
| **Execution Closure** | All external calls modeled? |
| **Economic Realism** | Attack economically viable? |

---

## 🎓 Recommended Workflow

```
Day 1: Exploration
├── Build merged.txt
├── Run Protocol Mapper
├── Understand state management
└── Note complexity areas

Day 2-3: Hypothesis & Validation
├── Run Hypothesis Generator
├── Validate top priorities with Code Path Explorer
├── Kill or promote each hypothesis
└── Document survivors

Day 4: Deep Analysis & Review
├── Working chat for complex issues
├── Adversarial review before reporting
└── Draft findings with PoC
```

---

## 📖 Companion Resources

| Resource | Location |
|----------|----------|
| Solidity Framework | `../InfoSec/` |
| Main Playbook (Solidity) | `../Audit_Assistant_Playbook.md` |
| Report Writing Guide | `../InfoSec/report-writing.md` |

---

## 🔧 Tooling Commands

```bash
# Find ALL public functions (entry points + internal)
grep -rn "pub fn\|pub(crate) fn" src/ | grep -v "test\|#\[cfg(test" | head -50

# Find state-changing functions
grep -rn "&mut self\|&mut deps\|DepsMut" src/ | grep "pub fn" | head -30

# Find blockchain entry points
grep -rn "#\[entry_point\]\|#\[program\]\|#\[pallet::call\]" src/

# Find functions that move funds
grep -rn "transfer\|send\|withdraw\|deposit\|mint\|burn\|stake\|claim" src/ | grep "pub fn"

# Find .unwrap()/.expect() — potential panic DoS vectors
grep -rn "\.unwrap()\|\.expect(" src/ | grep -v test | grep -v "// safe"

# Find unchecked arithmetic
grep -rn "[^_]+ [0-9]\|[^_]- [0-9]\|[^_]\* [0-9]" src/ | grep -v "checked_\|saturating_\|test"

# Find unsafe blocks
grep -rn "unsafe" src/ | grep -v test

# Find external calls (cross-contract)
grep -rn "WasmMsg\|SubMsg\|invoke\|invoke_signed\|CpiContext\|T::Currency" src/

# Find admin/privileged functions
grep -rn "admin\|owner\|authority\|migrate\|upgrade\|pause" src/ | grep "pub fn"

# Count SLOC
find src -name "*.rs" -exec wc -l {} + | sort -rn | head -20

# Quick danger map (run this first!)
echo "=== PANIC POINTS ==="  && grep -c "\.unwrap()\|\.expect(" src/*.rs 2>/dev/null
echo "=== UNSAFE BLOCKS ===" && grep -c "unsafe" src/*.rs 2>/dev/null
echo "=== ADMIN FUNCTIONS ==" && grep -c "admin\|owner\|authority" src/*.rs 2>/dev/null
```

---

## 📝 License

This framework is provided for educational and professional use in smart contract security auditing.

---

**Framework Version:** 2.0  
**Last Updated:** February 2026  
**Target Ecosystems:** CosmWasm, Solana/Anchor, Substrate, General Rust  
**Enhanced with:** ClaudeSkills Trail of Bits patterns, InfoSec_Us_Team methodology
