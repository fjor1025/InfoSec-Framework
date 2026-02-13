# Audit Assistant Playbook

A cognitive playbook for experienced smart contract auditors.

This is NOT an automated audit tool.
It does NOT replace auditor judgment.
It structures how auditors think, explore, validate, and report findings.

## What Makes This Framework Work

Every framework enforces a **binding architecture** that prevents the LLM from "chatting" instead of auditing:

1. **AUTHORITATIVE SOURCES** — Declares which documents govern behavior (hierarchy)
2. **CORE RULES OF ENGAGEMENT** — 5 non-negotiable rules (evidence-only, methodology adherence, output format, scope discipline, validation before confirmation)
3. **PRE-ANALYSIS VERIFICATION** — Checklist the LLM must silently pass before generating any output
4. **MANDATORY VALIDATION CHECKS** — 4 checks every finding must pass (Reachability, State Freshness, Execution Closure, Economic Realism)
5. **AUDITOR'S MINDSET** — 6 ecosystem-specific lenses applied to every function

Without this architecture, the LLM treats methodology as optional. With it, the LLM is forced into structured audit behavior.

## Repository Structure

```
audit-assistant-playbook/
├── README.md                              <- This file
├── report-writing.md                      <- Universal report writing guide
├── VULNERABILITY_PATTERNS_INTEGRATION.md  <- ClaudeSkills integration status
│
├── SolidityEVM/                           <- Solidity/EVM Framework (Benchmark)
│   ├── Audit_Assistant_Playbook.md        <- Conversation structure & prompts (Sections 1–10)
│   ├── CommandInstruction.md              <- System prompt (binding architecture)
│   ├── audit-workflow1.md                 <- Manual audit methodology
│   └── audit-workflow2.md                 <- Semantic phase analysis
│
├── RustBaseSmartContract/                 <- Rust Framework (CosmWasm / Solana / Substrate)
│   ├── README.md
│   ├── Audit_Assistant_Playbook_Rust.md   <- Sections 1–10
│   ├── CommandInstruction-Rust.md         <- Binding architecture + 6 Rust lenses
│   └── Rust-Smartcontract-workflow.md     <- Methodology + ClaudeSkills Solana/Substrate patterns
│
├── Go-SmartContract/                      <- Go Framework (Cosmos SDK / IBC)
│   ├── README.md
│   ├── Audit_Assistant_Playbook_Go.md     <- Sections 1–10
│   ├── CommandInstruction-Go.md           <- Binding architecture + 6 Go/Cosmos lenses
│   └── Go-Smart-Contract-Audit-Methodology.md <- Methodology + ClaudeSkills C1–C6 patterns
│
├── Cairo-StarkNet/                        <- Cairo Framework (StarkNet L2)
│   ├── README.md
│   ├── Audit_Assistant_Playbook_Cairo.md  <- Sections 1–10
│   ├── CommandInstruction-Cairo.md        <- Binding architecture + 6 Cairo lenses
│   └── Cairo-Audit-Methodology.md         <- Methodology + ClaudeSkills Cairo patterns
│
├── Algorand-PyTeal/                       <- Algorand Framework (PyTeal / TEAL)
│   ├── README.md
│   ├── Audit_Assistant_Playbook_Algorand.md <- Sections 1–10
│   ├── CommandInstruction-Algorand.md     <- Binding architecture + 6 Algorand lenses
│   └── Algorand-Audit-Methodology.md      <- Methodology + ClaudeSkills A1–A9 patterns
│
└── ClaudeSkills/                          <- Trail of Bits vulnerability patterns (submodule)
    └── plugins/building-secure-contracts/skills/
        ├── solana-vulnerability-scanner/   <- Integrated → Rust Framework
        ├── cosmos-vulnerability-scanner/   <- Integrated → Go Framework
        ├── substrate-vulnerability-scanner/<- Integrated → Rust Framework
        ├── cairo-vulnerability-scanner/    <- Integrated → Cairo Framework
        ├── algorand-vulnerability-scanner/ <- Integrated → Algorand Framework
        └── ton-vulnerability-scanner/      <- Available (no framework yet)
```

## Framework Overview

Each framework follows the same 3-file architecture, adapted for its ecosystem:

| File | Purpose | Key Content |
|------|---------|-------------|
| **CommandInstruction** | System prompt (binding architecture) | AUTHORITATIVE SOURCES, CORE RULES, PRE-ANALYSIS VERIFICATION, AUDITOR'S MINDSET, Red Flags, Invariants |
| **Methodology/Workflow** | Audit phases & checklists | Entry points, semantic classification, protocol-specific attacks, validation & verification, pro tips |
| **Playbook** | Conversation structure & prompts | Sections 1–10: Build, Main, Exploration, Working, Drafting, Scope Index, Review, SCAN, Hypotheses, Scope Transfer |

### Framework Comparison

| Framework | Lines | Sections | ClaudeSkills Patterns | Ecosystem Lenses |
|-----------|-------|----------|----------------------|-----------------|
| **Solidity/EVM** | ~2,492 | 1–10 | Benchmark (original) | Storage hunting, proxy thinking, flash loan, reentrancy, oracle, access control |
| **Rust** | ~3,017 | 1–10 | Solana + Substrate | Ownership tracking, unsafe hunting, panic safety, cross-contract, state consistency, arithmetic |
| **Go/Cosmos** | ~3,354 | 1–10 | Cosmos C1–C6 | Pointer hunting, error paranoia, zero value, module boundary, state consistency, economic surface |
| **Cairo/StarkNet** | ~2,703 | 1–10 | Cairo C1–C6 | felt252 thinking, storage hunting, L1↔L2 surface, reentrancy, serialization, access control |
| **Algorand/PyTeal** | ~2,456 | 1–10 | Algorand A1–A9 | Transaction field hunting, group thinking, inner tx fee, clear state paranoia, smart sig, asset opt-in |

