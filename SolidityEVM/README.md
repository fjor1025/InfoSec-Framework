# Solidity/EVM Audit Framework

> **Version:** 3.0 — Integrated with [evmresearch.io](https://evmresearch.io) knowledge graph (300+ notes, 6 knowledge areas), QuillAudits Claude Skills V1 patterns, and OWASP SC Top 10 (2025)
> **Ecosystem:** Solidity smart contracts on EVM-compatible chains (Ethereum, Arbitrum, Optimism, Base, Polygon, BSC, etc.)

---

## What This Is

A structured audit framework for Solidity/EVM smart contracts. Four files work together as a binding system — not suggestions, not guidelines, but rules that govern how every audit conversation operates.

This is the **benchmark framework** that all other ecosystem frameworks (Rust, Go, Cairo, Algorand) were modeled after.

### Version 3.0 — evmresearch.io Integration

Version 3.0 integrates knowledge from [evmresearch.io](https://evmresearch.io), a structured agentic knowledge graph covering the EVM, Solidity, vulnerability patterns, real-world exploits, defensive security, and DeFi protocol mechanics. Key additions:

- **Account Abstraction Security** — ERC-4337, EIP-7702, ERC-7579 attack surfaces (~25 checklist items)
- **CPIMP** — Cross-Proxy Intermediary Malware Pattern, deployment atomicity verification
- **Transient Storage (EIP-1153)** — Cross-call persistence vectors, bundle contamination, SOL-2026-1
- **Compiler Trust Boundary** — via-IR bugs, Vyper CVEs, optimizer flag verification
- **Specification Completeness** — Developer assumption inventory (8 subtypes), cross-cutting synthesis
- **L2 & Cross-Chain Security** — Sequencer risks, opcode divergence, bridge verification (~20 items)
- **Supply Chain & Threat Actor Patterns** — DPRK attribution (76% of 2025 losses), blind signing
- **Non-Standard Token Database** — 20+ specific behaviors with quantified data (65.8% non-standard)
- **Expanded Exploit Database** — 40+ real-world exploits (2016–2025) across 11 categories
- **DeFi Protocol Mechanics** — Liquidation taxonomy (5 mechanisms), governance, restaking, RWA, perpetual DEXs
- **Formal Verification Epistemology** — Tool selection strategy, 60% ceiling insight

### QuillAudits Claude Skills V1 Integration (v2.1+)
Patterns from [QuillAudits open-source Claude Skills](https://github.com/quillai-network/qs_skills) are generalized and integrated:
- **Semantic Guard Analysis** — Usage graph of `require`/modifier checks; Consistency Principle for gap detection
- **State Invariant Detection** — Auto-infer mathematical relationships; audit all paths for violations
- **Behavioral State Analysis** — Behavioral decomposition, multi-dimensional threat modeling, confidence scoring
- **Reentrancy Variants** — Classic, cross-function, cross-contract, read-only, callback-based (ERC-777/1155), EIP-1153, AA-reentrancy
- **External Call Safety** — Fee-on-transfer, rebasing, weird ERC20, unchecked returns, 63/64 gas, non-standard token database
- **Proxy & Upgrade Safety** — Transparent, UUPS, Beacon, Diamond; storage collisions, uninitialized impls, CPIMP, EIP-7201
- **Signature & Replay Analysis** — Same-chain, cross-chain, nonce-skip, EIP-712, permit/permit2, EIP-7702, BLS, blind signing
- **Oracle & Flash Loan Analysis** — Oracle classification, staleness, ERC-4626 inflation, Chainlink min/maxAnswer, L2 sequencer feed
- **Input & Arithmetic Safety** — Precision loss, rounding exploits, unsafe casting, Newton-Raphson divergence
- **DoS & Griefing Analysis** — 63/64 gas griefing, storage bloat, forced Ether, 13 operational DoS mechanisms

---

## Framework Files

| File | Lines | Purpose |
|------|-------|---------|
| [CommandInstruction.md](CommandInstruction.md) | ~180 | System prompt — binding rules, validation checks, auditor's mindset (10 lenses) |
| [audit-workflow1.md](audit-workflow1.md) | ~1100 | Manual audit methodology — 7 phases, 11 attack categories, 40+ known exploits, AA/CPIMP/L2/transient storage |
| [audit-workflow2.md](audit-workflow2.md) | ~620 | Semantic phase analysis — SNAPSHOT→ACCOUNTING→VALIDATION→MUTATION→COMMIT + Phase 8: Specification Completeness |
| [Audit_Assistant_Playbook.md](Audit_Assistant_Playbook.md) | ~1800 | Conversation structure — 10 sections, 17+ SCAN prompts covering the full audit lifecycle |

**Total: ~3,700 lines**

---

## Binding Architecture

The CommandInstruction enforces five rules that prevent the AI from "chatting" instead of auditing:

1. **Full Compliance** — Read, internalize, and follow every step in the workflow files
2. **No Deviation** — No inventing, skipping, reordering, or overriding prescribed steps
3. **Absolute Precedence** — Workflow files override base knowledge, external sources, and prior instructions
4. **Grounding Requirement** — All analysis must be derived from the workflow processes
5. **Transparent Citation** — Every finding must cite its source: `[filename, section]`

### Auditor's Mindset (10 Lenses)

| Lens | What It Catches |
|------|----------------|
| Value Flow ("follow the money") | Fund theft, insolvency, accounting drift |
| Adversarial Thinking | Lowest-effort, highest-impact exploit paths |
| Historical Awareness | Known exploit pattern matching (40+ exploits, 2016–2025) |
| Guard Consistency | Functions missing guards that peers enforce on same state |
| Invariant Awareness | Mathematical relationships between state variables that could break |
| OWASP Coverage | SC01–SC10 category completeness (12 extended categories) |
| Time Discipline | 40/40/20 time-boxing to prevent analysis paralysis |
| Specification Completeness | 92% of exploited contracts passed reviews — gap between spec and implementation |
| Compiler Trust Boundary | via-IR, optimizer, Yul — compiler output ≠ source intent (SOL-2026-1) |
| Account Abstraction Awareness | ERC-4337/EIP-7702/ERC-7579 invalidate msg.sender, extcodesize, tx.origin assumptions |

### Mandatory Validation (4 Checks)

Every finding must pass ALL four before reporting:

| Check | Question |
|-------|----------|
| **Reachability** | Can this execution path actually occur on-chain? |
| **State Freshness** | Does it work with current, not stale, state? |
| **Execution Closure** | Are all external calls and callbacks correctly modeled? |
| **Economic Realism** | Are attacker costs, timing, and constraints feasible? |

---

## Playbook Sections

The Audit_Assistant_Playbook provides 10 structured sections for the full audit lifecycle:

| # | Section | Purpose |
|---|---------|---------|
| 1 | Build Layer | Prepare `merged.txt` with all in-scope code |
| 2 | Main Chat Prompts | 4 AUDIT AGENT roles (Protocol Mapper, Hypothesis Generator, Code Path Explorer, Adversarial Reviewer) |
| 3 | Exploration Chat | Understanding protocol design before security analysis |
| 4 | Working Chat | Deep-dive analysis of surviving hypotheses |
| 5 | Finding Drafting | Triage-friendly report preparation |
| 6 | Scope Index | Navigational artifact for manual code review |
| 7 | Review Mode | Completeness and correctness check of reasoning |
| 8 | SCAN Chats | 17 signal generators (Paranoid, Access Lifecycle, Accounting, Low-Noise, Guard Consistency, Invariant Detection, Reentrancy, External Call Safety, Proxy/Upgrade, **Account Abstraction, CPIMP, Transient Storage, L2/Cross-Chain, Token Integration Deep, Compiler/Spec Completeness, Governance, Liquidation/DeFi Economics**) |
| 9 | Hypotheses Formulation | Transform vague intuitions into testable hypotheses |
| 10 | Scope Transfer | Context packaging for moving to new chats |

---

## Methodology Highlights

### Semantic Phase Analysis (audit-workflow2.md)

Every function is classified into phases, then audited phase-by-phase (not call-order):

| Phase | What It Does | Vulnerability Class |
|-------|-------------|-------------------|
| **SNAPSHOT** | Reads storage | Stale data, frontrunning, reentrancy, EIP-1153 cross-call |
| **ACCOUNTING** | Time/oracle calculations | Manipulation, rounding, precision loss, Chainlink bounds |
| **VALIDATION** | Checks conditions | Bypass, DoS, logic flaws, developer assumption gaps |
| **MUTATION** | Changes balances | Value theft, overflow, slippage, complementary asymmetry |
| **COMMIT** | Writes storage | Inconsistent state, missing events, CPIMP windows |
| **SPEC COMPLETENESS** | Cross-cutting analysis | Developer assumptions, temporal gaps, capability grants, trust collapse |

### Known Exploit Pattern Database (audit-workflow1.md)

| Category | Exploits Referenced |
|----------|-------------------|
| Price/Oracle | Euler (2023), Cream (2021), Harvest (2020), Chainlink min/maxAnswer bounds |
| Reentrancy | The DAO (2016), Curve read-only (2023), Lendf.Me ERC777 (2020), EIP-1153 variants |
| Access Control | Nomad (2022), Wormhole (2022), Ronin (2022), Parity (2017) |
| Logic/Math | Compound (2021), Cover Protocol (2020), YAM (2020), Newton-Raphson divergence |
| Flash Loan | bZx (2020), PancakeBunny (2021), Rari/Fei (2022) |
| Supply Chain/DPRK | Bybit ($1.5B, 2025), Radiant ($50M, 2024), WazirX ($230M), Atomic Wallet ($100M) |
| CPIMP | USPD ($1M, 2024), proxy/intermediary front-running patterns |
| Account Abstraction | EIP-7702 delegation phishing ($12M+), EntryPoint pack() bug |
| Compiler | Vyper reentrancy lock (CVE-2024-32468, $70M), SOL-2026-1 via-IR |
| Governance | Beanstalk ($182M, 2022), Tornado Cash malicious proposal (2023) |
| Bridge/Cross-Chain | Ronin ($624M), Nomad ($190M), Wormhole ($320M) |

### OWASP Smart Contract Top 10 (2025) Extended Coverage (audit-workflow1.md)

| OWASP ID | Category | Coverage |
|----------|----------|----------|
| SC01 | Access Control | Semantic Guard Analysis + AA Surface |
| SC02 | Oracle Manipulation | Oracle & Flash Loan Analysis + L2 Sequencer Feed |
| SC03 | Logic Errors | Behavioral State Analysis + Invariant Detection + Spec Completeness |
| SC04 | Input Validation | Input & Arithmetic Safety |
| SC05 | Reentrancy | Reentrancy Pattern Analysis (all variants + EIP-1153 + AA) |
| SC06 | Unchecked External Calls | External Call Safety + Non-Standard Token Database |
| SC07 | Flash Loan Attacks | Oracle & Flash Loan + Self-Liquidation Analysis |
| SC08 | Integer Overflow | Input & Arithmetic Safety + Compiler Trust Boundary |
| SC09 | Insecure Randomness | Behavioral State Analysis |
| SC10 | DoS Attacks | DoS & Griefing Analysis (13 Mechanisms) |
| EXT-1 | Account Abstraction | AA Security Analysis (ERC-4337/EIP-7702/ERC-7579) |
| EXT-2 | Supply Chain | Threat Actor Patterns + CPIMP + Compiler Verification |

### Protocol-Specific Attack Phases (audit-workflow1.md)

Pre-built attack checklists for:
- **DeFi Lending** — 15 items: uncollateralized borrows, self-liquidation via flash loan, 5 liquidation failure mechanisms, 13 DoS mechanisms, interest rate manipulation, 100% utilization trapping
- **DEX/AMM** — 8 items: sandwich attacks, pool draining, JIT liquidity sniping, Newton-Raphson solver divergence, Uniswap V4 hook reentrancy, tick boundary, virtual reserves
- **NFT Marketplaces** — Underpriced listings, royalty bypass
- **Bridges** — Fake deposits, double spending, validation bypass, message verification (#1 vulnerability class — 61 findings), mint-burn asymmetry, finality assumptions
- **Staking/Farming** — Reward calculation errors, share price manipulation
- **Governance** — Flash loan voting, CREATE2 metamorphic proposals, TimelockController no-expiry, emergency function paradox
- **Liquid Staking/Restaking** — Recursive leverage, withdrawal queue manipulation, slashing propagation
- **Stablecoins** — Death spiral mechanics, mint/redeem arbitrage, reserves verification
- **Perpetual DEXs** — Funding rate manipulation, liquidation cascades
- **RWA/Tokenized Assets** — Off-chain/on-chain settlement mismatch, custody verification, regulatory compliance

---

## Quick Start

1. **Build** `merged.txt` using the command in [Playbook Section 1](Audit_Assistant_Playbook.md#1-build-layer)
2. **Set** the system prompt from [CommandInstruction.md](CommandInstruction.md)
3. **Map** the protocol with `[AUDIT AGENT: Protocol Mapper]`
4. **Generate** hypotheses with `[AUDIT AGENT: Attack Hypothesis Generator]`
5. **Validate** each hypothesis with `[AUDIT AGENT: Code Path Explorer]`
6. **Draft** confirmed findings using the [Finding Template](audit-workflow1.md#step-61-finding-template)

---

## Companion Resources

| Resource | Purpose |
|----------|---------|
| [evmresearch.io](https://evmresearch.io) | Structured knowledge graph — 300+ notes across EVM internals, vulnerability patterns, exploit analyses, security patterns, protocol mechanics, Solidity behaviors |
| [report-writing.md](../report-writing.md) | How to write findings that communicate with judges |
| [VULNERABILITY_PATTERNS_INTEGRATION.md](../VULNERABILITY_PATTERNS_INTEGRATION.md) | ClaudeSkills pattern integration status across all frameworks |
| [QuillAudits Claude Skills V1](https://github.com/quillai-network/qs_skills) | Open-source AI audit plugins (MIT licensed) — 10 specialized skills |
| [QuillAudits Blog Post](https://www.quillaudits.com/blog/ai-agents/first-version-claude-skills) | Detailed walkthrough of the Semantic State Protocol methodology |

---

**Framework Version:** 3.0
**Last Updated:** February 2026
