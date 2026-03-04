<!-- Managed by docs-for-humans-and-ai skill -->
<!-- Ecosystem: Rust (CosmWasm / Solana / Substrate) -->
<!-- Version: 3.2 -->

# Rust Smart Contract Audit Framework

Covers **CosmWasm**, **Solana/Anchor**, **Substrate**, and general Rust smart contracts. Version 3.2 includes Safe Solana Builder (Frank Castle) patterns and Awesome-Rust-Checker integration.

**Before making changes**, read this file fully. For repo-wide conventions, see [../CLAUDE.md](../CLAUDE.md).

## Directory Structure

```
RustBaseSmartContract/
├── CLAUDE.md                          ← You are here
├── README.md                          ← Human-facing overview + quick start
├── CommandInstruction-Rust.md         ← System prompt (binding rules, Rust-specific lenses)
├── Rust-Smartcontract-workflow.md     ← Methodology + ClaudeSkills patterns + SSB
└── Audit_Assistant_Playbook_Rust.md   ← Conversation structure (Sections 1–10)
```

## 3-File Architecture

| File | Role | AI Behavior |
|------|------|-------------|
| **CommandInstruction-Rust.md** | System prompt | Load FIRST. Binding rules. Rust-specific lenses + red flags. |
| **Rust-Smartcontract-workflow.md** | Methodology | 7 phases, CosmWasm/Solana/Substrate checklists, Rudra/lockbud/MIRAI patterns (RUST1–10), SSB patterns (SSB1–8). |
| **Audit_Assistant_Playbook_Rust.md** | Conversation structure | 10 sections, SCAN prompts, agent roles. |

## Auditor's Mindset (Rust Lenses)

| Lens | What It Catches |
|------|----------------|
| Ownership Tracking | Dangling references, use-after-move, incorrect lifetimes |
| Unsafe Hunting | Unsound Send/Sync, UnsafeDataflow, memory corruption |
| Panic Safety | `.unwrap()`, `.expect()`, unchecked indexing → chain halt/DoS |
| Cross-Contract | CPI privilege escalation, PDA confusion, keeper boundary bypass |
| State Consistency | Partial writes on error, missing rollback, load-after-CPI staleness |
| Arithmetic | checked_* vs unchecked, precision loss, rounding direction |
| Send/Sync Soundness | Unsafe trait impls that enable data races (Rudra: 76 CVEs) |
| Concurrency | Deadlock, TOCTOU, condvar misuse (lockbud patterns) |
| Memory Safety | UAF, double-free, leak patterns (RAPx + rCanary) |
| Verification | Taint flow, constant-time, reachable panics (MIRAI) |
| CPI Safety Surface | SSB-CPI-1 through SSB-CPI-8: program ID validation, signer pass-through, post-CPI staleness |
| Curiosity Principle | 6 adversarial questions for every account input |

## Ecosystem-Specific Entry Points

| Ecosystem | Entry Points | Key Concerns |
|-----------|-------------|--------------|
| **CosmWasm** | `instantiate`, `execute`, `query`, `migrate`, `reply` | Submessage failure propagation, storage key management |
| **Solana/Anchor** | `#[program]` instructions, account constraints | CPI safety, PDA derivation, type cosplay, 19 solana-fender analyzers |
| **Substrate** | `#[pallet::call]` extrinsics, hooks | Weight calculation, storage migrations, pallet interactions |
| **General Rust** | `pub fn`, `unsafe` blocks | Send/Sync soundness, panic safety, memory leaks |

## Semantic Phases (Rust)

| Phase | Rust Indicators | Key Questions |
|-------|----------------|---------------|
| SNAPSHOT | `&self`, `load`, `get`, `clone` | Cloning too much? Atomic reads? |
| VALIDATION | `ensure!`, `assert!`, `?`, error arms | Can be bypassed? All paths covered? |
| ACCOUNTING | `env.block.*`, time, fees | Time manipulation? Rounding errors? |
| MUTATION | `&mut self`, `insert`, arithmetic | Value conserved? Overflow risks? |
| COMMIT | `save`, `store`, events | All changes persisted? Events correct? |
| ERROR | `Result`, `Option`, `unwrap` | State corrupted on error? Cleanup? |

## Key Integrations

| Source | What It Provides | Patterns |
|--------|-----------------|----------|
| ClaudeSkills Solana Scanner | CPI, PDA, ownership, signer checks | Cosmos C1–C6 |
| ClaudeSkills Substrate Scanner | Weights/fees, verify-first, unsigned validation | 792+ lines |
| Awesome-Rust-Checker | 5 academic tools (Rudra, lockbud, RAPx, rCanary, MIRAI) | RUST1–RUST10 |
| Safe Solana Builder (Frank Castle) | 70+ audits, 250+ Critical/High | SSB1–SSB8, SSB-CPI, SSB-ANC |
| solana-fender | AST-based static analysis | 19 analyzers |
| x-ray / sec3 | LLVM-IR vulnerability detection | 20+ SVE IDs |

## Editing Rules

- Multi-ecosystem framework — changes must specify which ecosystem (CosmWasm/Solana/Substrate/General) they apply to
- SSB patterns (SSB1–8, SSB-CPI, SSB-ANC) are in Rust-Smartcontract-workflow.md Step 6.7
- Awesome-Rust-Checker patterns (RUST1–10) are in Step 6.6
- Never remove `.unwrap()` detection — it's a critical chain halt vector
- Solana-specific additions should reference SVE IDs where applicable

<!-- LOCAL CUSTOMIZATIONS — everything below this line is preserved on update -->
