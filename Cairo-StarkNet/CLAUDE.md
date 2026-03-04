<!-- Managed by docs-for-humans-and-ai skill -->
<!-- Ecosystem: Cairo / StarkNet -->
<!-- Version: 2.0 -->

# Cairo/StarkNet Smart Contract Audit Framework

Covers **Cairo** smart contracts on **StarkNet L2** with special attention to L1↔L2 bridge security, felt252 arithmetic, and signature replay vectors.

**Before making changes**, read this file fully. For repo-wide conventions, see [../CLAUDE.md](../CLAUDE.md).

## Directory Structure

```
Cairo-StarkNet/
├── CLAUDE.md                          ← You are here
├── README.md                          ← Human-facing overview + quick start
├── CommandInstruction-Cairo.md        ← System prompt (binding rules, 6 Cairo lenses)
├── Cairo-Audit-Methodology.md         ← Full audit methodology + ClaudeSkills patterns
└── Audit_Assistant_Playbook_Cairo.md  ← Conversation structure (Sections 1–10)
```

## 3-File Architecture

| File | Role | AI Behavior |
|------|------|-------------|
| **CommandInstruction-Cairo.md** | System prompt | Load FIRST. 6 Cairo-specific lenses. |
| **Cairo-Audit-Methodology.md** | Methodology | Phases, checklists, L1↔L2 patterns, ClaudeSkills Cairo C1–C6. |
| **Audit_Assistant_Playbook_Cairo.md** | Conversation structure | 10 sections, SCAN prompts, agent roles. |

## Auditor's Mindset (6 Lenses)

| Lens | What It Catches |
|------|----------------|
| felt252 Thinking | Field element overflow/underflow at prime P (~2^251), arithmetic wrapping |
| Storage Layout Hunting | `#[storage]` struct collisions, `LegacyMap` key management |
| L1↔L2 Attack Surface | Cross-layer message validation, fund locking, cancellation mechanisms |
| Reentrancy Awareness | Cairo reentrancy patterns (different from EVM but still possible) |
| Serialization Safety | Data encoding/decoding between L1 and L2, address truncation |
| Access Control Rigor | `#[external(v0)]` exposure, `#[l1_handler]` sender validation |

## Critical Attack Vectors

| Vector | Description |
|--------|-------------|
| felt252 Overflow | Arithmetic on field elements without bounds checking |
| L1→L2 Address Conversion | Addresses > STARKNET_PRIME map to zero |
| L1→L2 Message Failure | Locked funds without cancellation mechanism |
| Unchecked from_address | L1 handlers without sender validation |
| Signature Replay | Missing nonce/domain separation |

## Cairo-Specific Types

| Type | Security Consideration |
|------|----------------------|
| `felt252` | Field element — wraps at prime P, NOT at 2^256 |
| `u128`, `u256` | Standard integers — different overflow behavior from felt252 |
| `ContractAddress` | Must validate against zero address and STARKNET_PRIME |
| `LegacyMap` | Storage map — key collisions possible |

## Tool References

| Tool | Purpose |
|------|---------|
| **Caracal** | Static analyzer (`unchecked-felt252-arithmetic`, `unchecked-l1-handler-from`) |
| **Starknet Foundry** | Testing framework |
| **Cairo-lint** | Linting tool |

## Editing Rules

- felt252 is NOT the same as uint256 — always emphasize the prime field distinction
- L1↔L2 vectors are the highest-severity class in StarkNet
- ClaudeSkills Cairo patterns (C1–C6) are integrated throughout the methodology
- StarkNet architecture diagrams should show both L1 and L2 layers

<!-- LOCAL CUSTOMIZATIONS — everything below this line is preserved on update -->
