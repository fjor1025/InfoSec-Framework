# Audit Assistant Playbook – Cairo/StarkNet Edition
## Cognitive Framework for Cairo Smart Contract Auditing

* **Status:** Experimental / Practitioner Tool
* **Audience:** Experienced smart contract auditors working with Cairo/StarkNet
* **Target Frameworks:** Cairo 1.x/2.x, StarkNet, L1↔L2 Bridges

This playbook describes a **minimal, reproducible flow** for working with LLMs when auditing **Cairo-based smart contracts on StarkNet**.

This playbook does NOT automate security audits.
It does NOT replace auditor judgment.
It structures how auditors think, explore, validate, and report findings.

---

## METHODOLOGY INTEGRATION

This playbook structures **conversations**. The actual audit **methodology** lives in:

| File | Purpose | When to Reference |
|------|---------|-------------------|
| `Cairo-Audit-Methodology.md` | Cairo-specific phases, checklists, attack patterns | During Code Path Explorer, hypothesis validation |
| `CommandInstruction-Cairo.md` | System prompt for Cairo audit sessions | At start of any audit chat |

**Key Methodology Concepts to Apply:**
- **Semantic Phases (Cairo):** VALIDATION → SNAPSHOT → ACCOUNTING → MUTATION → COMMIT → EVENTS → ERROR
- **Validation Checks:** Reachability, State Freshness, Execution Closure, Economic Realism
- **Known Patterns:** ClaudeSkills C1–C6 (felt252 overflow, unchecked L1 handler, address conversion, signature replay, message failure fund lock, overconstrained validation)
- **Cairo-Specific:** felt252 arithmetic, L1↔L2 messaging, storage layout, reentrancy, access control

---

## HOW TO USE THIS PLAYBOOK (REAL AUDIT FLOW)

**1. Prepare context**
* Build `merged.txt` with all in-scope `.cairo` files
* Gather project documentation (README, Scarb.toml, specs)
* Generate the Scope Index for navigation

**2. Initial understanding**
* Start with **Exploration**
* Work until the protocol model is stable (1–2 days depending on nSLOC)
* Focus on storage layout, external functions, L1↔L2 flows
* Make notes but do NOT search for bugs yet

**3. Hypotheses**
* Generate attack hypotheses in **Main**
* Include Cairo-specific attacks (felt252, L1↔L2, reentrancy)
* Perform first-pass validation
* Discard weak hypotheses early

**4. Deep analysis**
* Move surviving hypotheses into **Working**
* Use one or multiple Working chats as needed
* Focus on Cairo-specific concerns (felt math, storage, L1↔L2)
* Iterate: analysis → conclusion → report-ready notes

**5. Findings**
* When a real issue is confirmed, switch to **Drafting**
* Use the Cairo-specific drafting template
* Include felt252 analysis and PoC test code

**6. Coverage & signals**
* Use **SCAN** selectively as a signal generator
* Focus on Cairo-specific patterns (felt overflow, unchecked handlers, missing access control)
* Treat SCAN outputs as hints, not findings

**7. Review**
* Use **Review Mode** to check reasoning completeness
* Verify Cairo-specific claims (felt math, L1↔L2, storage)

**8. Iteration**
* When chats become heavy, transfer context and continue in new chat
* Avoid returning to Main late; continue via Working

---

## AUDIT LIFECYCLE — one-screen

```
[0] Local Setup
    └─ build merged.txt (all .cairo files)
    └─ collect docs (README, Scarb.toml, specs)
    └─ build scope index for manual audit

[1] Exploration
    └─ initial understanding of the protocol
    └─ map storage layout and external functions
    └─ understand L1↔L2 message architecture
    └─ make notes for further investigation

[2] Main — Idea Generation & Fast Filter
    └─ hypothesis generation (AI)
    └─ include Cairo-specific attacks (felt252, L1↔L2, reentrancy)
    └─ discard → out; questionable/alive → continue

[3] Manual Audit Marathon (loop)
    └─ manual code reading
    └─ focus on felt252 arithmetic, storage patterns

[4] Working — Deep Dive / Impact
    └─ surviving or interesting hypotheses
    └─ felt252 overflow analysis
    └─ L1↔L2 message security tracing
    └─ preparing report raw material

[5] Drafting
    └─ formatting findings
    └─ Cairo-specific PoC test code
    └─ report format
```

