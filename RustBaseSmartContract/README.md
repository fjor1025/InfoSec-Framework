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
- Account validation and constraints (19 solana-fender analyzer patterns)
- PDA derivation, seed management, and seed collision prevention
- CPI (Cross-Program Invocation) privileges and program ID validation
- Rent-exempt balance requirements
- Account lifecycle (initialization, reinitialization, closing)
- Type cosplay / account confusion (discriminator validation)
- Account reloading after CPI (stale data prevention)
- Instruction introspection (relative vs absolute indexing)
- Insecure randomness detection
- Initialization frontrunning prevention
- x-ray SVE (Solana Vulnerability Enumeration) coverage
- OWASP Solana Programs Top 10 mapping

### Solana Safe Builder (Frank Castle / SSB)
Builder-side secure coding patterns from 70+ Rust audits and 250+ Critical/High findings:
- **Risk Assessment** — classify every program as 🟢 Low / 🟡 Medium / 🔴 Critical before auditing
- **Account & Identity Validation** — 6 mandatory checks (signer, ownership, data matching, type cosplay, reinitialization, writable)
- **CPI Safety Surface** — SSB-CPI-1 through SSB-CPI-8 (validate program IDs, reload stale data, signer pass-through, SOL balance checks, post-CPI ownership, error propagation, invoke vs invoke_signed, blast radius)
- **Anchor-Specific Pitfalls** — SSB-ANC-1 through SSB-ANC-9 (UncheckedAccount CHECK, init_if_needed, has_one, seeds+bump, realloc+zero_init, transfer_checked, reload(), access_control, close)
- **Native Rust 6-Step Validation** — key → owner → signer → writable → discriminator → data
- **Token-2022 Compatibility** — enforce `transfer_checked` over legacy `token::transfer`
- **Curiosity Principle** — 6 adversarial questions for every account input
- Detection patterns: SSB1–SSB8 (see Rust-Smartcontract-workflow.md Step 6.7)

### Substrate
- Extrinsic weight calculation
- Storage migrations
- Pallet interactions and hooks
- Governance and upgrade paths

### General Rust Safety (Awesome-Rust-Checker)
Applicable to **all** Rust codebases regardless of blockchain framework:
- **Unsafe code soundness** — Send/Sync trait bounds, UnsafeDataflow (panic safety), UnsafeDestructor
- **Concurrency safety** — self-deadlock, lock-order inversion, condvar misuse, atomic TOCTOU
- **Memory safety** — use-after-free, invalid free, double-free, memory leaks
- **Verification** — taint analysis, constant-time verification, reachable panics
- Detection patterns: RUST1–RUST10 (see Rust-Smartcontract-workflow.md Step 6.6)

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
- **Wormhole (2022)**: Signature verification bypass [SVE-1001]
- **Cashio (2022)**: Missing signer + ownership validation [SVE-1001/1002]
- **Mango Markets (2022)**: Oracle manipulation + self-liquidation
- **Jet Protocol v1 (2021)**: Incorrect break vs continue [SVE-2001]
- **Crema Finance (2022)**: Flash loan + CPI price manipulation [SVE-1016]
- **spl-token-swap**: Incorrect checked_div vs ceil_div [SVE-2004]
- **Raydium (2022)**: Insufficient account validation [SVE-1007]
- **Nirvana Finance (2022)**: Flash loan + unchecked mint [SVE-1002]

### Substrate
- **Acala (2022)**: aUSD mint misconfiguration
- **Moonbeam**: XCM validation issues

