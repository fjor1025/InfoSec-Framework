# TON/FunC/Tact Smart Contract Audit Framework

## Overview

This module provides comprehensive security audit methodology for TON blockchain smart contracts written in FunC, Tact, or TVM assembly.

## Quick Start

```bash
# 1. Copy system prompt
cat CommandInstruction-TON.md

# 2. Start audit session with the prompt

# 3. Invoke parallelized scan (recommended for <2500 SLOC)
[AUDIT AGENT: TON Parallelized Scan]

# 4. For complex DeFi protocols
[AUDIT AGENT: TON Protocol Audit]
```

## Module Structure

```
TON-FunC/
├── CommandInstruction-TON.md      # System prompt (copy this)
├── TON-FunC-Audit-Methodology.md  # Full methodology reference
├── Audit_Assistant_Playbook_TON.md # Conversation structure
├── README.md                       # This file
├── CLAUDE.md                       # AI assistant context
└── ton-auditor-skills/            # Parallelized audit orchestrator
    ├── SKILL.md                   # Orchestrator instructions
    ├── references/
    │   ├── attack-vectors/        # 87 documented patterns (V1-V87)
    │   │   ├── attack-vectors-1.md  # Message handling, auth (V1-V30)
    │   │   ├── attack-vectors-2.md  # Async, lifecycle (V31-V44)
    │   │   ├── attack-vectors-3.md  # Economics, DeFi (V45-V69)
    │   │   └── attack-vectors-4.md  # Token standards (V70-V87)
    │   ├── agents/
    │   │   ├── vector-scan-agent.md       # Pattern detection
    │   │   ├── ton-protocol-agent.md      # DeFi-specific checks
    │   │   └── adversarial-reasoning-agent.md
    │   ├── judging.md             # FP filtering criteria
    │   └── report-formatting.md   # Output format
    └── assets/
```

## Six Auditor Lenses

### Lens 1: Message Sender Hunting
TON's actor model means any contract can message any contract. Validate `sender_address` against stored trusted addresses.

### Lens 2: Bounce Chain Integrity
Every outgoing message can bounce. State changes before send must be reverted by bounce handlers.

### Lens 3: External Message Safety
`recv_external` handlers are gas-attack vectors. Signature → seqno → accept_message() is the only safe order.

### Lens 4: Gas and Reserve Economics
Mode flags (128, +32, etc.) control gas payment and contract survival. Misuse is catastrophic.

### Lens 5: FunC Language Footguns
Boolean -1/0 vs 1/0, missing `impure`, swapped throw polarity, reserved exit codes.

### Lens 6: Asynchronous State Coherence
State changes between messages. Callbacks must re-read state, not use cached values.

## Attack Vector Categories

| Category | Vectors | Coverage |
|----------|---------|----------|
| Message Handling & Auth | V1-V11 | Sender validation, bounce parsing, serialization |
| FunC Footguns | V12-V20 | Boolean logic, impure, throw polarity |
| Gas & Storage | V21-V30 | Mode flags, reserve usage, storage fees |
| Async Execution | V31-V44 | Race conditions, message ordering, reentrancy |
| DeFi Patterns | V45-V69 | Oracle, AMM, vault, staking, bridge |
| Token Standards | V70-V87 | TEP-74 Jetton, TEP-62 NFT compliance |

## Protocol Checklists

Run `[AUDIT AGENT: TON Protocol Audit]` for category-specific validation:

- **Jetton Implementation** (12 items) — sender validation, bounce handlers, supply tracking
- **Lending/Borrowing** (14 items) — interest accrual, liquidation math, oracle validation
- **AMM/DEX** (10 items) — slippage from user, deadline enforcement, invariant checks
- **Vault/Accounting** (10 items) — first-depositor, rounding direction, share manipulation
- **Staking/Rewards** (10 items) — accumulator ordering, flash stake prevention
- **Bridge/Cross-Chain** (9 items) — replay protection, rate limits, finality

## Integration with External Skills

### ton-auditor-skills (Parallelized Scanning)
```
[AUDIT AGENT: TON Parallelized Scan]
```
- Spawns 4 vector scanning agents in parallel
- In DEEP mode: adds TON Protocol Agent + Adversarial Reasoning Agent
- Merges and deduplicates findings
- Confidence scoring for each finding

### .context Framework Integration
References `.context/skills/smart-contract-audit/`:
- `TON-CHECKS.md` — Quick tricks and audit patterns
- `reference/ton/fv-ton-*` — Vulnerability pattern details
- `reference/ton/protocols/` — DeFi protocol context files

## Usage Examples

### Basic Audit
```
[AUDIT AGENT: Protocol Mapper]
> Analyze msg_handlers.fc and jetton_wallet.fc
```

### Attack Hypothesis Generation
```
[AUDIT AGENT: Attack Hypothesis Generator]
> Focus on the transfer_notification handler
```

### Full Parallelized Scan
```
[AUDIT AGENT: TON Parallelized Scan] deep
> Run comprehensive 87-vector scan with adversarial reasoning
```

## References

- [TON Documentation](https://docs.ton.org/)
- [TON Enhancement Proposals](https://github.com/ton-blockchain/TEPs)
- [FunC Language Reference](https://docs.ton.org/develop/func/overview)
- [Tact Language](https://docs.tact-lang.org/)
- [TVM Specification](https://ton.org/tvm.pdf)