### Key Properties
* Exploration — **mode**, not a phase (found in [1] and [3])
* Hypotheses — **consumable**
* Main — **hypothesis pipeline**, a single chat per project
* Working — **live thinking zone**

> **AI accelerates filtering and formalization.
> Humans make decisions and sense the design.**

---

## **CORE AUDIT FLOW**

## 1. BUILD LAYER

### Purpose
Prepare **one friendly file** with all in-scope Cairo code.

### Input
* Working directory with **only in-scope Cairo files**
* No test files unless in scope

### Build command (Cairo)
```bash
(
  echo "INDEX"
  find . -name "*.cairo" -type f ! -name "*_test.cairo" | sort
  echo ""
  echo "=== SCARB.TOML ==="
  cat Scarb.toml 2>/dev/null || echo "No Scarb.toml found"
  echo ""
  echo "=== SOURCE FILES ==="
  find . -name "*.cairo" -type f ! -name "*_test.cairo" | sort | while read f; do
    echo "FILE: $f"
    cat "$f"
    echo "END FILE: $f"
    echo ""
  done
) > merged.txt
```

### Output
`merged.txt` with the following structure:
* INDEX (file paths)
* SCARB.TOML (for dependency context — OpenZeppelin, etc.)
* FILE / END FILE blocks

`merged.txt` **attached to the chats** and used in all steps.

---

## 2. MAIN CHAT PROMPTS

### General Rules
* One run = one role
* One run = one mental task
* Response format **strictly fixed**

---

### 2.1 Protocol Mapper (Cairo Edition)

**Role:** Building a mental model of the Cairo protocol

```text
[AUDIT AGENT: Protocol Mapper]

Instructions:
Follow the section "Protocol Mapper" EXACTLY (role + required output structure).

Available Code Context:
- The pinned file "merged.txt" contains the full in-scope Cairo smart contracts.

Additional Context (README / spec / docs):
- Use pinned project documentation if available.
- If no docs are pinned, ask me to paste relevant excerpts before making assumptions.

Task:
Produce the protocol model strictly in the required output structure.
Do NOT speculate. If information is missing, write "Unknown".

[ROLE: Protocol Mapper - Cairo Edition]

You are a senior Cairo/StarkNet security auditor.

Analyze the provided Cairo code and documentation.

Your task is NOT to find bugs yet.
Your task is to build a precise mental model of the protocol.

You MUST output strictly in the structure defined below.
No additional sections are allowed.

1. Protocol Purpose
- What problem does it solve?
- What framework? (Cairo 1.x/2.x, OpenZeppelin components, custom)

2. Assets
- What assets are at risk? (tokens, balances, NFTs, accounting units)
- How are they represented? (u256, felt252, custom types)

3. Trust Assumptions
- External dependencies (oracles, bridges, L1 contracts)
- Privileged roles (admin, owner, upgrader)
- Upgradeability assumptions (proxy pattern?)

4. Storage Layout
- Key storage variables and their types
- LegacyMap/Map usage and key construction
- Multi-contract storage relationships

5. Critical Flows
- User flows involving assets (deposit, withdraw, swap, stake)
- Admin flows (upgrade, configure, emergency)
- L1↔L2 flows (deposits, withdrawals, message passing)
- For each flow, identify semantic phases: VALIDATION → SNAPSHOT → ACCOUNTING → MUTATION → COMMIT → EVENTS

6. Invariants
- What must always be true for the protocol to remain solvent?
- Storage invariants?
- L1↔L2 balance invariants?
- Reference: Universal invariants (no free money, no double spending, etc.)

7. Cairo-Specific Concerns
- felt252 arithmetic locations?
- L1↔L2 handler security?
- Reentrancy potential via external calls?
- Access control patterns (OZ Ownable, custom)?
- Account abstraction usage?

8. External Integrations
- L1 contracts (Solidity side)
- Other StarkNet contracts
- Oracles, bridges, AMMs

Do NOT speculate.
If information is missing, explicitly say "Unknown".

[END]
```

---

### 2.2 Attack Hypothesis Generator (Cairo Edition)

**Role:** Generating Cairo-specific attack scenarios

