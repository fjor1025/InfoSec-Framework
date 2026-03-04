# Audit Assistant Playbook
Cognitive Framework for Smart Contract Auditing

* Version: 3.1 — Enhanced with evmresearch.io knowledge graph (300+ notes), CPIMP, Account Abstraction, Transient Storage, L2 Security, **Pashov Audit Group 170-Vector Parallelized Scan**
* Status: Experimental / Practitioner Tool
* Audience: Experienced smart contract auditors

This playbook describes a **minimal, reproducible flow** for working when auditing smart contracts.
This playbook does NOT automate security audits.
It does NOT replace auditor judgment.
It structures how auditors think, explore, validate, and report findings.

Language policy:
- Descriptions and documentation: English
- Reasoning and exploration: Auditor’s choice (Default is RU)
- Formal artifacts (hypotheses, findings, reviews): English recommended


This playbook consists of two parts:

**CORE AUDIT FLOW**
The main audit workflow and roles. Used in every audit.

**SUPPORTING TOOLS**
Optional utilities and coverage helpers. Used as needed.

---

## METHODOLOGY INTEGRATION

This playbook structures **conversations**. The actual audit **methodology** lives in:

| File | Purpose | When to Reference |
|------|---------|-------------------|
| `audit-workflow1.md` | Manual audit phases, checklists, attack vectors | During Code Path Explorer, hypothesis validation |
| `audit-workflow2.md` | Semantic phase analysis (SNAPSHOT→COMMIT) | When classifying functions, tracing mutations |
| `CommandInstruction.md` | System prompt for audit sessions | At start of any audit chat |
| `pashov-skills/` | 170-vector parallelized scan, confidence scoring, agent instructions | Fast pre-audit triage, automated scanning, CI integration |

**Key Methodology Concepts to Apply:**
- **Semantic Phases**: SNAPSHOT → ACCOUNTING → VALIDATION → MUTATION → COMMIT
- **Validation Checks**: Reachability, State Freshness, Execution Closure, Economic Realism
- **Known Exploit Patterns**: Euler, Cream, Nomad, Wormhole, Curve read-only reentrancy, Bybit $1.5B, Penpie, SIR.trading, USPD CPIMP, EIP-7702 delegation phishing, Balancer cascade, etc.
- **Guard Consistency**: Semantic Guard Analysis — usage graph of `require`/modifier checks
- **State Invariant Detection**: Infer mathematical relationships, check all functions
- **OWASP SC Top 10 (2025)**: SC01–SC10 coverage mapping
- **Time-Boxing**: 40/40/20 rule for large codebases
- **Specification Completeness**: 92% of 2025 exploited contracts passed reviews — spec gap is primary failure mode
- **Account Abstraction**: ERC-4337 / EIP-7702 / ERC-7579 attack surface analysis
- **CPIMP**: Cross-Proxy Intermediary Malware Pattern — proxy deployment atomicity
- **Transient Storage**: EIP-1153 cross-call persistence, compiler bugs (SOL-2026-1)
- **Compiler Trust Boundary**: via-IR divergence, optimizer, pipeline-specific bugs
- **Developer Assumption Inventory**: 8 subtypes of unstated preconditions
- **Cross-Cutting Synthesis**: Temporal gaps, indefinite capability grants, compositional cascades
- **Verification Strategy**: FV vs fuzzing vs manual — 60% ceiling for automated tools
- **Pashov 170-Vector Scan**: Parallelized agentic scan with FP gates, confidence scoring, and cross-chain/LayerZero coverage (18 vectors)
- **Pashov Confidence Scoring**: Start at 100, deduct for privilege (-25), partial path (-20), self-contained impact (-15), threshold at 75

---

## HOW TO USE THIS PLAYBOOK (REAL AUDIT FLOW)

**1. Prepare context**

* Build `merged.txt` and place it together with available project documentation.
* Generate the Scope Index once for navigation.

**2. Initial understanding**

* Start with **Exploration**.
* Work there until the protocol model is stable for you (depending on nSLOC up to 1–2 days).
* Feel free to make notes for further investigation, but do not search for bugs yet.

**3. Hypotheses**

* Generate attack hypotheses in **Main**.
* Perform first-pass validation there.
* Discard weak hypotheses early.

**4. Deep analysis**

* Move surviving or unclear hypotheses into **Working**.
* Use one or multiple Working chats as needed.
* Iterate quickly: analysis → conclusion → report-ready notes.

**5. Findings**

* When a real issue is confirmed, switch to **Drafting**.
* Use the appropriate drafting template.
* Store reports immediately in the private repository.

**6. Coverage & signals**

* Use **SCAN** selectively as a signal generator.
* Treat SCAN outputs as hints, not findings.
* Prefer targeted scans over whole-code scans.

**7. Review**

* Use **Review Mode** to check reasoning completeness
  (not to judge the author or report quality).

**8. Iteration**

* When chats become heavy, transfer context and continue in a new chat.
* Avoid returning to Main late in the audit; continue via Working.


## AUDIT LIFECYCLE — one-screen 

```
[0] Local Setup
    └─ build merged.txt
    └─ prepare local workspace
    └─ attach merged.txt and docs to assistant
    └─ build scope index for manual audit

[0.5] Pashov Fast Scan (optional, parallelized)
    └─ spawn 4 vector-scan agents (Sonnet) on merged.txt
    └─ each agent covers ~42 attack vectors (170 total)
    └─ triage pass: Skip / Borderline / Survive
    └─ deep pass: structured one-liners → confidence score
    └─ spawn adversarial reasoning agent (Opus, DEEP mode)
    └─ FP gate (concrete path, reachable entry, no guard)
    └─ confidence ≥ 75 → feed to Hypothesis Generator [2]
    └─ see pashov-skills/README.md

[1] Exploration
    └─ initial understanding of the protocol
    └─ modules / roles / flows
    └─ no hypotheses and no security assessment
    └─ make notes for further investigation

[2] Main — Idea Generation & Fast Filter
    └─ hypothesis generation (AI)
    └─ quick code check
    └─ INVALID → die immediately
    └─ questionable / alive → continue

[3] Manual Audit Marathon (loop)
    └─ manual code reading
    └─ continuous Exploration
    └─ Your own ideas emerge
        └─ → Working
            └─ → to Drafting
        └─ → or Hypothesis Generator
            └─ → back to Main (same pipeline as in [2])

[4] Working — Deep Dive / Impact
    └─ Surviving or interesting hypotheses
    └─ Discussion, debates, and pushback — ok
    └─ Finding and maximizing impact
    └─ 1 hypothesis → N findings
    └─ If necessary:
        └─ Setting the PoC task
    └─ Preparing the report raw material

[5] Drafting
    └─ Formatting findings
    └─ Severity / Narrative / Clarity
    └─ Report format
```

### Key Properties

* Exploration — **mode**, not a phase (found in [1] and [3])
* Hypotheses — **consumable**
* Main — **hypothesis pipeline**, a single chat per project
* Working — **live thinking zone**

> **AI accelerates filtering and formalization.
> Humans make decisions and sense the design.**


## **CORE AUDIT FLOW**
## 1. BUILD LAYER

### Purpose

Prepare **one friendly file** with all in-scope code.

### Input

* working directory with **only in-scope Solidity files**
* no third-party libraries

### Build command

```bash
(
  echo "INDEX"
  find . -name "*.sol" -type f | sort
  echo "END INDEX"
  echo
  find . -name "*.sol" -type f -exec sh -c '
    for f do
      echo "==== FILE: $f ===="
      cat "$f"
      echo "\n==== END FILE ====\n"
    done
  ' sh {} +
) > merged.txt
```

### Output

`merged.txt` with the following structure:

