<!-- Managed by docs-for-humans-and-ai skill -->

# Nemesis

NEMESIS is a language-agnostic iterative deep-reasoning audit agent. It runs two sub-auditors (Feynman Auditor + State Inconsistency Auditor) in an alternating feedback loop until convergence.

**Before making changes**, read [README.md](README.md), [NEMESIS_INTEGRATION.md](NEMESIS_INTEGRATION.md), and the root [CLAUDE.md](../CLAUDE.md).

## Directory Contents

| File | Purpose |
|------|---------|
| [README.md](README.md) | Architecture, usage, benchmark results, output format |
| [NEMESIS_INTEGRATION.md](NEMESIS_INTEGRATION.md) | Per-ecosystem integration status and feed-forward rules |
| [skills/nemesis-auditor/SKILL.md](skills/nemesis-auditor/SKILL.md) | Orchestrator — runs the iterative Feynman ↔ State loop |
| [skills/feynman-auditor/SKILL.md](skills/feynman-auditor/SKILL.md) | First-principles logic bug finder (7 question categories) |
| [skills/state-inconsistency-auditor/SKILL.md](skills/state-inconsistency-auditor/SKILL.md) | Coupled state desync detector (8 phases) |

## Key Facts

- **Language-agnostic**: Works on Solidity, Move, Rust, Go, C++, Python, TypeScript
- **Trigger**: `[AUDIT AGENT: NEMESIS Deep Audit]` or `/nemesis` slash command
- **Position**: Runs as an optional deep-reasoning phase before hypothesis generation
- **Source skills**: Located in `Nemesis/skills/` (copied from [nemesis-auditor](https://github.com/sainikethan/nemesis-auditor) with path updates)
- **Output**: `.audit/findings/nemesis-verified.md`
- **Validation**: Findings pass the same 4 mandatory checks as all framework findings (Reachability, State Freshness, Execution Closure, Economic Realism)

## Integration Rule

NEMESIS is **additive** — it supplements, never replaces, existing ecosystem methodology. Its findings feed into the framework's Hypothesis Generator as confirmed signal, identical to how Pashov scan results are consumed.

<!-- LOCAL CUSTOMIZATIONS — everything below this line is preserved on update -->