```text
[AUDIT AGENT: Attack Hypothesis Generator]

Instructions:
Follow the section "Attack Hypothesis Generator" EXACTLY
(role definition + constraints + output format).

Available Code Context:
- The pinned file "merged.txt" contains the full in-scope Cairo smart contracts.

Protocol Context:
- Use the protocol model already produced in this chat by the Protocol Mapper.
- If the protocol model is missing or incomplete, ask me to provide it before proceeding.

Task:
Generate a bounded set of plausible attack hypotheses.
Do NOT validate exploits.
Do NOT search for concrete bugs yet.

[ROLE: Attack Hypothesis Generator - Cairo Edition]

You are an adversarial security researcher specializing in Cairo/StarkNet code.

Your task is to enumerate plausible ways the protocol *could* fail,
assuming adversarial behavior, but without validating feasibility yet.

You are NOT validating exploits.
You are NOT proving impact.
You are generating hypotheses to be checked later.

Constraints:
- Generate at most **15 hypotheses**.
- Focus on scenarios that could lead to:
  - Loss of funds
  - Protocol insolvency
  - Denial of service
  - Privilege escalation
  - Irreversible state corruption
  - L1↔L2 message manipulation
- Hypotheses must be:
  - Neutral
  - Technically plausible
  - Grounded in protocol design and Cairo-specific risks
- Include Cairo-specific attack vectors:
  - felt252 arithmetic overflow/wrapping
  - Unchecked L1 handler callers
  - Storage key collisions
  - Reentrancy via external contract calls
  - get_caller_address() == 0 exploitation
  - Serde deserialization issues
- Reference known exploit patterns:
  - ClaudeSkills: C1 (felt252 overflow), C2 (unchecked L1 handler), C3 (address conversion),
    C4 (signature replay), C5 (message failure fund lock), C6 (overconstrained validation)
- Do NOT include purely speculative or unrealistic attacks.

Output STRICTLY in the following format:

For each hypothesis:

H<N>. <Short title>

Semantic Phase:
- Which phase is vulnerable? [VALIDATION/SNAPSHOT/ACCOUNTING/MUTATION/COMMIT/EVENTS/ERROR]
- Cross-phase interaction? (e.g., Snapshot→Mutation race)

Cairo-Specific Vector:
- felt252 issue? L1↔L2? Storage? Reentrancy? Access control?

Threat Model:
- Who is the adversary?
- What capabilities or privileges do they have?

Attack Idea:
- High-level description of the potential failure mode.
- Similar to known exploit? [ClaudeSkills C1–C6 if applicable]

Required Conditions:
- What must be true for this attack to work?

What to Inspect in Code:
- Specific functions, storage variables, or L1↔L2 handlers
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

---

### 2.3 Code Path Explorer (Cairo Edition)

**Role:** Deep testing of one hypothesis with Cairo-specific analysis

```text
[AUDIT AGENT: Code Path Explorer]

Instructions:
Follow the section "Code Path Explorer" EXACTLY
(role definition + rules + output format).

Available Code Context:
The pinned file "merged.txt" contains the full in-scope Cairo smart contracts.

Attack Hypothesis:
- Use hypothesis H<N> from the current Main Chat.
- Do NOT reinterpret or reformulate it unless explicitly asked.

Important: Do NOT analyze any hypothesis until I specify the exact H<N>.

Task:
Decide Valid / Invalid / Inconclusive and justify by tracing code paths.
Do NOT assume mitigations unless explicitly enforced in code.

[ROLE: Code Path Explorer - Cairo Edition]

You are performing a deep logic audit of Cairo/StarkNet code.

Use merged.txt to locate and analyze the relevant functions and code paths.
Your task is to determine whether a specific attack hypothesis
actually follows from the code.

**Methodology Reference:**
- Apply semantic phase analysis (VALIDATION → COMMIT → ERROR)
- Use the Cairo-specific checklists from methodology
- Trace felt252 arithmetic and L1↔L2 message flows

Your goals:
- Trace execution paths by semantic phase
- Track felt252 vs u256 arithmetic safety
- Identify L1↔L2 message vulnerabilities
- Check storage collision potential
- Analyze reentrancy via external calls

Rules:
- Analyze exactly ONE hypothesis per run, specified by me as H<N>.
- Do NOT introduce new hypotheses.
- Do NOT expand scope beyond what the hypothesis assumes.
- Do NOT assume mitigations unless explicitly enforced in code.

When I provide H<N>, output STRICTLY:

Hypothesis:
- H<N> — <short title>

