<!-- Managed by docs-for-humans-and-ai skill -->
<!-- Ecosystem: TON / FunC / Tact -->
<!-- Version: 3.3 -->

# InfoSec-Framework: TON/FunC/Tact Audit Module

## Quick Start
1. Copy `CommandInstruction-TON.md` as your system prompt
2. Reference `TON-FunC-Audit-Methodology.md` for the full methodology
3. Use `Audit_Assistant_Playbook_TON.md` for conversation structure
4. Integrate `ton-auditor-skills/` for parallelized agent scanning

## Module Contents

| File | Purpose |
|------|---------|
| `CommandInstruction-TON.md` | System prompt with core rules, TON actor model specifics, validation gates |
| `TON-FunC-Audit-Methodology.md` | Comprehensive methodology with all attack vectors, checklists, phases |
| `Audit_Assistant_Playbook_TON.md` | Conversation prompts, agent roles, output formats |
| `ton-auditor-skills/` | Parallelized audit orchestrator with 4 scanning agents + protocol agent |

## TON-Specific Resources

- **Attack Vectors:** 87 documented patterns across message handling, authorization, async execution, contract lifecycle, and token standards
- **Protocol Checklists:** Jetton (12 items), Lending (14 items), AMM/DEX (10 items), Vault (10 items), Staking (10 items), Bridge (9 items)
- **Agents:**
  - Vector Scan Agent (x4): Parallelized pattern detection
  - TON Protocol Agent: Domain-specific DeFi analysis
  - Adversarial Reasoning Agent: First-principles attack path discovery

## Integration with InfoSec-Framework

This module follows the standard InfoSec-Framework structure and integrates with:
- `.context/skills/smart-contract-audit/` for reference vulnerability patterns
- `Nemesis/` for iterative deep-reasoning audit
- `ClaudeSkills/` for plugin-based extensions

## Critical TON Attack Surfaces

1. **Message Handling** — V1-V11: sender validation, bounce handling, serialization
2. **Asynchronous Execution** — V31-V44: race conditions, state coherence, message ordering
3. **Gas/Storage Economics** — V21-V30: mode flags, reserve usage, gas draining
4. **FunC Language Footguns** — V9, V12-V20: boolean logic, impure functions, throw polarity
5. **Token Standards** — V70-V87: TEP-74 Jetton, TEP-62 NFT compliance

See `TON-FunC-Audit-Methodology.md` for complete vector coverage.
