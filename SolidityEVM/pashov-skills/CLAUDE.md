<!-- Managed by docs-for-humans-and-ai skill -->

# Pashov Skills

Pashov Audit Group's parallelized smart contract security audit system. Spawns 4–5 agents scanning 170 atomic attack vectors with confidence scoring and FP gates.

**Before making changes**, read [README.md](README.md) and the parent framework's [CLAUDE.md](../CLAUDE.md).

## Directory Contents

| File | Purpose |
|------|---------|
| [SKILL.md](SKILL.md) | Orchestrator — discovers files, spawns agents, merges report |
| [VERSION](VERSION) | Upstream version tracker |
| [README.md](README.md) | Integration overview, comparison with InfoSec Framework |
| [finding-validation.md](finding-validation.md) | FP gate (3 checks) + confidence scoring (adapted from upstream `judging.md`) |
| [report-formatting.md](report-formatting.md) | Output template for scan reports |
| [agents/vector-scan-agent.md](agents/vector-scan-agent.md) | Agents 1–4 (Sonnet) — vector scanning instructions |
| [agents/adversarial-reasoning-agent.md](agents/adversarial-reasoning-agent.md) | Agent 5 (Opus) — adversarial reasoning (DEEP mode only) |
| [attack-vectors/attack-vectors-1.md](attack-vectors/attack-vectors-1.md) | Vectors 1–42 |
| [attack-vectors/attack-vectors-2.md](attack-vectors/attack-vectors-2.md) | Vectors 43–85 |
| [attack-vectors/attack-vectors-3.md](attack-vectors/attack-vectors-3.md) | Vectors 86–128 |
| [attack-vectors/attack-vectors-4.md](attack-vectors/attack-vectors-4.md) | Vectors 129–170 |

## Key Facts

- **Solidity-only**: Designed for EVM smart contracts
- **Trigger**: `[AUDIT AGENT: Pashov Parallelized Scan]` or `/solidity-auditor` slash command
- **Position**: Runs as Phase 0 (fast scan) before Phase 1 Understanding
- **Source skills**: Copied from [Pashov Audit Group Skills](https://github.com/pashov/skills) with framework adaptations
- **Output**: Confidence-scored findings, merged & deduplicated
- **Adaptations from upstream**: `judging.md` → `finding-validation.md` (adds InfoSec validation alignment), agent files add cross-reference headers and framework role mappings
- **Validation**: Findings pass the same 4 mandatory checks as all framework findings (Reachability, State Freshness, Execution Closure, Economic Realism) via confidence scoring

## Integration Rule

Pashov is **additive** — it supplements, never replaces, existing SolidityEVM methodology. Its findings feed into the framework's Hypothesis Generator as confirmed signal, identical to how NEMESIS results are consumed.

<!-- LOCAL CUSTOMIZATIONS — everything below this line is preserved on update -->