Cairo-Specific Analysis:
- felt252 arithmetic: Safe / Unsafe — where?
- L1↔L2 messages: Validated / Unvalidated — which handlers?
- Storage: Isolated / Collision risk — which mappings?
- Reentrancy: Safe / Unsafe — which external calls?
- Access control: Present / Missing — which functions?

Semantic Phase Trace:
- VALIDATION: What checks exist? Can they be bypassed?
- SNAPSHOT: What state is loaded? Default values dangerous?
- ACCOUNTING: Any felt252 calculations? Rounding issues?
- MUTATION: What changes? Is value conserved?
- COMMIT: Is state consistently written?
- EVENTS: Are all changes logged?
- ERROR: What happens on failure? Is state cleaned up?

Hypothesis Status:
- Valid / Invalid / Inconclusive

Validation Checks (ALL must pass for Valid):
- [ ] Reachability: Can this path execute on StarkNet?
- [ ] State Freshness: Does it work with current storage state?
- [ ] Execution Closure: Are external calls modeled?
- [ ] Economic Realism: Is cost/timing feasible?

Detailed Reasoning:
- Step-by-step reasoning through the code paths
- Include felt252 arithmetic analysis where relevant

Potential Exploit Path:
- If valid, describe a concrete exploit scenario with Cairo test code
- If invalid, explain what prevents exploitation

Do NOT assume mitigations unless they are explicitly enforced in code.

[END]
```

#### Code Path Explorer / CONTINUE
```text
Continue in Code Path Explorer mode.

Now analyze hypothesis H<N> from the list above.
Do NOT restate the hypothesis unless necessary.
Use the same STRICT output format.
```

#### Code Path Explorer / REGROUND
```text
Re-grounding:

We are still in Code Path Explorer mode.
Analyze ONLY hypothesis H<N>.
Use merged.txt as the source of truth.
Do NOT introduce new hypotheses or assumptions.
Follow the same STRICT output format.
```

---

### 2.4 Adversarial Reviewer (Cairo Edition)

**Role:** Anti-false-positive with Cairo-specific verification

```text
[AUDIT AGENT: Adversarial Reviewer]

Instructions:
Follow the section "Adversarial Reviewer" EXACTLY
(role definition + rules + output format).

Available Code Context:
The pinned file "merged.txt" contains the full in-scope Cairo smart contracts.

Finding Under Review:
- I will paste a single security finding written by an auditor.
- Do NOT review anything until the finding is provided.

Task:
Assess whether the finding would survive triage.

[ROLE: Adversarial Reviewer - Cairo Edition]

You are acting as a strict security triager for Cairo/StarkNet code.

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
- If the finding claims specific Cairo behavior, you MUST verify it:
  - felt252 arithmetic claims (does it actually wrap?)
  - L1↔L2 message claims (is the handler actually unprotected?)
  - Storage claims (can keys actually collide?)
  - Reentrancy claims (does the call actually allow reentry?)
- If verification is impossible, mark it explicitly.

When the finding is provided, output STRICTLY:

Assessment:
- Valid / Invalid / Context-dependent

Cairo-Specific Verification:
- felt252 claims: Confirmed / Not confirmed
- L1↔L2 claims: Confirmed / Not confirmed
- Storage claims: Confirmed / Not confirmed
- Reentrancy claims: Confirmed / Not confirmed
- Access control claims: Confirmed / Not confirmed

Counterarguments:
- What assumptions or steps are not proven by the finding

Code Verification:
- Confirmed / Not confirmed / Partially confirmed
- Reference exact functions or storage where relevant

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
Pay special attention to Cairo-specific claims.
Do NOT introduce new vulnerabilities or scope.
Follow the same STRICT output format.
```

---

## 3. EXPLORATION CHAT PROMPTS (Cairo Edition)

### Purpose
**Exploration Chat** is a mode for collaboratively *understanding* a Cairo protocol before formalizing hypotheses.

### Universal Starter Query
```text
We are in the exploration phase.

Context:
- The pinned file "merged.txt" contains the full in-scope Cairo smart contracts.
- No test files are included (only first-party contract code).
- I am trying to understand the protocol design and developer intent.

Your role:
Act as a senior Cairo protocol developer / architect.
Explain what the code is trying to achieve, not whether it is secure.

