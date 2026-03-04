# Algorand/PyTeal Smart Contract Audit Framework

> A comprehensive audit framework for Algorand smart contracts (PyTeal, TEAL, ARC4).
> **Version 2.0** — Enhanced with binding architecture and ClaudeSkills vulnerability patterns.

## Overview

This framework provides structured methodology for auditing Algorand smart contracts, with special attention to:
- **Transaction Field Validation**: RekeyTo, CloseRemainderTo, AssetCloseTo
- **Group Transaction Security**: Size validation, atomic transfer integrity
- **Access Control**: UpdateApplication, DeleteApplication protection
- **Inner Transaction Safety**: Fee pooling, asset opt-in requirements

### Binding Architecture (v2.0)
The CommandInstruction enforces structured audit behavior through:
- **AUTHORITATIVE SOURCES** — Document hierarchy that governs LLM behavior
- **CORE RULES OF ENGAGEMENT** — 5 non-negotiable rules
- **PRE-ANALYSIS VERIFICATION** — Silent checklist before any output
- **AUDITOR'S MINDSET** — 6 Algorand-specific lenses (Transaction Field Hunting, Group Transaction Thinking, Inner Transaction Fee Awareness, Clear State Program Paranoia, Smart Signature Precision, Asset Opt-In Awareness)

### ClaudeSkills Integration
Vulnerability patterns from `ClaudeSkills/plugins/building-secure-contracts/skills/algorand-vulnerability-scanner/` are integrated throughout the methodology (patterns A1–A9), providing specific Tealer detector references and detection commands.

## Framework Structure

```
Algorand-PyTeal/
├── README.md                              <- This file
├── Audit_Assistant_Playbook_Algorand.md   <- Conversation structure & prompts
├── CommandInstruction-Algorand.md         <- Algorand system prompt
└── Algorand-Audit-Methodology.md          <- Full audit methodology
```

## Quick Start

1. **Read the Playbook**: [Audit_Assistant_Playbook_Algorand.md](./Audit_Assistant_Playbook_Algorand.md)
2. **Use System Prompt**: [CommandInstruction-Algorand.md](./CommandInstruction-Algorand.md)
3. **Follow Methodology**: [Algorand-Audit-Methodology.md](./Algorand-Audit-Methodology.md)

## Key Concepts

### Algorand-Specific Considerations
| Aspect | Algorand Specifics |
|--------|-------------------|
| **Languages** | PyTeal (Python DSL), TEAL (assembly), ARC4 (ABI) |
| **Execution** | Approval Program + Clear State Program |
| **Storage** | Global State (64 key-values) + Local State (16 per user) |
| **Transactions** | Atomic Groups (up to 16 transactions) |
| **Fees** | Fee Pooling across group transactions |

### Critical Attack Vectors (11 Patterns)
1. **Rekeying Attack** - Unvalidated `RekeyTo` field changes account authorization
2. **Unchecked Transaction Fee** - Smart signatures without fee bounds
3. **Closing Account** - `CloseRemainderTo` drains entire balance
4. **Closing Asset** - `AssetCloseTo` transfers all ASA holdings
5. **Group Size Check** - Missing validation allows repeated calls
6. **Time-Based Replay** - Missing `Lease` field protection
7. **Access Controls** - Unprotected Update/Delete application
8. **Asset ID Verification** - Wrong asset substitution
9. **Denial of Service** - Asset opt-in push pattern failures
10. **Inner Transaction Fee** - Unset fees drain app balance
11. **Clear State Transaction** - OnComplete bypass via clear program

### Tool References
- **Tealer**: Static analyzer for TEAL/PyTeal
  - `unprotected-rekey`
  - `group-size-check`
  - `update-application-check`
- **Algorand Sandbox**: Local testing environment
- **PyTeal**: Python DSL for smart contracts

## Algorand Architecture Quick Reference

