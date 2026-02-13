# Go Smart Contract Audit Framework

> **A complete, standalone methodology for auditing Go-based blockchain applications**
> **Version 2.0** — Enhanced with binding architecture and ClaudeSkills vulnerability patterns.

This framework provides structured audit workflows for **Cosmos SDK**, **Tendermint/CometBFT ABCI**, and general Go blockchain applications. It is designed to work independently while following the same philosophical approach as the Solidity and Rust frameworks.

### Binding Architecture (v2.0)
The CommandInstruction now enforces structured audit behavior through:
- **AUTHORITATIVE SOURCES** — Document hierarchy that governs LLM behavior
- **CORE RULES OF ENGAGEMENT** — 5 non-negotiable rules
- **PRE-ANALYSIS VERIFICATION** — Silent checklist before any output
- **AUDITOR'S MINDSET** — 6 Go/Cosmos-specific lenses (Pointer & Reference Hunting, Error Path Paranoia, Zero Value Exploitation, Module Boundary Thinking, State Consistency Analysis, Economic Attack Surface)

### ClaudeSkills Integration
Vulnerability patterns from `ClaudeSkills/plugins/building-secure-contracts/skills/cosmos-vulnerability-scanner/` are integrated throughout the methodology (patterns C1–C6), providing specific detection commands and vulnerable/secure code examples.

---

## 🎯 What This Framework Provides

| Component | Purpose |
|-----------|---------|
| **Audit_Assistant_Playbook_Go.md** | Cognitive framework — how to structure LLM conversations |
| **CommandInstruction-Go.md** | System prompt — copy into new audit chats |
| **Go-Smart-Contract-Audit-Methodology.md** | Methodology — checklists, phases, attack patterns |

---

## 📁 Framework Structure

```
Go-SmartContract/
├── README.md                              # This file
├── Audit_Assistant_Playbook_Go.md         # LLM conversation structure
├── CommandInstruction-Go.md               # System prompt for audit sessions
└── Go-Smart-Contract-Audit-Methodology.md # Audit methodology & checklists
```

---

## 🚀 Quick Start

### 1. Prepare Your Codebase

Build a single merged file with all in-scope Go code:

```bash
# Navigate to your project
cd /path/to/cosmos-module

# Create merged.txt
(
  echo "INDEX"
  find . -name "*.go" -type f ! -path "./vendor/*" ! -name "*_test.go" | sort
  echo ""
  echo "=== GO.MOD ==="
  cat go.mod
  echo ""
  echo "=== SOURCE FILES ==="
  find . -name "*.go" -type f ! -path "./vendor/*" ! -name "*_test.go" | sort | while read f; do
    echo "FILE: $f"
    cat "$f"
    echo "END FILE: $f"
    echo ""
  done
) > merged.txt
```

### 2. Start Your Audit Session

1. Open a new LLM chat
2. Pin `merged.txt` and any project documentation
3. Copy the entire content of `CommandInstruction-Go.md` as the system prompt
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

## 🔵 Go-Specific Focus Areas

### Pointer vs Value Semantics
- Track pointer receivers (`*Type`) vs value receivers
- Identify mutations before validation
- Check for pointer aliasing (shared state)

### Error Handling
- Flag all ignored errors (`_, _ :=`)
- Check for `panic()` in production paths
- Verify error wrapping with `sdkerrors.Wrap()`

### Zero Value Safety
- Flag zero-value structs treated as valid
- Check `nil` returns from `store.Get()`
- Verify default values are safe

### Gas & DoS
- Flag unbounded `Iterator()` calls
- Check slice/map growth in loops
- Identify expensive crypto operations

---

## 🔗 Framework-Specific Considerations

### Cosmos SDK
- Message handlers: `func (k Keeper) HandleMsg*(ctx sdk.Context, msg *types.Msg*)`
- Module keepers and cross-keeper calls
- Bank module interactions
- IBC packet handling and callbacks
- Governance proposals and upgrades

### Tendermint/CometBFT
- ABCI interface: `CheckTx`, `DeliverTx`, `BeginBlock`, `EndBlock`
- Validator set management
- Evidence handling
- Light client verification