* INDEX (file paths)
* FILE / END FILE blocks

`merged.txt` **attached to the chats** and used in all steps.


## 2. MAIN CHAT PROMPTS

### General Rules

* One run = one role
* One run = one mental task
* Response format **strictly fixed**

---

### 2.1 Protocol Mapper

**Role:** building a mental model of the protocol

```text
[AUDIT AGENT: Protocol Mapper]

Instructions:
Follow the section "Protocol Mapper" EXACTLY (role + required output structure).

Available Code Context:
- The pinned file "merged.txt" contains the full in-scope smart contracts.

Additional Context (README / contest description / whitepaper):
- Use pinned project documentation if available.
- If no docs are pinned, ask me to paste relevant excerpts before making assumptions.

Task:
Produce the protocol model strictly in the required output structure.
Do NOT speculate. If information is missing, write "Unknown".

[ROLE: Protocol Mapper]

You are a senior Web3 security auditor.

Analyze the provided smart contracts and documentation.

Your task is NOT to find bugs yet.
Your task is to build a precise mental model of the protocol.

You MUST output strictly in the structure defined below.
No additional sections are allowed.

1. Protocol Purpose
- What problem does it solve?

2. Assets
- What assets are at risk? (tokens, balances, NFTs, accounting units)

3. Trust Assumptions
- External dependencies (oracles, bridges, keepers)
- Privileged roles (owner, admin, governance)
- Upgradeability assumptions

4. Critical State Variables
- Variables whose corruption leads to loss of funds or insolvency

5. Critical Flows
- User flows involving assets (deposit, withdraw, borrow, liquidate, swap)
- Admin flows
- For each flow, identify the semantic phases: SNAPSHOT → ACCOUNTING → VALIDATION → MUTATION → COMMIT

6. Invariants
- What must always be true for the protocol to remain solvent?
- Reference: [audit-workflow1.md, Step 3.2] for universal invariants

7. Inheritance & Modifiers (per audit-workflow2.md, Step 2.1b)
- Contract inheritance tree
- Key modifiers and their execution order
- Storage layout concerns (if upgradeable)

Do NOT speculate.
If information is missing, explicitly say "Unknown".

[END]
```

---

### 2.2 Attack Hypothesis Generator

**Role:** Generating attack scenarios

```text
[AUDIT AGENT: Attack Hypothesis Generator]

Instructions:
Follow the section "Attack Hypothesis Generator" EXACTLY
(role definition + constraints + output format).

Available Code Context:
- The pinned file "merged.txt" contains the full in-scope smart contracts.

Protocol Context:
- Use the protocol model already produced in this chat by the Protocol Mapper.
- If the protocol model is missing or incomplete, ask me to provide it before proceeding.

Task:
Generate a bounded set of plausible attack hypotheses.
Do NOT validate exploits.
Do NOT search for concrete bugs yet.

[ROLE: Attack Hypothesis Generator]

You are an adversarial security researcher.

Your task is to enumerate plausible ways the protocol *could* fail,
assuming adversarial behavior, but without validating feasibility yet.

You are NOT validating exploits.
You are NOT proving impact.
You are generating hypotheses to be checked later.

Constraints:
- Generate at most **15 hypotheses**.
- Focus on scenarios that could lead to:
  - loss of funds,
  - protocol insolvency,
  - irreversible accounting corruption.
- Hypotheses must be:
  - neutral,
  - testable,
  - grounded in protocol design and trust assumptions.
- Do NOT include purely speculative or unrealistic attacks.
- Reference known exploit patterns from [audit-workflow1.md, Step 5.1b]:
  - Price/Oracle: Euler, Cream, Harvest, Mango Markets, yETH, Bunni
  - Reentrancy: DAO, Curve read-only, ERC777 hooks, SIR.trading (EIP-1153), Fei/Rari
  - Access Control: Nomad, Wormhole, Parity, WazirX
  - Flash Loan: bZx, PancakeBunny, Rari/Fei, Beanstalk (governance)
  - Supply Chain: Bybit ($1.5B), Radiant ($53M), Orbit Chain ($82M)
  - CPIMP: USPD ($1M), EtherFi/Pendle/Orderly (Jul 2025)
  - AA: ERC-4337 pack() bug, EIP-7702 delegation phishing ($12M+)
  - Compiler: Curve/Vyper CVE-2023-46247, Solidity SOL-2026-1
  - Composability: Furucombo, SushiSwap, Balancer cascade (Nov 2025)
- Reference OWASP SC Top 10 (2025) categories from [audit-workflow1.md, OWASP Coverage Map]:
  - SC01 Access Control, SC02 Oracle, SC03 Logic, SC04 Input, SC05 Reentrancy
  - SC06 Unchecked Calls, SC07 Flash Loan, SC08 Overflow, SC09 Randomness, SC10 DoS
- Include guard consistency and invariant violation hypotheses:
  - Functions missing guards that peers enforce (Semantic Guard Analysis)
  - Mathematical invariants that could break under edge cases (State Invariant Detection)
  - External call safety: fee-on-transfer, rebasing, weird ERC20 (20+ non-standard behaviors)
  - Proxy/upgrade: storage collisions, uninitialized implementations, CPIMP
  - Signature replay: cross-chain, nonce skipping, expired permits, EIP-7702, BLS
  - Account Abstraction: ERC-4337 paymaster drainage, EIP-7702 delegation, ERC-7579 module lock
  - Transient storage: EIP-1153 cross-call persistence, bundle contamination
  - Compiler: via-IR pipeline divergence, optimizer, SOL-2026-1
  - Developer assumptions: 8 subtypes of unstated preconditions
  - Cross-cutting: temporal gaps, indefinite capability grants, compositional cascades
  - L2/cross-chain: opcode divergence, sequencer risks, message verification

Output STRICTLY in the following format:

For each hypothesis:

H<N>. <Short title>

Semantic Phase:
- Which phase is vulnerable? [SNAPSHOT/ACCOUNTING/VALIDATION/MUTATION/COMMIT]
- Cross-phase interaction? (e.g., Snapshot→Mutation race)

Threat Model:
- Who is the adversary?
- What capabilities or privileges do they have?

Attack Idea:
- High-level description of the potential failure mode.
- Similar to known exploit? [Name if applicable]

Required Conditions:
- What must be true in order for this attack to work?

What to Inspect in Code:
- Specific modules, functions, or state variables
  that should be analyzed during validation.

Do NOT speculate beyond the protocol model.
If something is unclear, explicitly state assumptions or write "Unknown".

[END]
```

#### Hypothesis Generator / CONTINUE

```text
Continue Hypothesis Generation mode.
Generate additional hypotheses starting from H<n+1>.
Do NOT rewrite prior hypotheses.
```

### 2.3 Code Path Explorer

**Role:** deep testing of one hypothesis. 