```
┌─────────────────────────────────────────────────────────────────┐
│                    ALGORAND TRANSACTION TYPES                    │
├─────────────────────────────────────────────────────────────────┤
│ Payment          │ Transfer ALGO between accounts               │
│ Asset Transfer   │ Transfer ASA (Algorand Standard Asset)       │
│ Application Call │ Invoke smart contract (NoOp, OptIn, etc.)    │
│ Asset Freeze     │ Freeze/unfreeze ASA holdings                 │
│ Asset Config     │ Create/modify/destroy ASA                    │
│ Key Registration │ Participate in consensus                     │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    APPLICATION CALL TYPES                        │
├─────────────────────────────────────────────────────────────────┤
│ NoOp             │ Regular function call                        │
│ OptIn            │ User opts into app (local state)             │
│ CloseOut         │ User closes out of app                       │
│ UpdateApplication│ Modify approval/clear programs ← PROTECT     │
│ DeleteApplication│ Remove application entirely ← PROTECT        │
│ ClearState       │ Force-remove local state (bypass approval)   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    ATOMIC GROUP TRANSACTIONS                     │
├─────────────────────────────────────────────────────────────────┤
│ • Up to 16 transactions in a group                              │
│ • All succeed or all fail (atomic)                              │
│ • Fee pooling: one tx can pay fees for others                   │
│ • Access via Gtxn[i].field()                                    │
│ • Validate Global.group_size() matches expected                 │
└─────────────────────────────────────────────────────────────────┘
```

## 📚 Known Exploit Database

### Algorand-Specific Exploits
- [ ] **Rekeying attacks**: Unauthorized account control transfer
- [ ] **CloseRemainderTo drains**: Entire balance to attacker
- [ ] **Group size manipulation**: Repeated execution via unbounded groups
- [ ] **Asset ID confusion**: Wrong token accepted in swaps

### Smart Signature Vulnerabilities
- [ ] Unchecked fee allowing balance drain
- [ ] Missing RekeyTo validation
- [ ] Lease field replay attacks

### Application Vulnerabilities
- [ ] Unprotected UpdateApplication
- [ ] Clear state program bypass
- [ ] Inner transaction fee drain
- [ ] Asset opt-in DoS

## Playbook Sections (v2.0)

The playbook now includes all 10 sections:

| Section | Purpose |
|---------|--------|
| 1. Build Layer | Create `merged.txt` from `.py`/`.teal` source |
| 2. Main Chat | Protocol Mapper, Hypothesis Generator, Code Path Explorer, Adversarial Reviewer |
| 3. Exploration | Understand protocol design (no bug hunting) |
| 4. Working Chat | Deep dive on surviving hypotheses |
| 5. Drafting | Format findings with Algorand-specific templates |
| 6. Scope Index | Navigate codebase by approval/clear/smart sig |
| 7. Review Mode | Verify transaction field claims before submission |
| 8. SCAN Chats | Paranoid Greedy, Transaction Fields, Group Security, Access Control |
| 9. Hypotheses Formulation | Interactive brainstorming with Algorand attack surfaces |
| 10. Scope Transfer | Transfer context to new chat |

## Integration with Other Frameworks

| If Auditing... | Also Reference... |
|----------------|-------------------|
| Algorand + Bridge to Ethereum | `../SolidityEVM/` |
| Algorand + Bridge to Cosmos | `../Go-SmartContract/` |
| PyTeal with Cairo similarities | `../Cairo-StarkNet/` |

## Learning Resources

1. **Algorand Developer Portal**: https://developer.algorand.org/
2. **PyTeal Documentation**: https://pyteal.readthedocs.io/
3. **Tealer Analyzer**: https://github.com/crytic/tealer
4. **Trail of Bits Algorand Patterns**: `ClaudeSkills/plugins/building-secure-contracts/skills/algorand-vulnerability-scanner/`
5. **ARC Standards**: https://arc.algorand.foundation/

---

## AI Context

| Artifact | Purpose |
|----------|---------|
| [CLAUDE.md](CLAUDE.md) | AI agent context for this framework — structure, lenses, editing rules |
| [../llms.txt](../llms.txt) | AI page index (regenerate with `../scripts/build-llms-txt.sh`) |
| [../llms-full.txt](../llms-full.txt) | Full concatenated content for AI ingestion |
| [CommandInstruction-Algorand.md](CommandInstruction-Algorand.md) | Use directly as LLM system prompt |

Documentation follows the [docs-for-humans-and-ai](../ClaudeSkills/plugins/docs-for-humans-and-ai/) standard adapted from [Cyfrin claude-docs-prompts](https://github.com/Cyfrin/claude-docs-prompts).

---

**Framework Version:** 2.0
**Last Updated:** February 2026
**Target Ecosystems:** Algorand, PyTeal, TEAL, ARC4, Beaker
**Enhanced with:** ClaudeSkills Trail of Bits patterns (A1–A9), InfoSec_Us_Team methodology