### ClaudeSkills Integration

All vulnerability patterns from `ClaudeSkills/plugins/building-secure-contracts/skills/` are integrated:

| ClaudeSkills Scanner | Patterns | Integrated Into | Key Additions |
|---------------------|----------|-----------------|---------------|
| Solana | 670+ lines | Rust CommandInstruction + Methodology | CPI, PDA, ownership, signer checks |
| Cosmos | 741+ lines | Go CommandInstruction + Methodology | GetSigners, non-determinism, ABCI panic/slow, bookkeeping |
| Substrate | 792+ lines | Rust CommandInstruction + Methodology | Weights/fees, verify-first, unsigned validation |
| Cairo | 723+ lines | Cairo CommandInstruction + Methodology | felt252, L1 handler, storage layout, signature replay |
| Algorand | 406+ lines | Algorand CommandInstruction + Methodology | Rekey, close, group size, inner tx fee, clear state |

## Key Concepts (Universal)

### Semantic Phases
Every function in every ecosystem is classified by what it does:

| Phase | Purpose | Cross-Ecosystem Examples |
|-------|---------|------------------------|
| **VALIDATION** | Input checking, permissions | `require()`, `ValidateBasic()`, `assert!()`, transaction field checks |
| **SNAPSHOT** | State reads, data loading | `SLOAD`, `store.Get()`, `.load()`, `App.globalGet()` |
| **ACCOUNTING** | Calculations | `block.timestamp`, `ctx.BlockTime()`, `get_block_timestamp()` |
| **MUTATION** | State changes | `balance[x] = y`, `store.Set()`, `&mut self`, `App.globalPut()` |
| **COMMIT** | Persistent writes | `SSTORE`, `save()`, `store.Set()`, state writes |
| **EVENTS** | Logging | `emit Event()`, `EmitEvent()`, `self.emit()`, log entries |
| **ERROR** | Failure handling | `revert`, `return err`, `Result::Err`, `Reject()` |

### Validation Checks (All Findings Must Pass)

| Check | Question |
|-------|----------|
| **Reachability** | Can this path actually execute on-chain? |
| **State Freshness** | Works with current/realistic state? |
| **Execution Closure** | All external calls modeled? |
| **Economic Realism** | Attack cost/timing feasible? |

## Quick Start

### For Solidity Audits
1. Read [Audit_Assistant_Playbook.md](./SolidityEVM/Audit_Assistant_Playbook.md)
2. Use [CommandInstruction.md](./SolidityEVM/CommandInstruction.md) as system prompt
3. Follow [audit-workflow1.md](./SolidityEVM/audit-workflow1.md) + [audit-workflow2.md](./SolidityEVM/audit-workflow2.md)

### For Rust Audits (CosmWasm / Solana / Substrate)
1. Read [Audit_Assistant_Playbook_Rust.md](./RustBaseSmartContract/Audit_Assistant_Playbook_Rust.md)
2. Use [CommandInstruction-Rust.md](./RustBaseSmartContract/CommandInstruction-Rust.md) as system prompt
3. Follow [Rust-Smartcontract-workflow.md](./RustBaseSmartContract/Rust-Smartcontract-workflow.md)

### For Go Audits (Cosmos SDK / IBC)
1. Read [Audit_Assistant_Playbook_Go.md](./Go-SmartContract/Audit_Assistant_Playbook_Go.md)
2. Use [CommandInstruction-Go.md](./Go-SmartContract/CommandInstruction-Go.md) as system prompt
3. Follow [Go-Smart-Contract-Audit-Methodology.md](./Go-SmartContract/Go-Smart-Contract-Audit-Methodology.md)

### For Cairo/StarkNet Audits
1. Read [Audit_Assistant_Playbook_Cairo.md](./Cairo-StarkNet/Audit_Assistant_Playbook_Cairo.md)
2. Use [CommandInstruction-Cairo.md](./Cairo-StarkNet/CommandInstruction-Cairo.md) as system prompt
3. Follow [Cairo-Audit-Methodology.md](./Cairo-StarkNet/Cairo-Audit-Methodology.md)

### For Algorand/PyTeal Audits
1. Read [Audit_Assistant_Playbook_Algorand.md](./Algorand-PyTeal/Audit_Assistant_Playbook_Algorand.md)
2. Use [CommandInstruction-Algorand.md](./Algorand-PyTeal/CommandInstruction-Algorand.md) as system prompt
3. Follow [Algorand-Audit-Methodology.md](./Algorand-PyTeal/Algorand-Audit-Methodology.md)

## Report Writing

See [report-writing.md](./report-writing.md) for the universal report writing guide.
The guide teaches narrative-driven reporting that communicates with judges — not form-filling.

## Who This Is For
- Experienced smart contract auditors
- Security researchers doing manual audits
- Auditors working with LLM assistants

## Who This Is NOT For
- Beginners learning smart contract development
- Automated vulnerability scanning
- "Run once and get bugs" workflows

---

**Framework Version:** 2.0
**Last Updated:** February 2026
**License:** MIT