```text
[AUDIT AGENT: Code Path Explorer]

Instructions:
Follow the section "Code Path Explorer" EXACTLY
(role definition + rules + output format).

Available Code Context:
The pinned file "merged.txt" contains the full in-scope smart contracts.

Attack Hypothesis:
- Use hypothesis H<N> from the current Main Chat.
- Do NOT reinterpret or reformulate it unless explicitly asked.

Important: Do NOT analyze any hypothesis until I specify the exact H<N>.

Task:
Decide Valid / Invalid / Inconclusive and justify by tracing code paths.
Do NOT assume mitigations unless explicitly enforced in code.

[ROLE: Code Path Explorer]

You are performing a deep logic audit.

Use merged.txt to locate and analyze the relevant functions and code paths.
Your task is to determine whether a specific attack hypothesis
actually follows from the code.

**Methodology Reference:**
- Apply semantic phase analysis from [audit-workflow2.md, Step 2.2-2.3]
- Use the 7-step function checklist from [audit-workflow1.md, Step 4.1]
- Trace inheritance and modifiers per [audit-workflow2.md, Step 2.1b]

Your goals:
- Trace execution paths by semantic phase (SNAPSHOT → ACCOUNTING → VALIDATION → MUTATION → COMMIT)
- Identify edge cases using values from [audit-workflow1.md, Step 5.3]
- Identify missing checks or incorrect ordering
- Reason about state before and after execution
- Check for cross-phase vulnerabilities (Snapshot→Mutation races, Accounting→Validation order)

Rules:
- Analyze exactly ONE hypothesis per run, specified by me as H<N>.
- Do NOT introduce new hypotheses.
- Do NOT expand scope beyond what the hypothesis assumes.
- Do NOT assume mitigations unless explicitly enforced in code.

When I provide H<N>, output STRICTLY:

Hypothesis:
- H<N> — <short title>

Inheritance & Modifiers:
- Contract inheritance chain
- Modifiers on target function(s)
- Any missing expected modifiers (nonReentrant, whenNotPaused)

Semantic Phase Trace:
- SNAPSHOT: What state is read? Is it fresh?
- ACCOUNTING: Any time/oracle dependencies? 
- VALIDATION: What checks exist? Can they be bypassed?
- MUTATION: What changes? Is value conserved?
- COMMIT: Is state consistently written?

Hypothesis Status:
- Valid / Invalid / Inconclusive

Validation Checks (ALL must pass for Valid):
- [x] Reachability: Can this path execute on-chain?
- [x] State Freshness: Does it work with current state?
- [x] Execution Closure: Are external calls modeled?
- [x] Economic Realism: Is cost/timing feasible?

Detailed Reasoning:
- Step-by-step reasoning through the code paths

Potential Exploit Path:
- If valid, describe a concrete exploit scenario
- If invalid, explain what prevents exploitation

Do NOT assume mitigations unless they are explicitly enforced in code.

[END]
```

#### Code Path Explorer / CONTINUE
```
Continue in Code Path Explorer mode.

Now analyze hypothesis H<N> from the list above.
Do NOT restate the hypothesis unless necessary.
Use the same STRICT output format.
```

#### Code Path Explorer / REGROUND

```
Re-grounding:

We are still in Code Path Explorer mode.
Analyze ONLY hypothesis H<N>.
Use merged.txt as the source of truth.
Do NOT introduce new hypotheses or assumptions.
Follow the same STRICT output format.
```

### 2.4 Adversarial Reviewer

**Role:** anti-false-positive (bug bounty triage mindset)

```text
[AUDIT AGENT: Adversarial Reviewer]

Instructions:
Follow the section "Adversarial Reviewer" EXACTLY
(role definition + rules + output format).

Available Code Context:
The pinned file "merged.txt" contains the full in-scope smart contracts.

Finding Under Review:
- I will paste a single security finding written by an auditor.
- Do NOT review anything until the finding is provided.

Task:
Assess whether the finding would survive triage.

[ROLE: Adversarial Reviewer]

You are acting as a strict security triager.

Your default stance is skeptical.
The finding must be justified by the code and stated assumptions.

You are NOT a co-auditor.
You are NOT searching for new vulnerabilities.
You are NOT improving the finding.

Rules:
- Review exactly ONE finding per run.
- Do NOT expand scope or threat model.
- Do NOT change stated severity.
- Do NOT assume intent or behavior not enforced by code.
- If the finding claims specific code behavior, you MUST verify it in merged.txt.
- If verification is impossible, mark it explicitly.

When the finding is provided, output STRICTLY:

Assessment:
- Valid / Invalid / Context-dependent

Counterarguments:
- What assumptions or steps are not proven by the finding

Code Verification:
- Confirmed / Not confirmed / Partially confirmed
- Reference exact functions or state where relevant

Residual Risk:
- What remains if the finding is partially valid

Reviewer Notes:
- What would block acceptance by a triager
- What clarification or evidence is missing

[END]

```

#### Adversarial Reviewer / CONTINUE
```text
Continue in Adversarial Reviewer mode.

Review the next finding below using the same rules
and the same STRICT output format.
```

#### Adversarial Reviewer / REGROUND

```text
Re-grounding:

We are still in Adversarial Reviewer mode.
Review exactly ONE finding.
Remain skeptical and triage-oriented.
Verify claimed code behavior using merged.txt.
Do NOT introduce new vulnerabilities or scope.
Follow the same STRICT output format.
```

### 2.5 Pashov Parallelized Scan

**Role:** Fast parallelized security scan using 170 attack vectors (Pashov Audit Group)

> **Source:** [Pashov Audit Group Skills](https://github.com/pashov/skills) — MIT Licensed
> **Reference:** `pashov-skills/` directory for full agent instructions, attack vectors, and scoring rules
> **Best for:** Pre-audit triage, fast automated scanning, codebase under ~2,500 lines

```text
[AUDIT AGENT: Pashov Parallelized Scan]

Instructions:
Follow the Pashov parallelized scan workflow EXACTLY.
Reference files are in the `pashov-skills/` directory.

Available Code Context:
- The pinned file "merged.txt" contains the full in-scope smart contracts.
- OR: scan all in-scope .sol files found via `find` (per mode selection).

Mode Selection:
- **default** (no arguments): scan all `.sol` files. Exclude: `interfaces/`, `lib/`, `mocks/`, `test/`, `*.t.sol`, `*Test*.sol`, `*Mock*.sol`.
- **deep**: same as default + spawn adversarial reasoning agent for thorough review.
- **`$filename ...`**: scan specified file(s) only.

Task:
Orchestrate a parallelized security scan across 170 attack vectors.

[ORCHESTRATION WORKFLOW]

**Turn 1 — Discover.**
In parallel: (a) Bash `find` for in-scope `.sol` files per mode, (b) Locate `pashov-skills/` reference directory.

**Turn 2 — Prepare.**
In parallel: (a) Read `pashov-skills/agents/vector-scan-agent.md`, (b) Read `pashov-skills/report-formatting.md`, (c) Create four per-agent bundle files (`/tmp/audit-agent-{1,2,3,4}-bundle.md`) — each concatenates ALL in-scope `.sol` files (with `### path` headers and fenced code blocks), then `pashov-skills/finding-validation.md`, then `pashov-skills/report-formatting.md`, then `pashov-skills/attack-vectors/attack-vectors-N.md`; print line counts.

**Turn 3 — Spawn.**
Spawn all agents as parallel tool calls:
- **Agents 1–4** (vector scanning): Each receives vector-scan-agent.md instructions + their bundle file.
- **Agent 5** (adversarial reasoning, DEEP mode only): Receives in-scope file paths + `pashov-skills/agents/adversarial-reasoning-agent.md` instructions.

**Turn 4 — Report.**
Merge all agent results: deduplicate by root cause (keep higher-confidence version), sort by confidence highest-first, re-number sequentially, insert **Below Confidence Threshold** separator row. Use `pashov-skills/report-formatting.md` for the scope table and output structure.

[FINDING VALIDATION — from pashov-skills/finding-validation.md]

FP Gate (ALL must pass — drop finding if any fails):
1. Concrete attack path: caller → function call → state change → loss/impact
2. Entry point reachable by attacker (check modifiers, guards)
3. No existing guard prevents the attack

Confidence Score (start at 100, apply deductions):
- Privileged caller required → -25
- Partial attack path → -20
- Self-contained impact → -15

Threshold: 75 (below = description only, no Fix block)

[CROSS-REFERENCE TO INFOSEC FRAMEWORK]

Pashov scan findings should be used as:
- Input to the Attack Hypothesis Generator (confirmed findings → hypotheses)
- Signal for targeted SCAN prompts (surviving vector groups → specific SCANs)
- Cross-validation data for Code Path Explorer (verified independently)
- Pre-filter for the Adversarial Reviewer (confidence < 75 → manual triage)

[DO NOT REPORT]
- Linter/compiler-level notes, gas micro-optimizations, naming, NatSpec
- Admin privileges that are by-design (owner can pause, set fees)
- Missing events or logging
- Centralization observations without concrete exploit path
- Theoretical issues requiring implausible preconditions

[END]
```

#### Pashov Scan / TARGETED

```text
Continue Pashov Parallelized Scan mode.
Focus on specific vector groups:
- <LIST VECTOR GROUPS: e.g., "Reentrancy (V12, V52, V60, V83, V105, V153, V156)">
Re-scan only the specified vectors with deeper analysis.
Apply the same FP gate and confidence scoring.
```

#### Pashov Scan / MERGE WITH HYPOTHESES

```text
Context:
The Pashov Parallelized Scan has produced findings.
The Attack Hypothesis Generator has produced hypotheses H1..Hn.

Task:
1. Map each Pashov finding to the closest hypothesis (or mark as NEW).
2. For mapped findings: does the Pashov finding confirm, contradict, or extend the hypothesis?
3. For NEW findings: generate a new hypothesis in the standard H<N> format.
4. Output a combined priority list for Code Path Explorer validation.
```

## 3. EXPLORATION CHAT PROMPTS

### Purpose

**Exploration Chat** is a mode for collaboratively *understanding* a complex protocol before formalizing hypotheses and auditing.

Goal:

* Recover developer intentions**,
* Understand the architecture and dependencies**,
* Find design bottlenecks** without calling them vulnerabilities,
* Reduce the time it takes to "get into" complex code.

### Universal Starter Query for Exploration Chat (select your preferred language)

```text
We are in the exploration phase.

Context:
- The pinned file "merged.txt" contains the full in-scope smart contracts.
- No external libraries are included.
- I am trying to understand the protocol design and developer intent.

Your role:
Act as a senior protocol developer / architect.
Explain what the code is trying to achieve, not whether it is secure.

Rules:
- Do NOT look for vulnerabilities.
- Do NOT assess security or exploitability.
- Do NOT speculate beyond what can be inferred from code.
- If intent or assumptions are unclear, explicitly say so.

Task:
1) Give a high-level explanation of the protocol architecture.
2) Identify key design decisions that are non-obvious.
3) List the main assumptions the design relies on.
4) Point out areas that are complex or easy to misunderstand.