### IBC Protocol
- Packet lifecycle: `SendPacket`, `OnRecvPacket`, `OnAcknowledgement`, `OnTimeout`
- Channel and connection handshakes
- Client updates and misbehavior

---

## 📋 Semantic Phases (Go Edition)

| Phase | Go Indicators | Key Questions |
|-------|---------------|---------------|
| **VALIDATION** | `ValidateBasic()`, early `if` checks | All fields validated? Signatures checked? |
| **SNAPSHOT** | `k.Get*()`, `store.Get()` | Zero values handled? Nil returns checked? |
| **ACCOUNTING** | `ctx.BlockTime()`, oracle queries | Time manipulation? Rounding errors? |
| **MUTATION** | `store.Set()`, pointer modification | Value conserved? Pointer safety? |
| **COMMIT** | `Save*()`, protobuf marshaling | Atomic writes? Gas accounted? |
| **EVENTS** | `EmitEvent()`, `EmitTypedEvent()` | All changes logged? Safe attributes? |
| **ERROR** | `return nil, err`, `panic()` | State rolled back? Cleanup done? |

---

## 🚨 Universal Red Flags

```go
// 1. Pointer modification before validation
pos.Amount = pos.Amount.Add(delta)
if pos.Amount.IsNegative() { return err }  // Too late!

// 2. Zero value as valid state
if pos == nil { return types.Position{} }  // Is {} valid?

// 3. Ignored error
result, _ := k.doSomething(ctx)

// 4. Panic in handler
data := k.mustGet(ctx, id)

// 5. Unbounded iteration
iter := store.Iterator(nil, nil)

// 6. Type assertion without check
m := msg.(*types.MsgUpdate)  // Panic if wrong type!
```

---

## 📚 Known Exploit Database

### Cosmos SDK / IBC
- **Dragonberry (2022)**: ICS-23 proof verification bypass
- **Jackfruit (2022)**: Height offset in IBC client
- **Huckleberry (2022)**: Vesting account mishandling
- **Elderflower (2022)**: Bank module prefix bypass

### Cosmos DeFi
- **Osmosis (2022)**: LP share calculation rounding
- **Umee (2023)**: Collateral factor manipulation
- **Mars Protocol (2023)**: Liquidation threshold bypass
- **Crescent (2022)**: AMM price manipulation

---

## ✅ Validation Checklist

Before confirming ANY finding, verify:

| Check | Question |
|-------|----------|
| **Reachability** | Is handler registered? Is message routed? |
| **State Freshness** | Works with realistic KV store state? |
| **Execution Closure** | All external calls modeled? |
| **Economic Realism** | Attack economically viable? |

---

## 🎓 Recommended Workflow

```
Day 1: Exploration
├── Build merged.txt
├── Run Protocol Mapper
├── Understand keeper structure
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
| Rust Framework | `../RustBaseSmartContract/` |
| Main Playbook (Solidity) | `../Audit_Assistant_Playbook.md` |

---

## 🔧 Tooling Commands

```bash
# Find message handlers
grep -rn "func (k Keeper)" --include="*.go" | grep "Msg\|Handle"

# Find functions with sdk.Context
grep -rn "sdk.Context" --include="*.go" | grep "func"

# Find potential panics
grep -rn "panic(\|must" --include="*.go"

# Find ignored errors
grep -rn "_, _ :=\|_ =" --include="*.go"

# Find unbounded iterations
grep -rn "Iterator(nil, nil)" --include="*.go"

# Count SLOC
find . -name "*.go" ! -name "*_test.go" -exec wc -l {} + | tail -1

# Run security scanner
gosec ./...

# Run race detector
go test -race ./...
```

---

## 📝 License

This framework is provided for educational and professional use in smart contract security auditing.

---

**Framework Version:** 2.0  
**Last Updated:** February 2026  
**Target Ecosystems:** Cosmos SDK, Tendermint, CometBFT, IBC, General Go  
**Enhanced with:** ClaudeSkills Trail of Bits patterns (C1–C6), InfoSec_Us_Team methodology
