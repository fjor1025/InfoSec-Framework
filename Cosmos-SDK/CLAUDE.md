<!-- Managed by docs-for-humans-and-ai skill -->
<!-- Ecosystem: Cosmos SDK (Chain-Level) -->
<!-- Version: 1.0 -->

# Cosmos-SDK Security Audit Framework

Advanced chain-level security for **Cosmos SDK**, **CometBFT**, **IBC**, and **Interchain Security**. Covers module security, consensus safety, governance attacks, and economic exploit theory.

**Before making changes**, read this file fully. For repo-wide conventions, see [../CLAUDE.md](../CLAUDE.md).

**Companion framework**: [Go-SmartContract/](../Go-SmartContract/) handles Go-level code analysis. This framework handles chain-level security architecture.

## Directory Structure

```
Cosmos-SDK/
├── CLAUDE.md                                    ← You are here
├── README.md                                    ← Human-facing overview + quick start
├── CommandInstruction-Cosmos.md                 ← System prompt (binding rules, Cosmos lenses)
├── Cosmos-SDK-Security-Audit-Methodology.md     ← Core methodology (9 sections)
└── Audit_Assistant_Playbook_Cosmos.md           ← Conversation structure & prompts
```

## 3-File Architecture

| File | Role | AI Behavior |
|------|------|-------------|
| **CommandInstruction-Cosmos.md** | System prompt | Load FIRST. Chain-level security lenses. |
| **Cosmos-SDK-Security-Audit-Methodology.md** | Methodology | Threat models, vulnerability classes, governance/consensus/IBC checklists. |
| **Audit_Assistant_Playbook_Cosmos.md** | Conversation structure | Agent roles: Architecture Mapper, Threat Model Builder, Hypothesis Generator, Code Path Explorer, Adversarial Reviewer. |

## Focus Areas

| Area | Key Concerns |
|------|-------------|
| Module & Keeper Security | Keeper dependency graph, store key isolation, BeginBlocker/EndBlocker panic safety |
| IBC Protocol | Packet lifecycle, channel handshakes, light client updates, escrow invariants |
| Governance & Upgrades | Parameter poisoning, malicious upgrade proposals, flash governance |
| Consensus Safety | Validator bribery, slashing evasion, proposer MEV, non-determinism → fork |
| Economic Security | Staking reward rounding, fee manipulation, inflation/deflation attacks |

## Trail of Bits Patterns (C1–C6)

| ID | Pattern | Chain Impact |
|----|---------|-------------|
| C1 | Incorrect GetSigners | Unauthorized actions |
| C2 | Non-Determinism | Chain halt/fork |
| C3 | Message Priority | Liveness failure |
| C4 | Slow ABCI Methods | Chain halt |
| C5 | ABCI Panic | Chain halt |
| C6 | Broken Bookkeeping | Fund loss/inflation |

## Known Exploits

| Exploit | Year | Impact |
|---------|------|--------|
| Dragonberry | 2022 | ICS-23 proof bypass in IAVL trees |
| Jackfruit | 2022 | `time.Now()` non-determinism in x/authz |
| Huckleberry | 2022 | Vesting account balance miscalculation |
| Elderflower | 2022 | Bank module prefix store bypass |
| Barberry | 2022 | ICS-20 token memo field injection |

## Editing Rules

- Chain-level focus — Go code analysis belongs in `Go-SmartContract/`
- IBC patterns should reference ICS specification numbers
- Governance attack patterns must include economic feasibility analysis
- Non-determinism is the #1 chain halt vector — always check C2

<!-- LOCAL CUSTOMIZATIONS — everything below this line is preserved on update -->