Focus on "why" and "how", not on "is it safe".

We will discuss specific files and functions step by step.

Language policy:
- System instructions are written in English and must be followed strictly.
- The user may interact in Russian.
- Respond in Russian unless explicitly asked to respond in English.
```

### Request for Exploration Chat Re-grounding

```text
Re-grounding:
We are still in Exploration Chat.
Use the pinned file "merged.txt" as the source of truth.
Do not ask me to provide code that already exists in merged.txt.
When answering, reference exact functions/files from merged.txt.
If something cannot be found there, say so explicitly.
```

### Request to move to a new file

```text
Re-grounding before new topic:
We are continuing exploration of the same codebase.
Focus now on <FILE / MODULE>.
Use merged.txt and cite exact locations.
```


## 4. WORKING CHAT PROMPTS

### Universal starter query for Working Chat (select your preferred language)

```text
Context:
This is a WORKING chat for deep manual analysis of a surviving hypothesis.

Input:
- A hypothesis that was not discarded in Main.
- The hypothesis may still be wrong and can be killed here.

Primary goals:
- Understand the real security impact (if any).
- Expand, strengthen, or refute the hypothesis.
- Decompose one hypothesis into one or more concrete findings if applicable.

What to focus on:
- Impact analysis (funds, accounting, fairness, trust, availability).
- Secondary and cascading effects.
- Alternative actors, timings, and conditions.
- Whether the issue is reportable, and under what assumptions.

Allowed:
- Debate and challenge the hypothesis.
- Revisit validity if impact analysis reveals flaws.
- Explore multiple interpretations of the same issue.

Optional support:
- Help formulate PoC requirements or attack conditions
  (do NOT implement PoCs unless explicitly requested).

Out of scope:
- Generating new unrelated hypotheses.
- Auto-audit loops or mass scanning.
- Final report writing (handled elsewhere).

Language policy:
- System instructions are in English.
- I will work in Russian.
- Respond in Russian unless explicitly requested otherwise.

Source of truth:
- Use the pinned merged.txt and project documentation.

Your role:
Act as a senior security auditor assisting in impact extraction
and finding shaping, not as an automated validator.

Hypothesis (ID, threat model, attack idea, conditions, what to inspect):


Main trace available below; use it only after you attempt to kill/confirm independently:
```

### Short-prompt for Working Chat when working with a list of hypotheses:

```text
We continue the Working Chat.

Context:
- The list of hypotheses H1..Hn is already known.
- We are now analyzing hypothesis H7.

Task:
Validate or invalidate this hypothesis based on code paths.
```

### Starting-prompt for working with outputs from SCAN (select your preferred language)

```text
Context:
This is a WORKING chat for deep manual analysis of a surviving hypothesis.

Input:
- A hypothesis that was not discarded in Main.
- The hypothesis may still be wrong and can be killed here.

Primary goals:
- Understand the real security impact (if any).
- Expand, strengthen, or refute the hypothesis.
- Decompose one hypothesis into one or more concrete findings if applicable.

What to focus on:
- Impact analysis (funds, accounting, fairness, trust, availability).
- Secondary and cascading effects.
- Alternative actors, timings, and conditions.
- Whether the issue is reportable, and under what assumptions.

Allowed:
- Debate and challenge the hypothesis.
- Revisit validity if impact analysis reveals flaws.
- Explore multiple interpretations of the same issue.

Optional support:
- Help formulate PoC requirements or attack conditions
  (do NOT implement PoCs unless explicitly requested).

Out of scope:
- Generating new unrelated hypotheses.
- Auto-audit loops or mass scanning.
- Final report writing (handled elsewhere).

Language policy:
- System instructions are in English.
- I will work in Russian.
- Respond in Russian unless explicitly requested otherwise.

Source of truth:
- Use the pinned merged.txt and project documentation.

Your role:
Act as a senior security auditor assisting in impact extraction
and finding shaping, not as an automated validator.

Source: SCAN / <file>

Observation:
<что именно скан подсветил>

Why it looks interesting:
<1–2 строки, твой взгляд>

Task:
Help analyze whether this observation can lead to a real security impact.
```

### Short reset-request (experimental)

```text
Assume the previously identified issue is fully fixed.
Re-evaluate the surrounding code paths for independent issues.
```

### Template for description of finding before sending it to Drafting

```text
Finding source: Working Chat

Summary:
<1–2 sentences, gist of the problem>

Impact:
<what breaks / what risk>

Conditions:
<under what conditions, roles, states>

Code snippets:
<contracts / functions>

Notes:
<anything important to keep but not included above>
```

## 5. FINDING DRAFTING CHAT PROMPTS

### Purpose

Preparing a clear, triage-friendly report on an already identified issue.

### Starting-prompt for Finding Drafting Chat

```text
We are in the finding drafting phase.

Context:
- The vulnerability has already been validated in a Working Chat.
- This chat is dedicated to preparing a clear, accurate vulnerability report.
- The pinned file "merged.txt" contains the full in-scope smart contracts.

Your role:
Act as an experienced security auditor and bug bounty triager.

General Rules:
- Do NOT invent new attack paths.
- Do NOT expand scope beyond the validated issue.
- Do NOT exaggerate impact.
- Be precise, conservative, and technically accurate.
- Clearly separate:
  - facts from assumptions,
  - guaranteed behavior from configuration-dependent behavior.

