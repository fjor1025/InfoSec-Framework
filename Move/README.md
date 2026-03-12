# Sui Move Smart Contract Audit Framework

## Overview

This module provides comprehensive security audit methodology for Sui Move smart contracts, including the unique object model, capability pattern, PTB composability, and package upgrade considerations.

## Quick Start

```bash
# 1. Copy system prompt
cat CommandInstruction-Move.md

# 2. Start audit session with the prompt

# 3. Invoke parallelized scan (recommended for <2500 SLOC)
[AUDIT AGENT: Move Parallelized Scan]

# 4. For complex DeFi protocols
[AUDIT AGENT: Sui Protocol Audit]
```

## Module Structure

```
Move/
├── CommandInstruction-Move.md      # System prompt (copy this)
├── Move-Audit-Methodology.md       # Full methodology reference
├── Audit_Assistant_Playbook_Move.md # Conversation structure
├── README.md                        # This file
├── CLAUDE.md                        # AI assistant context
└── move-auditor-skills/            # Parallelized audit orchestrator
    ├── SKILL.md                    # Orchestrator instructions
    ├── references/
    │   ├── attack-vectors/         # 143 documented patterns
    │   │   ├── attack-vectors-1.md   # Object model, abilities (V1-V30)
    │   │   ├── attack-vectors-2.md   # Shared objects, PTBs (V31-V60)
    │   │   ├── attack-vectors-3.md   # Upgrades, lifecycle (V61-V90)
    │   │   ├── attack-vectors-4.md   # Arithmetic, types (V91-V120)
    │   │   └── attack-vectors-5.md   # DeFi patterns (V121-V143)
    │   ├── agents/
    │   │   ├── vector-scan-agent.md
    │   │   ├── sui-protocol-agent.md
    │   │   └── adversarial-reasoning-agent.md
    │   ├── judging.md
    │   └── report-formatting.md
    └── assets/
```

## Six Auditor Lenses

### Lens 1: Object Abilities Hunting
Move's type system with abilities (copy, drop, store, key) IS the security model. Wrong abilities = critical vulnerability.

### Lens 2: Capability Pattern Verification
Sui uses capability objects for access control. Functions with side effects must require capability parameters.

### Lens 3: Object Relationship Validation
When related objects are passed together, their relationship must be validated (pool_id checks).

### Lens 4: Shared Object and PTB Safety
PTBs enable atomic multi-step transactions. Flash loan receipts need NO abilities and must bind to source.

### Lens 5: Package Upgrade Safety
init() runs once on first deployment, NOT on upgrade. Migration functions needed for post-upgrade state.

### Lens 6: Arithmetic and Type Safety
Move is safe, but bitwise shifts don't overflow-check (Cetus pattern). Generic type confusion possible.

## Attack Vector Categories

| Category | Vectors | Coverage |
|----------|---------|----------|
| Object Model & Abilities | V1-V30 | copy/drop/store/key misuse, object leakage |
| Access Control | V1-V10 | Capability pattern, OTW, visibility |
| Shared Objects & PTBs | V26-V40 | Flash loans, concurrent access, version |
| Package Lifecycle | V17-V25 | Upgrades, migrations, dependencies |
| Arithmetic & Types | V41-V60 | Shifts, generics, rounding |
| DeFi Patterns | V61-V143 | Oracle, AMM, vault, staking, bridge |

## Protocol Checklists

Run `[AUDIT AGENT: Sui Protocol Audit]` for category-specific validation:

- **Lending/Borrowing** (14 items) — interest accrual, liquidation math, oracle validation
- **AMM/DEX** (10 items) — slippage from user, deadline, invariant verification
- **Vault/Accounting** (10 items) — first-depositor, rounding direction, share manipulation
- **Staking/Rewards** (10 items) — accumulator ordering, flash stake prevention
- **Bridge/Cross-Chain** (9 items) — replay protection, rate limits, finality
- **Governance** (6 items) — flash vote prevention, timelock, quorum

## Integration with External Skills

### move-auditor-skills (Parallelized Scanning)
```
[AUDIT AGENT: Move Parallelized Scan]
```
- Spawns 5 vector scanning agents in parallel
- In DEEP mode: adds Sui Protocol Agent + Adversarial Reasoning Agent
- Merges and deduplicates findings
- Confidence scoring for each finding

### .context Framework Integration
References `.context/skills/smart-contract-audit/`:
- `MOVE-CHECKS.md` — Quick tricks and audit patterns
- `reference/move/fv-mov-*` — Vulnerability pattern details
- `reference/move/protocols/` — DeFi protocol context files

## Usage Examples

### Basic Audit
```
[AUDIT AGENT: Protocol Mapper]
> Analyze sources/pool.move and sources/router.move
```

### Attack Hypothesis Generation
```
[AUDIT AGENT: Attack Hypothesis Generator]
> Focus on the flash_loan and repay functions
```

### Full Parallelized Scan
```
[AUDIT AGENT: Move Parallelized Scan] deep
> Run comprehensive 143-vector scan with adversarial reasoning
```

## References

- [Sui Documentation](https://docs.sui.io/)
- [Move Language Reference](https://move-language.github.io/move/)
- [Sui Move Examples](https://github.com/MystenLabs/sui/tree/main/examples)
- [Sui Security Advisories](https://github.com/MystenLabs/sui/security/advisories)