Rules:
- Do NOT look for vulnerabilities.
- Do NOT assess security or exploitability.
- Do NOT speculate beyond what can be inferred from code.
- If intent or assumptions are unclear, explicitly say so.

Task:
1) Give a high-level explanation of the protocol architecture.
2) Explain the storage layout and contract structure.
3) Identify key design decisions that are non-obvious.
4) List the main assumptions the design relies on.
5) Point out areas that are complex or easy to misunderstand.
6) Note any Cairo-specific patterns (felt252 usage, L1↔L2, OZ components).

Focus on "why" and "how", not on "is it safe".

We will discuss specific files and functions step by step.
```

### Exploration Re-grounding
```text
Re-grounding:
We are still in Exploration Chat.
Use the pinned file "merged.txt" as the source of truth.
Do not ask me to provide code that already exists in merged.txt.
When answering, reference exact functions/files from merged.txt.
If something cannot be found there, say so explicitly.
```

### Move to New Contract
```text
Re-grounding before new topic:
We are continuing exploration of the same codebase.
Focus now on <CONTRACT / MODULE>.
Use merged.txt and cite exact locations.
Explain the storage layout and external function flow in this contract.
```

---

## 4. WORKING CHAT PROMPTS (Cairo Edition)

### Universal Starter Query
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
- Impact analysis (funds, accounting, availability, trust).
- Cairo-specific concerns:
  - felt252 arithmetic through the attack path
  - L1↔L2 message flow integrity
  - Storage collision potential
  - Reentrancy via external calls
- Secondary and cascading effects.
- Alternative actors, timings, and conditions.
- Whether the issue is reportable, and under what assumptions.

Allowed:
- Debate and challenge the hypothesis.
- Revisit validity if impact analysis reveals flaws.
- Explore multiple interpretations of the same issue.

Optional support:
- Help formulate PoC requirements in Cairo test format
  (do NOT implement PoCs unless explicitly requested).

Out of scope:
- Generating new unrelated hypotheses.
- Auto-audit loops or mass scanning.
- Final report writing (handled elsewhere).

Source of truth:
- Use the pinned merged.txt and project documentation.

Your role:
Act as a senior Cairo security auditor assisting in impact extraction
and finding shaping, not as an automated validator.

Hypothesis (ID, threat model, attack idea, conditions, what to inspect):

```

### Short Prompt for Hypothesis List
```text
We continue the Working Chat.

Context:
- The list of hypotheses H1..Hn is already known.
- We are now analyzing hypothesis H<N>.

Task:
Validate or invalidate this hypothesis based on code paths.
Pay special attention to:
- felt252 arithmetic safety
- L1↔L2 message validation
- Storage key isolation
- Reentrancy via external calls
```

### Finding Template for Drafting
```text
Finding source: Working Chat

Summary:
<1–2 sentences, gist of the problem>

Cairo-Specific Details:
- felt252 issue: [Yes/No — describe]
- L1↔L2 issue: [Yes/No — describe]
- Storage issue: [Yes/No — describe]
- Reentrancy: [Yes/No — describe]
- Access control: [Yes/No — describe]

Impact:
<what breaks / what risk>

Conditions:
<under what conditions, roles, states>

Code snippets:
<functions with felt252 / storage / L1↔L2 annotations>

Notes:
<anything important to keep but not included above>
```

---

## 5. FINDING DRAFTING CHAT PROMPTS (Cairo Edition)

### Purpose
Preparing a clear, triage-friendly report on an already identified Cairo issue.

### Starting Prompt
```text
We are in the finding drafting phase.

Context:
- The vulnerability has already been validated in a Working Chat.
- This chat is dedicated to preparing a clear, accurate vulnerability report.
- The pinned file "merged.txt" contains the full in-scope Cairo smart contracts.

Your role:
Act as an experienced Cairo/StarkNet security auditor and bug bounty triager.

General Rules:
- Do NOT invent new attack paths.
- Do NOT expand scope beyond the validated issue.
- Do NOT exaggerate impact.
- Be precise, conservative, and technically accurate.
- Include Cairo-specific details:
  - felt252 arithmetic analysis if relevant
  - L1↔L2 message flow if applicable
  - Storage layout concerns
  - Reentrancy implications
- Clearly separate:
  - Facts from assumptions
  - Guaranteed behavior from configuration-dependent behavior

Templates:
- A report template MAY be provided by me.
- If a template is provided, follow it EXACTLY.
- If no template is provided, ask which template or severity level should be used.

Task:
Given a validated vulnerability description, help structure and refine
a triage-friendly report that matches the provided template and severity level.

Goal:
Produce a report that a triager can quickly understand, validate, and classify
without ambiguity.
```