Templates:
- A report template MAY be provided by me (e.g. Low / High / Critical, or platform-specific).
- If a template is provided, follow it EXACTLY.
- If no template is provided, ask which template or severity level should be used
  before drafting the report.

Task:
Given a validated vulnerability description, help structure and refine
a triage-friendly report that matches the provided template and severity level.

Goal:
Produce a report that a triager can quickly understand, validate, and classify
without ambiguity.

```
### Template for drafting (paste required template) 

```text
Here is the report template to use:

<PASTE TEMPLATE HERE>

Here is the validated vulnerability description:

<PASTE YOUR FINDING NOTES HERE>

```
## **SUPPORTING TOOLS**
## 6. SCOPE INDEX PROMPT

**Scope Index** is a navigational artifact for **manual smart contract audit** that replaces:

* mass file pinning in the IDE,
* Excel progress tables,
* chaotic repository navigation.



### Starting-prompt for Scope Index (paste the scope section from README and SLOC info)
```text
We are generating a draft Scope Index for manual code review.

Context:
- The pinned file "merged.txt" contains the full in-scope smart contracts.
- I will provide:
  1) The official scope definition from the README.
  2) A list of files with their SLOC, produced by an external tool.

Inputs:

[README SCOPE]
<PASTE THE SCOPE SECTION FROM README HERE>
[/README SCOPE]

[SLOC DATA]
<PASTE FILE PATH + SLOC DATA HERE>
[/SLOC DATA]

Task:
Produce a Scope Index in Markdown with the following rules:

Formatting:
- Use a navigation-style list (NOT a table).
- Each file must be a relative Markdown link, e.g.:
  [Vault.sol](./contracts/Vault.sol)
- Display SLOC next to each file.
- Add a short one-line description of the file’s purpose.

Structure:
- Group files by logical role:
  Core / Funds
  Accounting
  External Dependencies
  Admin / Governance
  Utilities
  Other (if needed)

Sorting:
- Within each group, sort files by descending SLOC (largest first).

Rules:
- Do NOT compute SLOC yourself.
- Do NOT include files outside the provided scope.
- Do NOT assess security or prioritize risk.
- If a file’s role is unclear, place it under "Other".

Output:
- A clean, human-readable Scope Index suitable for manual refinement.
```

## 7. REVIEW MODE CHAT — code completeness check

Review Mode is a **mode for checking the completeness and correctness of reasoning**, not an assessment of report quality or auditor level.

### Review Mode — initial prompt (select your preferred language)

```text
You are reviewing an existing security finding written by another auditor.

Goal:
Confirm that the finding is technically sound and reviewable.
This is NOT aggressive triage.
Default stance: the finding is potentially valid.

Source of truth:
- Use the pinned "merged.txt" as the full in-scope codebase.
- Use pinned project documentation (README / spec) if available.

Input:
- I will paste a colleague's finding (description + claimed impact + code references).
- If any referenced code is missing from the paste, locate it in merged.txt.

Tasks:
1) Reconstruct the exact code path(s) that the finding relies on.
2) Check whether the described behavior follows from the code (no assumptions).
3) Check whether the claimed impact follows from that behavior.
4) Explicitly list all assumptions required for the finding to hold.
5) Identify what could block acceptance by a triager (unclear steps, missing evidence).

Rules:
- Do NOT dismiss the finding unless it is clearly incorrect.
- Do NOT search for unrelated vulnerabilities.
- Do NOT expand scope or threat model.
- Do NOT re-evaluate severity.
- If borderline, specify exactly what clarification or evidence is missing.

Output (STRICT):
Assessment:
- Sound / Needs clarification / Likely invalid

Code Path Summary:
- Bullet list of functions and key state transitions

Key Assumptions:
- Explicit bullets ("Unknown" if cannot be established)

Impact Check:
- Yes / No / Partial + why

Reviewer Notes:
- What to improve or clarify in the writeup
- Optional: how to strengthen the argumentation

Language:
Respond in Russian unless explicitly requested otherwise.
```

### Short-prompt для Review Mode (English, low-noise)

```text
You are summarizing the review outcome of a security finding.

Context:
- The finding has been reviewed for code correctness and impact linkage.
- This is NOT a full review and NOT aggressive triage.

Task:
Provide a short, neutral explanation (2–4 sentences) in English
explaining why the finding is:
- invalid, OR
- significantly overstated in impact.

Rules:
- Be factual and concise.
- Reference code behavior or missing assumptions.
- Do NOT suggest fixes.
- Do NOT propose alternative attack paths.
- Do NOT discuss severity in abstract terms.
- No speculation.

Tone:
Professional, neutral, suitable for a triager or another auditor.

Output:
A single short paragraph (no bullets).
```

### Adversarial Reviewer / SHORT (EN)
```text
Provide a short, neutral explanation (2–4 sentences) in English
explaining why the finding is invalid or significantly overstated.

Rules:
- Be factual and concise
- Reference code behavior or missing assumptions
- No fixes, no alternative attack paths, no speculation

Output: a single short paragraph.
```


## 8. SCAN CHATS PROMPTS (select your preferred language)
### SCAN Paranoid Greedy
```text
Context:
Perform a broad and paranoid security scan of the smart contracts.

Goal:
List anything that looks suspicious, fragile, non-obvious, or inconsistent.

Instructions:
- Use the full code from merged.txt.
- Prefer false positives over false negatives.
- Do NOT validate findings or assess severity.
- Do NOT assume intended design is safe.

Focus areas:
- Missing or weak checks
- Unusual state transitions
- Edge states (zero supply, init, shutdown)
- Cross-contract interactions
- Anything that “looks wrong”

Output:
Bulleted list.
For each item:
- Short description
- Affected contracts/functions
- Why this might be risky

Language:
Respond in Russian.

```
### SCAN Access Lifecycle
```text
Context:
Perform a security scan focused on access control and lifecycle logic.

Goal:
Identify potential authorization, role, and lifecycle-related issues.

Instructions:
- Use the full code from merged.txt.
- Do NOT assume correct usage or trusted actors.
- Do NOT validate exploits or assign severity.

Focus areas:
- Access control and permissions
- Initialization and configuration
- Admin / privileged actions
- Upgrade or migration paths
- Pause / emergency / shutdown logic

Output:
Bulleted list.
For each item:
- Description of the access or lifecycle concern
- Affected functions or roles
- Why this could be abused or misused

Language:
Respond in Russian.

```
### SCAN Accounting State
```text
Context:
Perform a security scan focused on accounting and state management.

Goal:
Identify potential issues in balance handling, supply tracking,
and state invariants.

Instructions:
- Use the full code from merged.txt.
- Focus on how values flow and are updated.
- Do NOT validate exploits or assign severity.

Focus areas:
- Balance and supply updates
- Virtual vs real accounting
- Order of state updates
- Rounding, precision, accumulation
- Reset / zero-state behavior

Output:
Bulleted list.
For each item:
- Description of the questionable accounting/state behavior
- Relevant functions or variables
- Why this could break an invariant

Language:
Respond in Russian.

```
### SCAN Low Noise High Quality Code
```text
Context:
Perform a conservative security review of a high-quality smart contract codebase.

Goal:
Identify subtle, non-obvious issues that may exist
despite careful engineering and standard best practices.

Instructions:
- Use the full code from merged.txt.
- Assume the code is generally well-written.
- Avoid generic or surface-level findings.
- Do NOT list obvious checks or standard patterns.
- Prefer fewer, higher-quality observations.

