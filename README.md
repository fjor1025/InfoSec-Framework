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
5. **AUDITOR'S MINDSET** — 6–8 ecosystem-specific lenses applied to every function

Without this architecture, the LLM treats methodology as optional. With it, the LLM is forced into structured audit behavior.

## Repository Structure

```
audit-assistant-playbook/
├── README.md                              <- This file
├── CLAUDE.md                              <- AI agent context (docs-for-humans-and-ai)
├── report-writing.md                      <- Universal report writing guide
├── VULNERABILITY_PATTERNS_INTEGRATION.md  <- ClaudeSkills integration status
├── llms.txt                               <- AI index (page list + descriptions)
├── llms-full.txt                          <- AI ingest (full concatenated content)
│
├── SolidityEVM/                           <- Solidity/EVM Framework (Benchmark)
│   ├── CLAUDE.md                          <- AI agent context for this ecosystem
│   ├── Audit_Assistant_Playbook.md        <- Conversation structure & prompts (Sections 1–10, 19 SCANs)
│   ├── CommandInstruction.md              <- System prompt (binding architecture)
│   ├── audit-workflow1.md                 <- Manual audit methodology + Pashov 170-vector cross-ref
│   ├── audit-workflow2.md                 <- Semantic phase analysis
│   └── pashov-skills/                     <- Pashov Audit Group integration
│       ├── CLAUDE.md                      <- AI agent context
│       ├── SKILL.md                       <- Orchestrator (discovers files, spawns agents, merges report)
│       ├── VERSION                        <- Upstream version tracker
│       ├── README.md                      <- Integration overview
│       ├── finding-validation.md          <- FP gate + confidence scoring
│       ├── report-formatting.md           <- Output template
│       ├── agents/                        <- Vector-scan + adversarial agent instructions
│       └── attack-vectors/                <- 170 atomic attack vectors (4 files)
│
├── RustBaseSmartContract/                 <- Rust Framework (CosmWasm / Solana / Substrate)
│   ├── CLAUDE.md
│   ├── README.md
│   ├── Audit_Assistant_Playbook_Rust.md   <- Sections 1–10
│   ├── CommandInstruction-Rust.md         <- Binding architecture + Rust lenses
│   └── Rust-Smartcontract-workflow.md     <- Methodology + ClaudeSkills + SSB patterns
│
├── Go-SmartContract/                      <- Go Framework (Cosmos SDK / IBC / CometBFT)
│   ├── CLAUDE.md
│   ├── README.md
│   ├── Audit_Assistant_Playbook_Go.md     <- Sections 1–10
│   ├── CommandInstruction-Go.md           <- Binding architecture + 8 Go/Cosmos lenses
│   └── Go-Smart-Contract-Audit-Methodology.md <- Methodology + ClaudeSkills C1–C6 + ABCI++
│
├── Cosmos-SDK/                            <- Cosmos SDK Framework (advanced chain-level)
│   ├── CLAUDE.md
│   ├── README.md
│   ├── Audit_Assistant_Playbook_Cosmos.md <- Sections 1–10
│   ├── CommandInstruction-Cosmos.md       <- Binding architecture + Cosmos-specific lenses
│   └── Cosmos-SDK-Security-Audit-Methodology.md <- Methodology + governance/consensus/IBC
│
├── Cairo-StarkNet/                        <- Cairo Framework (StarkNet L2)
│   ├── CLAUDE.md
│   ├── README.md
│   ├── Audit_Assistant_Playbook_Cairo.md  <- Sections 1–10
│   ├── CommandInstruction-Cairo.md        <- Binding architecture + 6 Cairo lenses
│   └── Cairo-Audit-Methodology.md         <- Methodology + ClaudeSkills Cairo patterns
│
├── Algorand-PyTeal/                       <- Algorand Framework (PyTeal / TEAL)
│   ├── CLAUDE.md
│   ├── README.md
│   ├── Audit_Assistant_Playbook_Algorand.md <- Sections 1–10
│   ├── CommandInstruction-Algorand.md     <- Binding architecture + 6 Algorand lenses
│   └── Algorand-Audit-Methodology.md      <- Methodology + ClaudeSkills A1–A9 patterns
│
├── Nemesis/                               <- NEMESIS iterative reasoning auditor (language-agnostic)
│   ├── CLAUDE.md                          <- AI agent context
│   ├── README.md                          <- Architecture, benchmark, usage
│   ├── NEMESIS_INTEGRATION.md             <- Per-ecosystem integration status
│   └── skills/                            <- Actual SKILL.md files (copied from nemesis-auditor)
│       ├── nemesis-auditor/SKILL.md       <- Orchestrator (iterative loop)
│       ├── feynman-auditor/SKILL.md       <- First-principles logic bug finder
│       └── state-inconsistency-auditor/SKILL.md <- Coupled state desync detector
│
└── ClaudeSkills/                          <- Trail of Bits vulnerability patterns (submodule)
    └── plugins/building-secure-contracts/skills/
    │   ├── solana-vulnerability-scanner/   <- Integrated → Rust Framework
    │   ├── cosmos-vulnerability-scanner/   <- Integrated → Go Framework
    │   ├── substrate-vulnerability-scanner/<- Integrated → Rust Framework
    │   ├── cairo-vulnerability-scanner/    <- Integrated → Cairo Framework
    │   ├── algorand-vulnerability-scanner/ <- Integrated → Algorand Framework
    │   └── ton-vulnerability-scanner/      <- Available (no framework yet)
    ├── plugins/solidity-auditor/          <- /solidity-auditor slash command (Pashov)
    │   └── skills/solidity-auditor/
    │       └── SKILL.md                   <- Orchestrator: 4 vector-scan + 1 adversarial agent
    └── plugins/docs-for-humans-and-ai/    <- Documentation standard (Cyfrin)
        └── skills/docs-for-humans-and-ai/
            ├── SKILL.md                   <- Dual-audience formatting + Diataxis
            └── resources/                 <- Cyfrin claude-docs-prompts reference
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
| **Solidity/EVM** | ~4,630 | 1–10 | Benchmark + QuillAudits V1 + evmresearch.io + Pashov 170-vector | Value flow, adversarial thinking, historical awareness, guard consistency, invariant awareness, OWASP coverage, time discipline, specification completeness, compiler trust boundary, account abstraction awareness |
| **Rust** | ~3,400+ | 1–10 | Solana + Substrate + Awesome-Rust-Checker (Rudra/lockbud/RAPx/rCanary/MIRAI) + Safe Solana Builder (Frank Castle, SSB1–SSB8) | Ownership tracking, unsafe hunting, panic safety, cross-contract, state consistency, arithmetic, Send/Sync soundness, concurrency, memory safety, verification, CPI safety surface, Curiosity Principle |
| **Go/Cosmos** | ~3,700+ | 1–10 | Cosmos C1–C6 + ABCI++ | Pointer hunting, error paranoia, zero value, module boundary, state consistency, economic surface, ABCI++ lifecycle, tx structure |
| **Cosmos-SDK** | ~2,300+ | 1–10 | Cosmos chain-level | Governance attacks, consensus safety, module integration, IBC security, validator economics, upgrade safety |
| **Cairo/StarkNet** | ~2,703 | 1–10 | Cairo C1–C6 | felt252 thinking, storage hunting, L1↔L2 surface, reentrancy, serialization, access control |
| **Algorand/PyTeal** | ~2,456 | 1–10 | Algorand A1–A9 | Transaction field hunting, group thinking, inner tx fee, clear state paranoia, smart sig, asset opt-in |
| **NEMESIS** | Cross-ecosystem | N/A | Feynman (7 categories) + State Inconsistency (8 phases) | First-principles reasoning, coupled state mapping, iterative cross-feed loop, multi-tx journey tracing |

### ClaudeSkills Integration

All vulnerability patterns from `ClaudeSkills/plugins/building-secure-contracts/skills/` are integrated:

| ClaudeSkills Scanner | Patterns | Integrated Into | Key Additions |
|---------------------|----------|-----------------|---------------|
| **QuillAudits V1 + evmresearch.io** | 10 skills + 300+ notes | Solidity/EVM Methodology + Playbook + CommandInstruction | Guard consistency, invariant detection, behavioral analysis, reentrancy variants, external call safety, proxy safety, signature replay, oracle/flash loan, input/arithmetic, DoS/griefing, OWASP SC Top 10 (2025), AA (ERC-4337/EIP-7702/ERC-7579), CPIMP, transient storage (EIP-1153), compiler trust boundary, L2/cross-chain, non-standard token DB (65.8% stat), 40+ exploit DB (2016–2025), specification completeness, formal verification epistemology |
| **Pashov Audit Group** | 170 attack vectors, 5 agents | SolidityEVM Methodology + Playbook + CommandInstruction + pashov-skills/ | 170-vector parallelized scan, FP gate (3 checks), confidence scoring (100-point), cross-chain/LayerZero (18 vectors), adversarial reasoning agent, Phase 0 integration |
| Solana | 670+ lines | Rust CommandInstruction + Methodology | CPI, PDA, ownership, signer checks |
| Cosmos | 741+ lines | Go CommandInstruction + Methodology + Cosmos-SDK | GetSigners, non-determinism, ABCI panic/slow, bookkeeping, ABCI++ lifecycle, module integration, tx structure attacks |
| Substrate | 792+ lines | Rust CommandInstruction + Methodology | Weights/fees, verify-first, unsigned validation |
| **Awesome-Rust-Checker** | 5 tools, 10 patterns (RUST1–RUST10) | Rust CommandInstruction + Methodology + Playbook | Rudra (76 CVEs, Send/Sync variance, panic safety, unsafe destructors), lockbud (deadlock, TOCTOU, UAF, invalid free), RAPx (SafeDrop, Senryx, Z3), rCanary (6 leak patterns), MIRAI (taint, constant-time, panic reachability) |
| **Safe Solana Builder** | 8 patterns (SSB1–SSB8), 17 rules (SSB-CPI + SSB-ANC) | Rust CommandInstruction + Methodology + Playbook | Frank Castle (70+ Rust audits, 250+ Critical/High) — CPI safety surface, Anchor pitfalls, Token-2022 compatibility, native Rust 6-step validation, Curiosity Principle (6 adversarial questions) |
| Cairo | 723+ lines | Cairo CommandInstruction + Methodology | felt252, L1 handler, storage layout, signature replay |
| Algorand | 406+ lines | Algorand CommandInstruction + Methodology | Rekey, close, group size, inner tx fee, clear state |
| **solidity-auditor** (`/solidity-auditor`) | SKILL.md + VERSION | SolidityEVM → pashov-skills/ (skill files + references) | Orchestrator SKILL.md + 4–5 parallel agents; `pashov-skills/` is `{resolved_path}`; `finding-validation.md` replaces `judging.md` |
| **docs-for-humans-and-ai** | Diataxis + llmstxt.org standard | All 7 CLAUDE.md files + llms.txt + llms-full.txt + build script | Dual-audience formatting, LOCAL CUSTOMIZATIONS marker, AI-consumable docs standard (Cyfrin claude-docs-prompts) |
| **NEMESIS** | Feynman Auditor (7 question categories) + State Inconsistency Auditor (8 phases) + iterative loop orchestrator | All 6 ecosystem CommandInstruction files (optional Phase 0 / 0.5) | 100% precision, 52.9% Sherlock coverage, language-agnostic iterative reasoning, coupled state dependency mapping, cross-feed discovery, masking code detection |

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

### For Go Audits (Cosmos SDK / IBC / CometBFT)
1. Read [Audit_Assistant_Playbook_Go.md](./Go-SmartContract/Audit_Assistant_Playbook_Go.md)
2. Use [CommandInstruction-Go.md](./Go-SmartContract/CommandInstruction-Go.md) as system prompt
3. Follow [Go-Smart-Contract-Audit-Methodology.md](./Go-SmartContract/Go-Smart-Contract-Audit-Methodology.md)

### For Cosmos SDK Chain-Level Audits (Governance / Consensus / Upgrades)
1. Read [Audit_Assistant_Playbook_Cosmos.md](./Cosmos-SDK/Audit_Assistant_Playbook_Cosmos.md)
2. Use [CommandInstruction-Cosmos.md](./Cosmos-SDK/CommandInstruction-Cosmos.md) as system prompt
3. Follow [Cosmos-SDK-Security-Audit-Methodology.md](./Cosmos-SDK/Cosmos-SDK-Security-Audit-Methodology.md)

### For Cairo/StarkNet Audits
1. Read [Audit_Assistant_Playbook_Cairo.md](./Cairo-StarkNet/Audit_Assistant_Playbook_Cairo.md)
2. Use [CommandInstruction-Cairo.md](./Cairo-StarkNet/CommandInstruction-Cairo.md) as system prompt
3. Follow [Cairo-Audit-Methodology.md](./Cairo-StarkNet/Cairo-Audit-Methodology.md)

### For Algorand/PyTeal Audits
1. Read [Audit_Assistant_Playbook_Algorand.md](./Algorand-PyTeal/Audit_Assistant_Playbook_Algorand.md)
2. Use [CommandInstruction-Algorand.md](./Algorand-PyTeal/CommandInstruction-Algorand.md) as system prompt
3. Follow [Algorand-Audit-Methodology.md](./Algorand-PyTeal/Algorand-Audit-Methodology.md)

## AI Ingestibility

This framework is designed for both human auditors and AI agents:

| Artifact | Purpose | How to Generate |
|----------|---------|----------------|
| [CLAUDE.md](./CLAUDE.md) | AI agent project context | Maintained manually |
| [llms.txt](./llms.txt) | Page index with descriptions | `./scripts/build-llms-txt.sh` |
| [llms-full.txt](./llms-full.txt) | Full concatenated content (~24K lines) | `./scripts/build-llms-txt.sh` |
| CommandInstruction files | LLM system prompts (binding rules) | Used directly as system prompt |
| `merged.txt` (per-audit) | Concatenated in-scope code | Playbook Section 1 Build Layer |

The `docs-for-humans-and-ai` ClaudeSkills plugin documents the writing standard. Based on [Cyfrin claude-docs-prompts](https://github.com/Cyfrin/claude-docs-prompts).

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

**Framework Version:** 3.2 (SolidityEVM — NEMESIS), 3.2 (Rust — Safe Solana Builder), 2.1 (Go), 2.0 (Cairo, Algorand), 1.0 (Cosmos-SDK), 1.0 (NEMESIS)
**Last Updated:** March 2026
**License:** MIT