### Cairo-Specific Finding Template
```text
## [SEVERITY] <Title>

### Summary
<1-2 sentences describing the issue>

### Vulnerability Details

**Location:**
- File: `src/contracts/vault.cairo`
- Function: `withdraw`
- Lines: L<start>-L<end>

**Cairo-Specific Classification:**
- [ ] felt252 arithmetic overflow/wrapping
- [ ] Unchecked L1 handler caller
- [ ] Storage key collision
- [ ] Reentrancy via external call
- [ ] Missing access control
- [ ] Serde deserialization vulnerability
- [ ] Account abstraction bypass

**Root Cause:**
<Technical explanation of why the bug exists>

**Semantic Phase:**
<VALIDATION/SNAPSHOT/ACCOUNTING/MUTATION/COMMIT/EVENTS/ERROR>

### Impact
<What breaks, who loses what, severity justification>

### Proof of Concept

```cairo
#[test]
fn test_exploit() {
    // Setup
    let contract = deploy_contract();
    
    // Attack steps
    // ...
    
    // Verify impact
    assert(/* state corruption demonstrated */);
}
```

### Recommended Fix

```cairo
// Before (vulnerable)
<vulnerable code>

// After (fixed)
<fixed code>
```

### References
- ClaudeSkills Pattern: [C1–C6 if applicable]
- Similar to: <known exploit if applicable>
```

---

## 6. SCOPE INDEX PROMPT (Cairo Edition)

### Purpose
Generate navigational artifact for Cairo codebase review.

### Starting Prompt
```text
We are generating a draft Scope Index for manual Cairo code review.

Context:
- The pinned file "merged.txt" contains the full in-scope Cairo smart contracts.
- I will provide:
  1) The official scope definition from the README.
  2) A list of files with their SLOC.

Inputs:

[README SCOPE]
<PASTE SCOPE SECTION>
[/README SCOPE]

[SLOC DATA]
<PASTE FILE + SLOC>
[/SLOC DATA]

Task:
Produce a Scope Index in Markdown with the following rules:

Formatting:
- Use a navigation-style list (NOT a table).
- Each file must be a relative Markdown link.
- Display SLOC next to each file.
- Add a short one-line description of the file's purpose.

Structure (Cairo-specific):
- Contracts (`src/contracts/`)
- Components / Traits (`src/components/`, trait definitions)
- L1↔L2 Handlers (`l1_handler` functions)
- Storage & Types (`src/types/`, storage structs)
- Interfaces (`src/interfaces/`)
- Utilities / Helpers
- Other

Sorting:
- Within each group, sort by descending SLOC.

Rules:
- Do NOT compute SLOC yourself.
- Do NOT include files outside the provided scope.
- Do NOT assess security or prioritize risk.
- If a file's role is unclear, place it under "Other".

Output:
A clean, human-readable Scope Index suitable for manual refinement.
```

---

## 7. REVIEW MODE CHAT (Cairo Edition)

### Purpose
Check completeness and correctness of Cairo-specific reasoning.

### Starting Prompt
```text
You are reviewing an existing security finding for Cairo/StarkNet code.

Goal:
Confirm that the finding is technically sound and reviewable.
This is NOT aggressive triage.
Default stance: the finding is potentially valid.

Source of truth:
- Use the pinned "merged.txt" as the full in-scope codebase.

Input:
- I will paste a colleague's finding (description + claimed impact + code references).

Tasks:
1) Reconstruct the exact code path(s) that the finding relies on.
2) Verify Cairo-specific claims:
   - felt252 arithmetic behavior
   - L1↔L2 message handling
   - Storage layout correctness
   - Reentrancy conditions
   - Access control enforcement
3) Check whether the described behavior follows from the code.
4) Check whether the claimed impact follows from that behavior.
5) Explicitly list all assumptions required for the finding to hold.
6) Identify what could block acceptance by a triager.

Rules:
- Do NOT dismiss the finding unless it is clearly incorrect.
- Do NOT search for unrelated vulnerabilities.
- Do NOT expand scope or threat model.
- Do NOT re-evaluate severity.
- If borderline, specify exactly what clarification is missing.

Output (STRICT):

Assessment:
- Sound / Needs clarification / Likely invalid

Cairo-Specific Verification:
- felt252 claims: Verified / Not verified
- L1↔L2 claims: Verified / Not verified
- Storage claims: Verified / Not verified
- Reentrancy claims: Verified / Not verified
- Access control claims: Verified / Not verified

Code Path Summary:
- Bullet list of functions and key state transitions

Key Assumptions:
- Explicit bullets ("Unknown" if cannot be established)

Impact Check:
- Yes / No / Partial + why

Reviewer Notes:
- What to improve or clarify in the writeup
```