Focus areas:
- Implicit assumptions that are not enforced in code
- Edge-case state transitions that are rarely exercised
- Cross-module or cross-function interactions
- Lifecycle boundaries (init → normal → shutdown)
- Invariants that rely on ordering or timing
- “This works unless X happens” situations

Output:
A short, curated list (ideally 5–10 items max).
For each item:
- Description of the subtle concern
- Where it appears in the code
- Why this assumption or interaction could be fragile

Do NOT:
- Assign severity
- Propose exploits
- Speculate wildly

Language:
Respond in Russian.

```
### SCAN Guard Consistency
```text
Context:
Perform a security scan focused on guard consistency across functions.

Goal:
Identify functions that are missing security guards (require/modifier checks)
that peer functions enforce on the same state.

Instructions:
- Use the full code from merged.txt.
- Build a mental usage graph of all require statements and modifiers.
- Apply the Consistency Principle: if guard G protects function A,
  and function B touches the same state, flag B if it lacks G.
- Do NOT validate exploits or assess severity.

Focus areas:
- Missing `nonReentrant` on functions with external calls
- Missing `whenNotPaused` on critical state-changing functions
- Missing access control on admin-adjacent operations
- Custom modifiers applied inconsistently
- Functions that bypass guards through internal call paths

Output:
For each finding:
- The guard that is inconsistently applied
- Functions WITH the guard vs functions WITHOUT
- Shared state variables between them
- Why this inconsistency could be exploitable

Language:
Respond in Russian.

```
### SCAN Invariant Detection
```text
Context:
Perform a security scan focused on state invariant detection.

Goal:
Infer mathematical relationships between state variables and flag
functions that could violate them.

Instructions:
- Use the full code from merged.txt.
- Automatically infer invariants: supply sums, conservation rules,
  collateral ratios, monotonic counters, synchronized updates.
- For each invariant, trace ALL functions that modify related state.
- Flag any function that could break the invariant.
- Do NOT validate exploits or assign severity.

Focus areas:
- totalSupply vs sum of balances (accounting desyncs)
- Share/asset ratios (first depositor, ERC-4626 inflation)
- Cross-contract state consistency (same value in multiple places)
- Accumulator updates (rewards, interest, fees) and missed updates
- Zero/near-zero edge states (empty pool, first/last user)
- Conservation of value across multi-step operations

Output:
For each invariant:
- The inferred relationship (mathematical expression)
- Functions that could violate it
- Edge cases that could trigger the violation
- Confidence: High / Medium / Low

Language:
Respond in Russian.

```
### SCAN Reentrancy Variants
```text
Context:
Perform a security scan focused on all reentrancy variants.

Goal:
Identify potential reentrancy beyond simple "state update after external call."

Instructions:
- Use the full code from merged.txt.
- Build a call graph of all external calls and state changes.
- Verify CEI (Checks-Effects-Interactions) compliance on every path.
- Do NOT validate exploits or assign severity.

Focus areas:
- Classic reentrancy: state updated after external call
- Cross-function reentrancy: external call in A, state read in B
- Cross-contract reentrancy: callback re-enters a different contract
- Read-only reentrancy: view function returns stale data during callback
- Callback-based: ERC-777 tokensReceived, ERC-1155 onReceived, ERC-721 onReceived
- Missing nonReentrant on functions that share state with guarded functions

Output:
Bulleted list.
For each item:
- Reentrancy variant type
- Call path (function → external call → potential reentry point)
- State variables at risk
- Whether nonReentrant or equivalent guard exists

Language:
Respond in Russian.

```
### SCAN External Call Safety
```text
Context:
Perform a security scan focused on external contract and token interactions.

Goal:
Identify potential issues with external calls, token integrations,
and non-standard token behaviors.

Instructions:
- Use the full code from merged.txt.
- Check every external call and token interaction.
- Do NOT validate exploits or assign severity.

Focus areas:
- Unchecked return values on transfer/transferFrom/approve
- Fee-on-transfer tokens: Does protocol assume received == sent?
- Rebasing tokens: Does balance change between reads without transfers?
- Non-standard ERC20: missing return value (USDT), decimals != 18, blocklist
- Unsafe approval patterns: approve without reset, infinite approval risks
- Callback exploitation: ERC-777 hooks, ERC-1155/721 receiver callbacks
- Low-level calls: .call{value:} without checking success
- Push vs pull payment patterns
- 63/64 gas rule exploitation on external calls

Output:
Bulleted list.
For each item:
- The external interaction at risk
- Token/contract assumptions made by the code
- What could go wrong with non-standard tokens or malicious contracts

Language:
Respond in Russian.

```
### SCAN Proxy & Upgrade Safety
```text
Context:
Perform a security scan focused on proxy and upgrade patterns.

Goal:
Identify potential issues in upgradeable contracts and proxy implementations.

Instructions:
- Use the full code from merged.txt.
- Check all proxy patterns, storage layouts, and upgrade paths.
- Do NOT validate exploits or assign severity.

Focus areas:
- Proxy pattern type (Transparent, UUPS, Beacon, Diamond/EIP-2535, Minimal)
- Storage layout collisions between proxy and implementation
- Uninitialized implementation contracts (can be initialized by attacker)
- Function selector clashes between proxy admin and implementation
- Missing storage gaps (__gap) in inherited contracts
- Unsafe upgrade paths that could break storage layout
- EIP-1967 standard slot compliance
- delegatecall target trust (immutable vs changeable)
- Constructor vs initializer usage

Output:
Bulleted list.
For each item:
- The specific proxy/upgrade concern
- Affected contracts and patterns
- Why this could lead to storage corruption or privilege escalation

Language:
Respond in Russian.

```
### SCAN low-noise-accounting
```text
Context:
Perform a conservative, low-noise review focused on accounting and invariants
in a high-quality Solidity codebase.

Goal:
Identify subtle accounting/state issues that could survive normal review.

Instructions:
- Use the full code from merged.txt.
- Assume the code is generally well-written.
- Avoid generic findings (missing access checks, basic reentrancy notes, etc.).
- Prefer a short list of high-signal concerns (5–10 items max).
- Do NOT assign severity or claim exploitation—flag fragility/invariants only.

Focus areas:
- Supply / balance invariants across functions (mint/burn/transfer/deposit/withdraw)
- “Virtual” vs “real” balance models (shares/assets, rebasing, indexes)
- Order-of-operations dependencies (effects vs checks vs external calls)
- Rounding / precision / dust accumulation and who benefits
- Accumulators and checkpoints (interest, rewards, fees) and missed updates
- Cross-module accounting (same value represented in multiple places)
- Zero / near-zero edge states (zero supply, first depositor, full exit)
- Time-based updates (block.timestamp) and stale state assumptions
- Replay/double-claim patterns (state not decremented or checkpoint not advanced)
- Invariant breaks triggered by rare sequences (A→B→A cycles)

Output:
A curated list (5–10 items max). For each item provide:
- The invariant/assumption that might be fragile
- Where it appears (contracts/functions/variables)
- A minimal “what could go wrong” description (no exploit path)

Do NOT:
- Propose PoCs
- Speculate wildly
- List obvious or boilerplate issues

Language:
Respond in Russian.

```

### SCAN Account Abstraction & EIP-7702
```text
Context:
Perform a security scan focused on Account Abstraction attack surfaces.

Goal:
Identify potential issues arising from ERC-4337, EIP-7702, and ERC-7579 interactions.

Instructions:
- Use the full code from merged.txt.
- Check all assumptions about msg.sender, tx.origin, and extcodesize.
- Do NOT validate exploits or assign severity.

