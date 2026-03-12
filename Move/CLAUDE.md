<!-- Managed by docs-for-humans-and-ai skill -->
<!-- Ecosystem: Sui Move -->
<!-- Version: 3.3 -->

# InfoSec-Framework: Sui Move Audit Module

## Quick Start
1. Copy `CommandInstruction-Move.md` as your system prompt
2. Reference `Move-Audit-Methodology.md` for the full methodology
3. Use `Audit_Assistant_Playbook_Move.md` for conversation structure
4. Integrate `move-auditor-skills/` for parallelized agent scanning

## Module Contents

| File | Purpose |
|------|---------|
| `CommandInstruction-Move.md` | System prompt with core rules, object model specifics, validation gates |
| `Move-Audit-Methodology.md` | Comprehensive methodology with all attack vectors, checklists, phases |
| `Audit_Assistant_Playbook_Move.md` | Conversation prompts, agent roles, output formats |
| `move-auditor-skills/` | Parallelized audit orchestrator with 5 scanning agents + protocol agent |

## Move-Specific Resources

- **Attack Vectors:** 143 documented patterns across object model, capabilities, PTBs, upgrades, and DeFi
- **Protocol Checklists:** Lending (14 items), AMM/DEX (10 items), Vault (10 items), Staking (10 items), Bridge (9 items), Governance (6 items)
- **Agents:**
  - Vector Scan Agent (x5): Parallelized pattern detection
  - Sui Protocol Agent: Domain-specific DeFi analysis
  - Adversarial Reasoning Agent: First-principles attack path discovery

## Integration with InfoSec-Framework

This module follows the standard InfoSec-Framework structure and integrates with:
- `.context/skills/smart-contract-audit/` for reference vulnerability patterns
- `Nemesis/` for iterative deep-reasoning audit
- `ClaudeSkills/` for plugin-based extensions

## Critical Sui Move Attack Surfaces

1. **Object Abilities** — V1-V5: copy/drop/store/key misuse, token duplication, debt destruction
2. **Capabilities** — V1-V2, V6-V10: missing capability checks, capability factory, OTW bypass
3. **Shared Objects & PTBs** — V26-V40: flash loan bypass, concurrent access, version checks
4. **Package Upgrades** — V17-V25: init assumptions, field reordering, unpinned deps, UpgradeCap
5. **Arithmetic** — V41-V60: bitwise shift overflow (Cetus pattern), generic confusion

## Known Exploits

| Exploit | Value | Root Cause |
|---------|-------|------------|
| Cetus (2025) | $223M | Bitwise shift overflow in custom math |
| Thala | - | Missing capability check on admin function |
| KriyaDEX | - | Hot potato with drop ability |

See `Move-Audit-Methodology.md` for complete vector coverage.