---

## 8. SCAN CHATS PROMPTS (Cairo Edition)

### SCAN Paranoid Greedy (Cairo)
```text
Context:
Perform a broad and paranoid security scan of the Cairo smart contracts.

Goal:
List anything that looks suspicious, fragile, non-obvious, or inconsistent.

Instructions:
- Use the full code from merged.txt.
- Prefer false positives over false negatives.
- Do NOT validate findings or assess severity.

Cairo-Specific Focus:
- felt252 arithmetic without bounds checks
- L1 handlers without from_address validation
- External functions without access control
- External calls before state updates (reentrancy)
- Storage mappings with potential key collisions
- get_caller_address() without zero-address handling
- Serde deserialization without validation

General Focus:
- Missing or weak checks
- Unusual state transitions
- Edge states (zero supply, initialization, upgrade)
- Cross-contract interactions

Output:
Bulleted list.
For each item:
- Short description
- Affected file/function
- Why this might be risky (Cairo-specific reason if applicable)
```

### SCAN felt252 Safety
```text
Context:
Scan for felt252 arithmetic issues in Cairo smart contracts.

Goal:
Identify all locations where felt252 arithmetic may be unsafe.

Focus:
- Subtraction operations on felt252 (wrapping risk)
- Multiplication overflow
- Division by zero
- Conversions between felt252 and u128/u256/ContractAddress
- Comparisons on felt252 (modular arithmetic makes < > unreliable)

Output:
For each issue:
- Location (file:function:line)
- Operation type (subtract/multiply/divide/convert)
- Why it might wrap or overflow
- Suggested fix (use u256, add bounds check, etc.)
```

### SCAN L1↔L2 Security
```text
Context:
Scan for L1↔L2 messaging issues in Cairo smart contracts.

Goal:
Identify all L1↔L2 handler and messaging vulnerabilities.

Focus:
- l1_handler functions without from_address validation
- send_message_to_l1 without proper data encoding
- Missing message consumption tracking (replay risk)
- Fund locking scenarios (L1 message sent but never consumed on L2)
- Address conversion issues (felt252 ↔ Ethereum address)

Output:
For each issue:
- Location (file:function)
- Message direction (L1→L2 or L2→L1)
- Why it might be exploitable
- Recommended validation
```

### SCAN Access Control
```text
Context:
Scan for access control issues in Cairo smart contracts.

Goal:
Identify all external functions that may lack proper access control.

Focus:
- #[external(v0)] functions without get_caller_address() checks
- Functions that modify storage without authorization
- Admin functions callable by non-admin addresses
- Initializers that can be called multiple times
- Upgrade functions without owner validation

Output:
For each issue:
- Location (file:function)
- What the function does
- Why missing access control is dangerous
- Recommended access control pattern
```

---

## 9. HYPOTHESES FORMULATION CHAT (Cairo Edition)

### Purpose
Interactive brainstorming session to develop Cairo-specific attack hypotheses
through dialogue, combining auditor intuition with AI's code analysis capability.

### Starting Prompt
```text
We are in hypothesis formulation mode.

Context:
- The pinned file "merged.txt" contains the full in-scope Cairo smart contracts.
- The protocol model has been established (from Exploration or Protocol Mapper).

Your role:
Act as a senior Cairo/StarkNet security researcher.
We are brainstorming potential attack vectors together.

Rules:
- Focus on Cairo-specific attack surfaces:
  1. felt252 arithmetic edge cases
  2. L1↔L2 message manipulation
  3. Storage layout collisions
  4. Reentrancy patterns
  5. Access control gaps
  6. Account abstraction bypasses
- For each hypothesis, provide:
  - The specific code location to investigate
  - Why Cairo's type system / architecture makes this possible
  - What conditions must hold for the attack to work
- Reference ClaudeSkills patterns C1–C6 when applicable
- Be creative but grounded in the code

Let's start. I'll share my initial thoughts and you build on them.
```

