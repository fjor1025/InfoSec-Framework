# Move Auditor

The ultimate AI-powered security audit skill for Sui Move — 120 attack vectors, 4 parallel scan agents, adversarial reasoning, and DeFi protocol analysis.

Built for:

- **Sui devs** who want a security check before every commit
- **Security researchers** looking for fast wins before a manual review
- **Auditors** who want systematic vector coverage as a first pass

Not a substitute for a formal audit — but the most comprehensive AI check you can run on Move contracts.

## What's Inside

- **120 attack vectors** across 4 reference files — covering object model security, capability patterns, shared object concurrency, PTB flash loans, arithmetic safety, token operations, oracle manipulation, DeFi protocol economics, package upgrades, and more
- **4 parallel vector-scan agents** — each assigned ~30 vectors, scanning the full codebase simultaneously
- **Adversarial reasoning agent** (DEEP mode) — free-form exploit hunting using Feynman questioning, state inconsistency analysis, and invariant hunting
- **Sui protocol agent** (DEEP mode) — domain-specific checklists for lending, AMM/DEX, vaults, staking, bridges, governance, NFT/Kiosk, and package upgrades
- **False-positive gate** — every finding must pass 3 checks (concrete path, reachable entry point, no existing guard)
- **Confidence scoring** — base 100 with deductions for privileged callers, partial paths, self-contained impact, token assumptions, and external preconditions

## Usage

```bash
# Scan the full repo (default — 4 agents)
/move-auditor

# Full repo + adversarial reasoning + protocol analysis (6 agents)
/move-auditor deep

# Review specific file(s)
/move-auditor sources/vault.move
/move-auditor sources/pool.move sources/oracle.move

# Write report to a markdown file (terminal-only by default)
/move-auditor --file-output
```

## Known Limitations

**Codebase size.** Works best up to ~2,500 lines of Move. Past ~5,000 lines, triage accuracy drops. For large codebases, run per module.

**What AI misses.** AI is strong at pattern matching — missing capability checks, unchecked arithmetic, known ability misuse. It struggles with relational reasoning: multi-transaction state setups, specification/invariant bugs, cross-protocol composability, game-theory attacks, and off-chain assumptions. AI catches what humans forget to check. Humans catch what AI cannot reason about. You need both.