Focus areas:
- tx.origin assumptions invalidated by EIP-7702 (delegated EOAs)
- msg.sender code assumptions (extcodesize, isContract) broken by 0xef0100 delegation prefix
- ERC-4337 EntryPoint interactions and paymaster trust
- Signature validation: SIG_VALIDATION_FAILED vs revert
- Cross-wallet signature replay (missing account-specific EIP-712 domain binding)
- Counterfactual wallet takeover (CREATE2 salt without owner credentials)
- Paymaster gas penalty exploitation (inflated callGasLimit)
- Transient storage contamination in multi-UserOperation bundles
- ERC-7579 module delegatecall storage access and uninstall lock
- EIP-7702 chainId=0 cross-chain authorization amplification
- Storage collision on EIP-7702 re-delegation (existing storage NOT cleared)

Output:
Bulleted list.
For each item:
- The AA-specific concern
- Which assumption is invalidated
- Affected contracts/functions
- Whether the concern is code-level or infrastructure-level

Language:
Respond in Russian.

```

### SCAN CPIMP & Deployment Safety
```text
Context:
Perform a security scan focused on Cross-Proxy Intermediary Malware Pattern (CPIMP)
and deployment safety.

Goal:
Identify potential front-running windows between proxy deployment and initialization.

Instructions:
- Use the full code from merged.txt.
- Check all proxy deployment patterns and initialization flows.
- Do NOT validate exploits or assign severity.

Focus areas:
- Proxy deployment atomicity: is deploy + initialize a single transaction?
- Front-runnable initialization windows
- Re-initialization possibilities (initializer vs reinitializer)
- CREATE2 deterministic deployment for multi-contract systems
- Post-deployment verification: can ERC-1967 slot be read directly?
- Event spoofing: can emitted events misdirect about implementation address?
- Block explorer reliance: can displayed implementation differ from actual?
- Process-layer vulnerabilities: deployment sequencing, upgrade windows invisible to code analysis

Output:
Bulleted list.
For each item:
- The deployment safety concern
- Time window or front-running opportunity
- Affected contracts and deployment flow

Language:
Respond in Russian.

```

### SCAN Transient Storage & EIP-1153
```text
Context:
Perform a security scan focused on EIP-1153 transient storage usage.

Goal:
Identify potential issues with transient storage semantics and cross-call persistence.

Instructions:
- Use the full code from merged.txt.
- Check all TSTORE/TLOAD usage and assumptions about data lifetime.
- Do NOT validate exploits or assign severity.

Focus areas:
- Cross-call persistence: transient values surviving external calls within a transaction
- Reentrancy lock bypass via transient storage
- ERC-4337 bundle contamination: transient values leaking between UserOperations
- Composability assumptions: protocols expecting single-call isolation
- Compiler bug SOL-2026-1: via-IR clearing both persistent and transient variables of same type
- Transient storage as pseudo-reentrancy guard: does it actually prevent re-entry?
- Gas implications: quadratic memory expansion costs

Output:
Bulleted list.
For each item:
- The transient storage concern
- The composability assumption violated
- Affected contracts/functions

Language:
Respond in Russian.

```

### SCAN L2 & Cross-Chain Security
```text
Context:
Perform a security scan focused on L2 deployment and cross-chain security.

Goal:
Identify potential issues from L2-specific behavior and cross-chain trust boundaries.

Instructions:
- Use the full code from merged.txt.
- Check all cross-chain assumptions and L2-specific code paths.
- Do NOT validate exploits or assign severity.

Focus areas:
- Opcode divergence: PUSH0, CREATE/CREATE2, SELFDESTRUCT behavior differences across L2s
- EIP-6780 adoption: SELFDESTRUCT restrictions NOT adopted on all L2s
- Sequencer centralization: downtime handling, forced inclusion bypass
- Chainlink L2 sequencer uptime feed: required before consuming price data on L2
- Bridge message verification: #1 vulnerability class in DeFi audits (61 findings empirical)
- Lock-and-mint architecture: concentrated target risk
- Mint-burn asymmetry: destination minting without verified source locking
- Finality assumptions: relay before source chain confirms = reorg attack window
- ZK proof replay: public inputs not bound to transaction-specific parameters
- DA saturation and prover killer attacks: EVM gas / ZK proving cost mismatch
- Cross-chain composability: different trust boundaries breaking security assumptions
- Metamorphic contracts: still exploitable on L2s without EIP-6780

Output:
Bulleted list.
For each item:
- The L2/cross-chain concern
- Which chains or environments are affected
- The trust boundary or assumption at risk

Language:
Respond in Russian.

```

### SCAN Token Integration Deep Dive
```text
Context:
Perform a deep security scan focused on non-standard token integration behaviors.

Goal:
Identify potential issues from the protocol's assumptions about token behavior,
given that 65.8% of deployed ERC-20s exhibit non-standard behaviors.

Instructions:
- Use the full code from merged.txt.
- Check all token interactions against the non-standard behavior database.
- Do NOT validate exploits or assign severity.

Focus areas:
- Fee-on-transfer: accounting assumes received == sent
- Rebasing tokens (stETH, aTokens): balance changes between reads
- Low-decimal tokens (GUSD: 2 decimals): vault inflation attack cost reduction
- Pausable/blocklist tokens (USDC, USDT): liquidation halt during price decline
- Flash-mintable tokens: totalSupply inflation affecting governance/pricing
- Upgradeable proxy tokens: USDC/USDT behavior can change post-integration
- Non-standard permit (DAI/RAI/GLM): silent return on bad signatures
- cUSDCv3 max-uint256 reinterpretation as "full balance"
- Dual ETH/WETH paths: double-counting on multi-chain (Celo/Polygon/zkSync)
- ERC-20 approval incompatibility matrix (USDT/BNB/OZ/permit)
- ERC-2612 permit phishing ($35M+ exploited)
- ERC-777 arbitrary hook assignment via ERC-1820 registry
- ERC-3156 flash loan side entrance and arbitrary initiator attacks
- Rebasing in AMMs: cached reserves diverge → free arbitrage

Output:
Bulleted list.
For each item:
- The specific token behavior assumption
- Which tokens would violate it
- Affected protocol functions

Language:
Respond in Russian.

```

### SCAN Compiler & Specification Completeness
```text
Context:
Perform a security scan focused on compiler trust boundary and specification gaps.

Goal:
Identify potential issues from compiler behavior, pipeline configuration,
and unstated developer assumptions.

Instructions:
- Use the full code from merged.txt.
- Check compiler version, pipeline flags, and developer assumptions.
- Do NOT validate exploits or assign severity.

Focus areas:
- Pragma version: exact vs floating
- via-IR pipeline: enabled? Known bugs (SOL-2026-1)?
- Optimizer settings: runs count, potential removal of "redundant" checks
- ABIEncoderV2 behavioral differences
- Yul/assembly div-by-zero returning 0 (not revert)
- Solidity pure/STATICCALL false guarantee: pure cannot prevent state reads at EVM level
- Modifier early returns: explicit returns don't affect function return values
- Developer assumption gaps (8 subtypes):
  - Step ordering, empty arrays, unchecked returns, unexpected matching
  - Uniqueness, mutual exclusivity, boundedness, sentinel reliability
- Audit coverage expiration: post-audit assumption changes
- Complementary function pair asymmetry: inverse functions not mirroring all state mutations

Output:
Bulleted list.
For each item:
- The compiler behavior or assumption concern
- Where it appears in the code
- The potential for behavioral divergence or specification gap

Language:
Respond in Russian.

```

### SCAN Governance & Timelock
```text
Context:
Perform a security scan focused on governance mechanisms and timelock patterns.

Goal:
Identify potential governance attack vectors and access control lifecycle issues.

Instructions:
- Use the full code from merged.txt.
- Check all governance, voting, and timelock patterns.
- Do NOT validate exploits or assign severity.

