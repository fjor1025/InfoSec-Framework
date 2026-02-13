# Cairo/StarkNet Smart Contract Audit Framework

> A comprehensive audit framework for Cairo smart contracts on StarkNet L2.
> **Version 2.0** — Enhanced with binding architecture and ClaudeSkills vulnerability patterns.

## Overview

This framework provides structured methodology for auditing Cairo smart contracts, with special attention to:
- **L1↔L2 Bridge Security**: Cross-layer message validation and fund safety
- **felt252 Arithmetic**: Field element overflow/underflow vulnerabilities
- **Signature Replay**: Nonce management and domain separation
- **L1 Handler Validation**: Authorized sender verification

### Binding Architecture (v2.0)
The CommandInstruction enforces structured audit behavior through:
- **AUTHORITATIVE SOURCES** — Document hierarchy that governs LLM behavior
- **CORE RULES OF ENGAGEMENT** — 5 non-negotiable rules
- **PRE-ANALYSIS VERIFICATION** — Silent checklist before any output
- **AUDITOR'S MINDSET** — 6 Cairo-specific lenses (felt252 Thinking, Storage Layout Hunting, L1↔L2 Attack Surface, Reentrancy Awareness, Serialization Safety, Access Control Rigor)

### ClaudeSkills Integration
Vulnerability patterns from `ClaudeSkills/plugins/building-secure-contracts/skills/cairo-vulnerability-scanner/` are integrated throughout the methodology, providing specific detection patterns with vulnerable/secure code examples.

## Framework Structure

```
Cairo-StarkNet/
├── README.md                              <- This file
├── Audit_Assistant_Playbook_Cairo.md      <- Conversation structure & prompts
├── CommandInstruction-Cairo.md            <- Cairo system prompt
└── Cairo-Audit-Methodology.md             <- Full audit methodology
```

## Quick Start

1. **Read the Playbook**: [Audit_Assistant_Playbook_Cairo.md](./Audit_Assistant_Playbook_Cairo.md)
2. **Use System Prompt**: [CommandInstruction-Cairo.md](./CommandInstruction-Cairo.md)
3. **Follow Methodology**: [Cairo-Audit-Methodology.md](./Cairo-Audit-Methodology.md)

## Key Concepts

### Cairo-Specific Considerations
| Aspect | Cairo/StarkNet Specifics |
|--------|-------------------------|
| **Types** | `felt252` (field element), `u128`, `u256`, `ContractAddress` |
| **Arithmetic** | Field elements wrap at prime P (~2^251) |
| **Storage** | `#[storage]` structs with `LegacyMap` |
| **Entry Points** | `#[external(v0)]`, `#[l1_handler]`, `#[constructor]` |
| **L1↔L2** | `send_message_to_l1_syscall`, L1 handler pattern |

### Critical Attack Vectors
1. **felt252 Overflow/Underflow** - Arithmetic on field elements without bounds
2. **L1→L2 Address Conversion** - Addresses > STARKNET_PRIME map to zero
3. **L1→L2 Message Failure** - Locked funds without cancellation mechanism
4. **Unchecked from_address** - L1 handlers without sender validation
5. **Signature Replay** - Missing nonce/domain separation

### Tool References
- **Caracal**: Static analyzer for Cairo
  - `unchecked-felt252-arithmetic`
  - `unchecked-l1-handler-from`
  - `missing-nonce-validation`
- **Starknet Foundry**: Testing framework
- **Cairo-lint**: Linting tool

## StarkNet Architecture Quick Reference

```
┌─────────────────────────────────────────────────────────────────┐
│                        ETHEREUM L1                               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │  L1 Bridge   │───▶│ StarkNet Core│───▶│  L1 Verifier │       │
│  │  Contract    │    │   Contract   │    │   Contract   │       │
│  └──────────────┘    └──────────────┘    └──────────────┘       │
│         │                   │                                    │
│         │ sendMessageToL2() │ Merkle Root                       │
│         ▼                   ▼                                    │
├─────────────────────────────────────────────────────────────────┤
│                        STARKNET L2                               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │   Sequencer  │───▶│  L2 Contract │───▶│    Prover    │       │
│  │              │    │ #[l1_handler]│    │   (STARK)    │       │
│  └──────────────┘    └──────────────┘    └──────────────┘       │
└─────────────────────────────────────────────────────────────────┘

L1→L2 Message Flow:
1. L1 contract calls sendMessageToL2()
2. Message enters L1→L2 message queue
3. Sequencer includes message in L2 block
4. #[l1_handler] processes message

L2→L1 Message Flow:
1. L2 contract calls send_message_to_l1_syscall()
2. Message included in state update proof
3. L1 contract can consume message after proof verification
```

## 📚 Known Exploit Database

### StarkNet/Cairo Exploits
- [ ] **ZKLend (2024)**: L1 message validation bypass
- [ ] **JediSwap**: Price oracle manipulation
- [ ] **MySwap**: felt252 arithmetic issues

### L1↔L2 Bridge Exploits (Cross-Reference)
- [ ] **Wormhole Pattern**: Signature validation bypass on bridge
- [ ] **Ronin Pattern**: Validator compromise in bridge
- [ ] **Nomad Pattern**: Merkle proof validation failure

### General Cairo Vulnerabilities
- [ ] felt252 overflow in balance calculations
- [ ] Missing from_address check in L1 handlers
- [ ] Signature replay due to missing nonce
- [ ] L1→L2 address truncation to zero
- [ ] Locked funds from failed L1→L2 messages

## Playbook Sections (v2.0)

The playbook now includes all 10 sections:

| Section | Purpose |
|---------|--------|
| 1. Build Layer | Create `merged.txt` from Cairo source |
| 2. Main Chat | Protocol Mapper, Hypothesis Generator, Code Path Explorer, Adversarial Reviewer |
| 3. Exploration | Understand protocol design (no bug hunting) |
| 4. Working Chat | Deep dive on surviving hypotheses |
| 5. Drafting | Format findings with Cairo-specific templates |
| 6. Scope Index | Navigate codebase by contract/module |
| 7. Review Mode | Verify findings before submission |
| 8. SCAN Chats | Paranoid Greedy, felt252 Safety, L1↔L2 Security, Access Control |
| 9. Hypotheses Formulation | Interactive brainstorming with Cairo attack surfaces |
| 10. Scope Transfer | Transfer context to new chat |

## Integration with Other Frameworks

| If Auditing... | Also Reference... |
|----------------|-------------------|
| Cairo + Solidity L1 Bridge | `../SolidityEVM/` |
| Cairo + CosmWasm IBC | `../RustBaseSmartContract/` |
| Cairo with Python tooling | `../Algorand-PyTeal/` |

## Learning Resources

1. **Cairo Book**: https://book.cairo-lang.org/
2. **StarkNet Documentation**: https://docs.starknet.io/
3. **OpenZeppelin Cairo**: https://github.com/OpenZeppelin/cairo-contracts
4. **Trail of Bits Cairo Patterns**: `ClaudeSkills/plugins/building-secure-contracts/skills/cairo-vulnerability-scanner/`
5. **Caracal Analyzer**: https://github.com/crytic/caracal

---

**Framework Version:** 2.0
**Last Updated:** February 2026
**Target Ecosystems:** Cairo, StarkNet L2
**Enhanced with:** ClaudeSkills Trail of Bits patterns, InfoSec_Us_Team methodology