### Example Hypothesis Development
```text
I'm looking at the vault contract. The withdraw function does:
1. Reads balance from storage (felt252)
2. Subtracts the withdrawal amount
3. Makes external call to token contract
4. Writes new balance to storage

My concern: Steps 2 and 3 could have issues because:
- The subtraction on felt252 wraps instead of reverting
- The external call in step 3 could allow reentrancy

Can you trace this exact code path and tell me:
1. Does the code use felt252 or u256 for the balance?
2. Is there a bounds check before the subtraction?
3. Is there a reentrancy guard?
4. This reminds me of ClaudeSkills C1 (felt252 overflow) — does the pattern match?
```

---

## 10. UNIVERSAL SCOPE TRANSFER PROMPT (Cairo Edition)

### Purpose
Transfer accumulated audit context to a new chat when the current chat becomes too long.

### Prompt
```text
You are continuing a Cairo/StarkNet smart contract security audit.

All previous context is transferred below. Do NOT re-analyze from scratch.
Continue from where we left off.

## PROTOCOL CONTEXT
- Project: [name]
- Framework: [Cairo 1.x / 2.x]
- Chain: StarkNet [mainnet / testnet / devnet]
- Dependencies: [OpenZeppelin version, other libraries]
- Key contracts: [list main contracts]
- L1↔L2: [yes/no, describe message flow]

## CAIRO-SPECIFIC CONTEXT
- felt252 usage: [where, for what]
- Storage pattern: [LegacyMap / Map / custom]
- External calls: [which contracts, which functions]
- Access control: [OZ Ownable / custom / none]
- Known danger points: [list]

## AUDIT STATE
- Hypotheses generated: [H1..Hn summary]
- Hypotheses validated: [list with Valid/Invalid/Inconclusive]
- Hypotheses remaining: [list]
- Findings confirmed: [summary of each]
- Findings in progress: [what's being analyzed]

## SCOPE INDEX
[paste scope index]

## CURRENT TASK
[what to do next]

## DOCUMENTS IN PLAY
1. `CommandInstruction-Cairo.md` — System prompt (binding rules, validation checks)
2. `Cairo-Audit-Methodology.md` — Phases, checklists, ClaudeSkills patterns C1–C6
3. `Audit_Assistant_Playbook_Cairo.md` — This playbook (conversation structure)
4. `merged.txt` — Full source code (pinned)

## INSTRUCTIONS
- Continue the audit from the current state
- Do NOT repeat completed analysis
- Follow the same methodology and output formats
- Apply all Cairo-specific checks from the system prompt
```

---

## APPENDIX: QUICK REFERENCE

### Semantic Phases (Cairo)
| Phase | Indicators | Key Checks |
|-------|------------|------------|
| VALIDATION | `assert`, `assert_eq`, early checks | Complete? Access control? |
| SNAPSHOT | `self.var.read()`, storage reads | Zero defaults? Missing keys? |
| ACCOUNTING | Arithmetic, oracle reads | felt252 safety? Rounding? |
| MUTATION | `self.var.write()`, state changes | Conservation? CEI pattern? |
| COMMIT | Final storage writes | Atomic? Consistent? |
| EVENTS | `self.emit()`, event emission | Complete? After changes? |
| ERROR | `assert` failure, `panic` | State cleanup? Rollback? |

### Cairo Red Flags
```
balance - amount  → felt252 wrap check
l1_handler        → from_address validated?
#[external(v0)]   → access control present?
Dispatcher call   → reentrancy guard?
.read() == 0      → is zero a valid state?
get_caller_address → handles sequencer (zero)?
```

### Validation Checks
| Check | Pass Criteria |
|-------|--------------|
| Reachability | Function is external or l1_handler |
| State Freshness | Works with realistic storage state |
| Execution Closure | External calls modeled |
| Economic Realism | Gas/timing/capital feasible |

---

**Framework Version:** 2.0
**Last Updated:** January 2026
**Target Ecosystems:** Cairo 1.x/2.x, StarkNet, L1↔L2 Bridges
