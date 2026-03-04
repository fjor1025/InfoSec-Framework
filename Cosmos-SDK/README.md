# Cosmos-SDK Security Audit Framework

> **Ecosystem:** Cosmos SDK / CometBFT / IBC / Interchain Security
> **Framework Version:** 1.0
> **Parent Framework:** [InfoSec-Framework](../README.md)
> **Companion:** [Go Smart Contract Audit Framework](../Go-SmartContract/README.md)

---

## What This Framework Provides

A complete, professional-grade security audit methodology for Cosmos SDK-based blockchains — covering module security, consensus safety, IBC protocol analysis, governance attack surfaces, and economic exploit theory.

This is NOT a beginner guide. It assumes working knowledge of:
- Cosmos SDK architecture (modules, keepers, handlers)
- CometBFT consensus (PBFT, proposer selection, evidence)
- IBC protocol (connections, channels, packets, light clients)
- Go language security fundamentals

---

## Framework Structure

| File | Purpose | When to Use |
|------|---------|-------------|
| [CommandInstruction-Cosmos.md](CommandInstruction-Cosmos.md) | System prompt for audit chat sessions | Copy into every new audit conversation |
| [Cosmos-SDK-Security-Audit-Methodology.md](Cosmos-SDK-Security-Audit-Methodology.md) | Core methodology: threat models, vulnerability classes, checklists | Reference during analysis; pin alongside code |
| [Audit_Assistant_Playbook_Cosmos.md](Audit_Assistant_Playbook_Cosmos.md) | LLM conversation structure and prompt templates | Follow the lifecycle for structured audit flow |
| [README.md](README.md) | This file — overview and quick start | Orientation |

---

## Quick Start

### 1. Prepare Codebase

```bash
# From the target chain's repo root:
find . -type f \( -name "*.go" -o -name "*.proto" \) \
  ! -path "*/vendor/*" ! -path "*_test.go" \
  ! -path "*/testutil/*" ! -path "*/mock/*" \
  | head -500 \
  | while read f; do
      echo "// ===== FILE: $f ====="
      cat "$f"
    done > merged.txt
```

### 2. Start Audit Session

1. Open a new LLM chat (Claude, GPT-4, etc.)
2. Paste the contents of `CommandInstruction-Cosmos.md` as the system prompt
3. Pin `merged.txt` as the code context
4. Pin `Cosmos-SDK-Security-Audit-Methodology.md` as reference

### 3. Follow the Audit Lifecycle

```
Architecture Mapper → Threat Model Builder → Hypothesis Generator
        → Code Path Explorer → Adversarial Reviewer → Finding Drafts
```

Each role is activated by tagging your message:
```
[AUDIT AGENT: Cosmos Architecture Mapper]
Map the security architecture of this codebase.
```

See `Audit_Assistant_Playbook_Cosmos.md` for complete prompt templates.

---

## Cosmos-Specific Focus Areas

### Module & Keeper Security
- Keeper dependency graph and permission boundaries
- Store key isolation and prefix collision risks
- Module account authorization
- BeginBlocker/EndBlocker safety (no panics, bounded computation)

### IBC Protocol Security
- Channel lifecycle and capability-based handshakes
- Packet data validation and malicious counterparty defense
- Timeout and acknowledgement error handling
- Escrow invariant preservation across chains

### Governance & Upgrade Security
- Parameter poisoning via governance proposals
- Malicious software upgrade proposals
- Flash governance and low-quorum exploitation
- Emergency halt and recovery procedures

### Economic & Consensus Security
- Validator bribery and slashing evasion
- MEV extraction in Cosmos (proposer privilege)
- Staking reward calculation (rounding direction)
- Non-determinism that causes chain halts or forks

### Trail of Bits Patterns (C1–C6)
| ID | Pattern | Chain Impact |
|----|---------|-------------|
| C1 | Incorrect GetSigners | Unauthorized actions |
| C2 | Non-Determinism | Chain halt/fork |
| C3 | Message Priority | Liveness failure |
| C4 | Slow ABCI Methods | Chain halt |
| C5 | ABCI Panic | Chain halt |
| C6 | Broken Bookkeeping | Fund loss/inflation |

---

## Known Exploit Database

The methodology includes analysis patterns derived from historical Cosmos exploits:

- **Dragonberry** (2022) — ICS-23 proof bypass in IAVL trees
- **Jackfruit** (2022) — `time.Now()` non-determinism in x/authz
- **Huckleberry** (2022) — Vesting account balance miscalculation
- **Elderflower** (2022) — Bank module prefix store bypass
- **Barberry** (2022) — ICS-20 token memo field injection
- **Osmosis LP** (2022) — LP share rounding exploitation
- **Umee** (2023) — Exchange rate manipulation via IBC supply change
- **THORChain** (2021+) — Map iteration non-determinism in EndBlocker

---

## Companion Resources

- [awesome-cosmos-security](../../awesome-cosmos-security/README.md) — Curated list of Cosmos security resources, audits, and tools
- [Go Smart Contract Framework](../Go-SmartContract/) — Go-level code analysis (complements this Cosmos-specific framework)
- [Vulnerability Patterns Integration](../VULNERABILITY_PATTERNS_INTEGRATION.md) — Cross-framework pattern tracking
- [Report Writing Guide](../report-writing.md) — Finding documentation standards

### External References
- [Trail of Bits — Common Cosmos Bugs](https://github.com/crytic/building-secure-contracts/tree/master/not-so-smart-contracts/cosmos)
- [Zellic — Exploring Cosmos Security](https://www.zellic.io/blog/exploring-cosmos)
- [Cosmos SDK Security Documentation](https://docs.cosmos.network/main/build/building-modules/errors)
- [IBC Protocol Specification](https://github.com/cosmos/ibc)
- [CometBFT Security Policy](../../cometbft/SECURITY.md)

---

## Directory Layout

```
Cosmos-SDK/
├── CLAUDE.md                                    ← AI agent context
├── README.md                                    ← You are here
├── CommandInstruction-Cosmos.md                 ← System prompt (copy into LLM)
├── Cosmos-SDK-Security-Audit-Methodology.md     ← Core methodology (9 sections)
└── Audit_Assistant_Playbook_Cosmos.md           ← Conversation structure & prompts
```

---

**Maintained by:** InfoSec Framework Contributors
**License:** See [parent LICENSE](../LICENSE)

## AI Context

| Artifact | Purpose |
|----------|---------|
| [CLAUDE.md](CLAUDE.md) | AI agent context for this framework — structure, lenses, editing rules |
| [../llms.txt](../llms.txt) | AI page index (regenerate with `../scripts/build-llms-txt.sh`) |
| [../llms-full.txt](../llms-full.txt) | Full concatenated content for AI ingestion |
| [CommandInstruction-Cosmos.md](CommandInstruction-Cosmos.md) | Use directly as LLM system prompt |

Documentation follows the [docs-for-humans-and-ai](../ClaudeSkills/plugins/docs-for-humans-and-ai/) standard adapted from [Cyfrin claude-docs-prompts](https://github.com/Cyfrin/claude-docs-prompts).