Focus areas:
- Flash loan governance: can voting power be acquired and used within one block?
- Snapshot-based voting: power measured at proposal creation time?
- CREATE2 metamorphic proposals: can proposal target code change between approval and execution?
- TimelockController: queued proposals without expiry? No-expiry = indefinite capability grant
- Emergency function paradox: emergency powers becoming the attack vector
- Low-participation quorum manipulation
- Rage quit mechanisms: credible exit threat vs governance DoS weapon
- Proposal code integrity verification at execution time (not just approval)
- Governance token concentration and delegation risks

Output:
Bulleted list.
For each item:
- The governance concern
- Affected contracts/functions
- The specific attack or failure mode

Language:
Respond in Russian.

```

### SCAN Liquidation & DeFi Economics
```text
Context:
Perform a security scan focused on liquidation mechanisms and DeFi economic design.

Goal:
Identify potential failures in liquidation, lending, and economic mechanisms.

Instructions:
- Use the full code from merged.txt.
- Check all liquidation, lending, and collateral-related logic.
- Do NOT validate exploits or assign severity.

Focus areas:
- 5 distinct liquidation failure mechanisms (each requires separate defense)
- Self-liquidation via flash loan (borrow → trigger own liquidation → profit from bonus)
- Fixed liquidation bonus revert below threshold (most underwater = unliquidatable)
- Asymmetric pause: repayments paused but liquidations active
- No grace period after unpause (instant liquidation race)
- Dust repayment front-running (liquidation DoS)
- 13 operational DoS mechanisms beyond economic failures
- Collateral in pausable tokens (USDC/USDT): halt during price decline → bad debt
- 100% utilization depositor trapping
- Oracle bounds: Chainlink min/maxAnswer stale price
- Interest rate curve failures at extreme utilization
- Borrower-liquidator timing/information asymmetry (11 patterns)

Output:
Bulleted list.
For each item:
- The economic/liquidation concern
- Affected contracts/functions
- The specific failure mode

Language:
Respond in Russian.

```

### SCAN Pashov 170-Vector Triage
```text
Context:
Perform a structured triage of the Pashov 170-vector attack surface
against the current codebase.

Goal:
Classify all 170 attack vectors into Skip/Borderline/Survive tiers,
then deep-dive surviving vectors with FP gate validation.

Instructions:
- Use the full code from merged.txt.
- Reference attack vectors from pashov-skills/attack-vectors/attack-vectors-{1,2,3,4}.md
- Apply finding validation from pashov-skills/finding-validation.md
- Do NOT write a full report — this is a triage pass.

Process:
1. Read all 4 attack vector files (170 vectors total).
2. For EACH vector, classify:
   - **Skip**: Named construct AND underlying concept both absent
   - **Borderline**: Named construct absent but underlying concept could manifest differently
   - **Survive**: Construct or pattern clearly present in codebase
3. For Borderline vectors: promote only if you can name the specific function + describe how exploit works in 1 sentence.
4. For Surviving vectors: apply FP gate (3 checks from finding-validation.md).
5. For each CONFIRMED vector: assign confidence score.

Output:
## Triage Summary
- Skip: V1, V2, ... (N vectors)
- Borderline: V8, V22, ... (N vectors) — with 1-sentence justification each
- Survive: V3, V16, ... (N vectors)
- Confirmed: V<N> [score] — brief description

## Recommended Follow-Up
Which SCAN modes or AUDIT AGENT roles to invoke for confirmed findings.

Language:
Respond in Russian.

```

### SCAN Pashov Cross-Chain & LayerZero Deep Dive
```text
Context:
Perform a deep security scan using Pashov LayerZero/cross-chain vectors.

Goal:
Identify cross-chain vulnerabilities using the 18 LayerZero-specific vectors
from the Pashov 170-vector database.

Instructions:
- Use the full code from merged.txt.
- Focus on vectors: V7, V24, V38-V39, V42, V44, V47, V59, V71, V114, V117, V119, V140, V142-V143, V156, V159-V160
- Reference: pashov-skills/attack-vectors/ for full vector descriptions
- Apply: pashov-skills/finding-validation.md for FP gate + confidence scoring
- Cross-reference: audit-workflow1.md Step 5.1j (L2 & Cross-Chain Security)

Focus areas:
- lzCompose sender impersonation (V7)
- Delegate privilege escalation (V38)
- Cross-chain supply accounting invariant violation (V39)
- Ordered message channel blocking / nonce DoS (V42)
- State-time lag exploitation / lzRead stale state (V44)
- OFT shared decimals truncation / uint64 overflow (V47)
- Cross-chain address ownership variance (V59)
- Missing enforcedOptions / insufficient gas (V71)
- Insufficient block confirmations / reorg (V114)
- Cross-chain message spoofing / missing peer validation (V117)
- Unauthorized peer initialization / fake peer attack (V119)
- Missing cross-chain rate limits / circuit breakers (V143)
- DVN collusion / insufficient diversity (V142)
- Default message library hijack (V160)
- Missing _debit authorization in OFT (V159)
- Cross-chain reentrancy via safe transfer callbacks (V156)

Output:
For each confirmed finding:
- Vector ID, confidence score, and 1-line description
- Contract.function location
- Attack path summary
- Recommended fix

Language:
Respond in Russian.

```

## 9. HYPOTHESES FORMULATION CHAT (experimental)
### Hypotheses Formulation Chat v0.1 — start-prompt (select your preferred language)
```text
Context:
This chat is dedicated to formulating security hypotheses.

Scope:
- Transform vague intuitions, discomfort, or unclear design choices
  into neutral, well-formed security hypotheses.
- Focus on assumptions, invariants, and non-obvious system states.
- Do NOT validate hypotheses.
- Do NOT analyze exploitability.
- Do NOT assess impact or severity.

Out of scope:
- Code path analysis.
- Adversarial reasoning.
- Proofs or refutations.
- Findings or report drafting.

Language policy:
- System instructions are in English.
- I will work primarily in Russian.
- Respond in Russian unless explicitly requested otherwise.

Your role:
Act as a hypothesis formulator.
Help me articulate *why something feels non-obvious or fragile*,
without asserting that it is a bug.
```

### Examples:
```text
The protocol has virtual shares and assets.
After all users exit, a non-zero virtual state remains.
It's not clear to me why this is safe.
Help formulate a correct hypothesis.

Below is an excerpt from an article about a hack of a similar protocol.
Don't look for bugs.
Help translate this into 2-3 neutral hypotheses,
that can be tested in a different design.

This hypothesis sounds too accusatory.
Reframe it so that it questions the assumption,
rather than asserting a risk.
```

## 10. UNIVERSAL SCOPE TRANSFER PROMPT
### Prompt for "moving context" to a new chat

You are the assistant preparing the context for moving a project to a new chat.
Please put together a brief but complete "context package" for the current conversation.

**Result Requirements:**

1. Write in a structured manner, without unnecessary fluff.
2. Don't invent anything that wasn't in the chat—if there's no information, mark it "not specified."
3. Include everything important for continuing work in the new chat.
4. Also note that the chat contains **pinned files**—list them and what they use (if known).

**Form your answer in this format:**

### 1) What is this project (1-3 sentences)

### 2) Goal / Expected Result

### 3) Current Status (what has already been done)

### 4) What are we currently discussing / deciding (main focus)

### 5) Key Decisions and Agreements (list)

### 6) Open Issues / Risks / What's Unclear

### 7) Next Steps (Todo Items for the Next 3-10 Tasks)

### 8) Terms / Entities / Important Names (Glossary)

### 9) Pinned Files and How They Are Used

* File Name → What is it for → Which Parts are Important

### 10) What does the new chat need from me (what input to ask the user)

Add a block at the end:
**"Short Version (up to 10)" lines)"** — so I can insert it as the starting context in a new chat.