### Solana (Frank Castle / SSB Reference Exploits)
- **Wormhole-class**: CPI signer pass-through — attacker account forwarded as signer [SSB-CPI-3]
- **Cashio-class**: Missing account ownership + reinitialization guard [SSB-ANC-2]
- **SOL balance drain**: CPI to system_program::transfer drains excess lamports [SSB-CPI-4]
- **Post-CPI ownership change**: `assign()` after CPI changes account owner [SSB-CPI-5]
- **Token-2022 DoS**: Legacy `token::transfer` fails on Token-2022 mints [SSB-ANC-6]
- **Global vault blast radius**: Single PDA vault for all users, one exploit drains all [SSB-CPI-8]
- See: [safe-solana-builder](https://github.com/FrankCastle-0x/safe-solana-builder)

### General Rust (Rudra CVEs)
- **76 CVEs discovered** across the Rust ecosystem via Send/Sync variance analysis
- **hyper (CVE-2021-32714)**: UnsafeDataflow — panic safety in unsafe code
- **smallvec, crossbeam, once_cell**: Unsound unsafe impl patterns
- See: [Rudra SOSP 2021 paper](https://dl.acm.org/doi/10.1145/3477132.3483570)

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
| Solidity Framework | `../SolidityEVM/` |
| Main Playbook (Solidity) | `../SolidityEVM/Audit_Assistant_Playbook.md` |
| Report Writing Guide | `../report-writing.md` |
| Cosmos-SDK Framework | `../Cosmos-SDK/` |
| Vulnerability Patterns Integration | `../VULNERABILITY_PATTERNS_INTEGRATION.md` |

---

## Automated Tooling Integration

### solana-fender (AST-based, 19 analyzers)
Static analyzer for Solana/Anchor programs using `syn` crate AST parsing.
Detects: unauthorized access, type cosplay, arbitrary CPI, bump seed issues,
account reloading, closing accounts, duplicate mutable accounts, precision loss,
seed collision, insecure randomness, and more.

```bash
solana-fender analyze --path programs/
```

### x-ray / sec3 (LLVM-IR, SVE IDs)
Compiles Solana Rust programs to LLVM-IR and applies rule-based vulnerability detection.
20+ SVE IDs covering access control, arithmetic, type confusion, PDA security, and program logic.

```bash
x-ray scan --target programs/ --output report.json
```

### OWASP Solana Programs Top 10
Cross-referenced throughout the framework:
1. Integer Overflow | 2. Missing Account Verification | 3. Missing Signer Check |
4. Arithmetic Accuracy | 5. Arbitrary CPI | 6. Account Confusion | 7. Error Not Handled

### Safe Solana Builder (Frank Castle — secure coding patterns)
Knowledge base from 70+ Rust audits distilled into SSB detection patterns.
Covers CPI safety, account validation, Token-2022 compatibility, Anchor pitfalls,
native Rust validation sequences, and adversarial "Curiosity Principle" reasoning.

```
Patterns: SSB1–SSB8 (integrated into Rust-Smartcontract-workflow.md Step 6.7)
Source:   https://github.com/FrankCastle-0x/safe-solana-builder
Usage:    Manual audit checklist — apply SSB patterns during hypothesis generation
```

### Awesome-Rust-Checker (General Rust Safety, 5 tools)
Academic and industry static analyzers for general Rust safety — applicable to all Rust codebases:

| Tool | Detection Focus | Technique | Citation |
|------|----------------|-----------|----------|
| **Rudra** | Send/Sync variance (76 CVEs), panic safety, unsafe destructors | MIR taint + HIR type analysis | SOSP 2021 |
| **lockbud** | Self-deadlock, lock-order inversion, condvar misuse, atomic TOCTOU, UAF, invalid free | MIR-based rustc plugin | TSE 2024 |
| **RAPx** | UAF, double-free, dangling pointers, memory leaks, unsafe API verification | MIR alias analysis + Z3 | Multi-paper |
| **rCanary** | Memory leaks (6 patterns: ManuallyDrop, Box::into_raw, proxy types, container drain, static leak) | Ownership analysis + Z3 | TOSEM |
| **MIRAI** | Reachable panics, taint flow, timing side channels, precondition violations | Abstract interpretation + Z3 | Meta/Facebook |

```bash
# Rudra — Send/Sync + panic safety + unsafe destructors
docker run --rm -v "$(pwd)":/tmp/mount rudra:latest /tmp/mount

# lockbud — concurrency + memory bugs
cargo install --git https://github.com/nicksial/lockbud
cargo lockbud -k deadlock -- --target-dir /tmp/lockbud
cargo lockbud -k memory  -- --target-dir /tmp/lockbud
cargo lockbud -k all     -- --target-dir /tmp/lockbud

# RAPx — SafeDrop + rCanary + Senryx
cargo rapx -F   # SafeDrop (UAF/DF)
cargo rapx -M   # rCanary (memory leaks)
cargo rapx -V   # Senryx (unsafe verification)

# rCanary (standalone) — memory leak detection
cargo rcanary

# MIRAI — abstract interpretation
cargo mirai
MIRAI_FLAGS="--diag=verify" cargo mirai  # strict mode
MIRAI_FLAGS="--constant_time" cargo mirai  # timing side channels
```

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

# General Rust Safety signals (Awesome-Rust-Checker patterns)
echo "=== SEND/SYNC IMPLS ==="  && grep -rn "unsafe impl.*Send\|unsafe impl.*Sync" src/
echo "=== RAW POINTERS ==="    && grep -rn "\*mut\|\*const\|as \*" src/ | grep -v test
echo "=== MAYBE_UNINIT ==="    && grep -rn "MaybeUninit\|assume_init\|mem::uninitialized\|mem::zeroed" src/
echo "=== MANUAL_DROP ==="     && grep -rn "ManuallyDrop\|Box::into_raw\|Box::leak\|Box::from_raw" src/
echo "=== LOCK PATTERNS ==="   && grep -rn "Mutex::new\|RwLock::new\|\.lock()\|\.read()\|\.write()" src/ | grep -v test
echo "=== ATOMICS ==="         && grep -rn "AtomicUsize\|AtomicBool\|Ordering::" src/ | grep -v test
echo "=== PTR_READ ==="        && grep -rn "ptr::read\|ptr::write\|from_raw_parts\|set_len\|transmute" src/
echo "=== DROP IMPLS ==="      && grep -rn "impl.*Drop.*for\|fn drop(" src/
# Safe Solana Builder (SSB) danger map
echo "=== DUPLICATE MUTABLE ==="  && grep -rn "Account<.*>.*Account<" src/ | grep -v test
echo "=== INIT_IF_NEEDED ==="    && grep -rn "init_if_needed" src/
echo "=== LEGACY TRANSFER ==="   && grep -rn "token::transfer\b" src/ | grep -v "transfer_checked"
echo "=== REMAINING_ACCTS ==="   && grep -rn "remaining_accounts" src/ | grep -v test
echo "=== GLOBAL VAULT PDA ==="  && grep -rn "seeds.*=.*b\"vault\"\|seeds.*=.*b\"pool\"" src/
echo "=== REALLOC ==="           && grep -rn "realloc" src/ | grep -v "zero_init"
echo "=== UNCHECKED_ACCT ==="    && grep -rn "UncheckedAccount" src/
echo "=== CPI SIGNERS ==="      && grep -rn "invoke_signed\|CpiContext::new_with_signer" src/```

---

## 📝 License

This framework is provided for educational and professional use in smart contract security auditing.

---

**Framework Version:** 3.2  
**Last Updated:** March 2026  
**Target Ecosystems:** CosmWasm, Solana/Anchor, Substrate, General Rust  
**Enhanced with:** ClaudeSkills Trail of Bits patterns, InfoSec_Us_Team methodology, solana-fender (19 AST analyzers), x-ray SVE detection, OWASP Solana Top 10, Awesome-Rust-Checker (Rudra/lockbud/RAPx/rCanary/MIRAI), Safe Solana Builder (Frank Castle — SSB patterns)
