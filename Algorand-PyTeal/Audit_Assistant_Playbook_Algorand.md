# Audit Assistant Playbook – Algorand/PyTeal Edition
## Cognitive Framework for Algorand Smart Contract Auditing

* **Status:** Experimental / Practitioner Tool
* **Audience:** Experienced smart contract auditors working with Algorand
* **Target Frameworks:** PyTeal, TEAL, ARC4, Beaker

This playbook describes a **minimal, reproducible flow** for working with LLMs when auditing **Algorand smart contracts**.

This playbook does NOT automate security audits.
It does NOT replace auditor judgment.
It structures how auditors think, explore, validate, and report findings.

---

## METHODOLOGY INTEGRATION

This playbook structures **conversations**. The actual audit **methodology** lives in:

| File | Purpose | When to Reference |
|------|---------|-------------------|
| `Algorand-Audit-Methodology.md` | Algorand-specific phases, checklists, attack patterns | During Code Path Explorer, hypothesis validation |
| `CommandInstruction-Algorand.md` | System prompt for Algorand audit sessions | At start of any audit chat |

**Key Methodology Concepts to Apply:**
- **Transaction Field Validation:** RekeyTo, CloseRemainderTo, AssetCloseTo, Fee
- **Validation Checks:** Reachability, State Freshness, Execution Closure, Economic Realism
- **Known Patterns:** ClaudeSkills A1–A9 (rekey, fee, close, asset close, group size, access control, asset ID, inner tx fee, clear state)
- **Algorand-Specific:** Group transactions, inner transactions, clear state program, smart signatures

---

## HOW TO USE THIS PLAYBOOK (REAL AUDIT FLOW)

**1. Prepare context**
* Build `merged.txt` with all in-scope `.py` / `.teal` files
* Gather project documentation (README, specs)
* Generate the Scope Index for navigation

**2. Initial understanding**
* Start with **Exploration**
* Work until the protocol model is stable
* Focus on OnComplete handlers, group structures, state schema
* Make notes but do NOT search for bugs yet

**3. Hypotheses**
* Generate attack hypotheses in **Main**
* Include Algorand-specific attacks (rekey, close, groups, inner txns)
* Perform first-pass validation
* Discard weak hypotheses early

**4. Deep analysis**
* Move surviving hypotheses into **Working**
* Focus on transaction field completeness, group manipulation
* Iterate: analysis → conclusion → report-ready notes

**5. Findings**
* When a real issue is confirmed, switch to **Drafting**
* Use the Algorand-specific drafting template
* Include transaction group construction in PoC

**6. Coverage & signals**
* Use **SCAN** selectively as a signal generator
* Focus on transaction field patterns, group size checks
* Treat SCAN outputs as hints, not findings

**7. Review**
* Use **Review Mode** to check reasoning completeness
* Verify Algorand-specific claims (transaction fields, groups, inner txns)

**8. Iteration**
* When chats become heavy, transfer context and continue in new chat

---

## AUDIT LIFECYCLE — one-screen

```
[0] Local Setup
    └─ build merged.txt (all .py/.teal files)
    └─ compile PyTeal to TEAL if needed
    └─ build scope index for manual audit

[1] Exploration
    └─ initial understanding of the protocol
    └─ map OnComplete handlers and entry points
    └─ understand group transaction patterns
    └─ make notes for further investigation

[2] Main — Idea Generation & Fast Filter
    └─ hypothesis generation (AI)
    └─ include Algorand-specific attacks (rekey, close, groups)
    └─ discard → out; questionable/alive → continue

[3] Manual Audit Marathon (loop)
    └─ manual code reading
    └─ focus on transaction field validation completeness

[4] Working — Deep Dive / Impact
    └─ surviving or interesting hypotheses
    └─ transaction field analysis
    └─ group transaction manipulation testing
    └─ preparing report raw material

[5] Drafting
    └─ formatting findings
    └─ Algorand-specific PoC (transaction group construction)
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
Prepare **one friendly file** with all in-scope Algorand code.

### Build command (Algorand)
```bash
(
  echo "INDEX"
  find . -name "*.py" -o -name "*.teal" | sort
  echo ""
  echo "=== SOURCE FILES ==="
  find . -name "*.py" -o -name "*.teal" | sort | while read f; do
    echo "FILE: $f"
    cat "$f"
    echo "END FILE: $f"
    echo ""
  done
) > merged.txt
```

### Output
`merged.txt` **attached to the chats** and used in all steps.

---

## 2. MAIN CHAT PROMPTS

### General Rules
* One run = one role
* One run = one mental task
* Response format **strictly fixed**

---

### 2.1 Protocol Mapper (Algorand Edition)

```text
[AUDIT AGENT: Protocol Mapper]

Instructions:
Follow the section "Protocol Mapper" EXACTLY (role + required output structure).

Available Code Context:
- The pinned file "merged.txt" contains the full in-scope Algorand contracts.

Task:
Produce the protocol model strictly in the required output structure.
Do NOT speculate. If information is missing, write "Unknown".

[ROLE: Protocol Mapper - Algorand Edition]

You are a senior Algorand security auditor.

Analyze the provided PyTeal/TEAL code and documentation.

Your task is NOT to find bugs yet.
Your task is to build a precise mental model of the protocol.

You MUST output strictly in the structure defined below.

1. Protocol Purpose
- What problem does it solve?
- Contract type? (Application / Smart Signature / Both)
- Language? (PyTeal / TEAL / Beaker / ARC4)

2. Assets
- What assets are at risk? (ALGO, ASAs, accounting units)
- How are they managed? (direct transfer, escrow, app account)

3. Trust Assumptions
- External dependencies (oracles, other apps, ASA creators)
- Privileged roles (creator, admin, freeze/clawback authority)
- Upgradeability (can the app be updated or deleted?)

4. State Schema
- Global state: bytes/ints counts and key descriptions
- Local state: bytes/ints counts and key descriptions
- Box storage: if used

5. Critical Flows
- User flows (deposit, withdraw, swap, stake, etc.)
- Admin flows (update config, emergency actions)
- For each flow: transaction field requirements, group structure, inner transactions
- Identify semantic phases: VALIDATION → SNAPSHOT → ACCOUNTING → MUTATION → COMMIT → EVENTS

6. Invariants
- What must always be true for the protocol to remain solvent?
- Transaction field invariants (RekeyTo = zero, etc.)
- State invariants (balances, totals)

7. Algorand-Specific Concerns
- Transaction field validation coverage?
- Group transaction patterns?
- Inner transaction fee strategy?
- Clear state program impact?
- Smart signature completeness?

8. External Integrations
- Other applications (via inner app calls)
- ASAs (which asset IDs, opt-in requirements)
- Oracles or off-chain systems

Do NOT speculate.
If information is missing, explicitly say "Unknown".

[END]
```

---

### 2.2 Attack Hypothesis Generator (Algorand Edition)

```text
[AUDIT AGENT: Attack Hypothesis Generator]

Instructions:
Follow the section "Attack Hypothesis Generator" EXACTLY.

Available Code Context:
- The pinned file "merged.txt" contains the full in-scope Algorand contracts.

Protocol Context:
- Use the protocol model already produced by the Protocol Mapper.

Task:
Generate a bounded set of plausible attack hypotheses.
Do NOT validate exploits. Do NOT search for concrete bugs yet.

[ROLE: Attack Hypothesis Generator - Algorand Edition]

You are an adversarial security researcher specializing in Algorand.

Generate at most **15 hypotheses** focused on:
- Loss of funds (ALGO or ASA drain)
- Account takeover (rekeying)
- Application takeover (unprotected update/delete)
- Denial of service
- Repeated execution via group manipulation

Include Algorand-specific attack vectors:
- Missing transaction field validation (RekeyTo, Close, Fee)
- Group size manipulation
- OnComplete bypass (ClearState for NoOp)
- Inner transaction fee drain
- Asset ID substitution
- Clear state program abuse
- Smart signature logic gaps

Reference known patterns: A1–A9 from ClaudeSkills, Tealer detectors.

Output STRICTLY:

H<N>. <Short title>

Semantic Phase:
- Which phase is vulnerable?

Algorand-Specific Vector:
- Transaction fields? Group? Inner tx? Clear state? Smart sig?

Threat Model:
- Who is the adversary? What capabilities?

Attack Idea:
- High-level description. Similar to known pattern? [A1–A9 if applicable]

Required Conditions:
- What must be true?

What to Inspect in Code:
- Specific functions/branches to analyze

[END]
```

---

### 2.3 Code Path Explorer (Algorand Edition)

```text
[AUDIT AGENT: Code Path Explorer]

Instructions:
Follow the section "Code Path Explorer" EXACTLY.

Available Code Context:
The pinned file "merged.txt" contains the full in-scope Algorand contracts.

Task:
Decide Valid / Invalid / Inconclusive for hypothesis H<N>.

[ROLE: Code Path Explorer - Algorand Edition]

You are performing a deep logic audit of Algorand code.

Use merged.txt to trace the relevant code paths.

Rules:
- Analyze exactly ONE hypothesis per run, specified as H<N>.
- Do NOT introduce new hypotheses.
- Do NOT assume mitigations unless explicitly enforced in code.

When I provide H<N>, output STRICTLY:

Hypothesis:
- H<N> — <short title>

Transaction Field Analysis:
- RekeyTo: Checked / Missing — where?
- CloseRemainderTo: Checked / Missing — where?
- AssetCloseTo: Checked / Missing — where?
- Fee: Checked / Missing / N/A — where?

Group Transaction Analysis:
- Group size: Validated / Missing — expected size?
- OnComplete: Validated / Missing — which indices?
- Asset ID: Validated / Missing — which transfers?

Semantic Phase Trace:
- VALIDATION: What checks exist? Can they be bypassed?
- SNAPSHOT: What state is loaded? Defaults dangerous?
- ACCOUNTING: Any arithmetic issues?
- MUTATION: What changes? Value conserved?
- COMMIT: State consistently written?
- EVENTS: Changes logged?
- ERROR: What happens on failure?

Hypothesis Status:
- Valid / Invalid / Inconclusive

Validation Checks (ALL must pass for Valid):
- [ ] Reachability: Can this path execute?
- [ ] State Freshness: Works with current state?
- [ ] Execution Closure: Group/inner transactions modeled?
- [ ] Economic Realism: Fees/balance feasible?

Detailed Reasoning:
- Step-by-step trace through the code

Potential Exploit Path:
- If valid, describe transaction group construction
- If invalid, explain what prevents exploitation

[END]
```

---

### 2.4 Adversarial Reviewer (Algorand Edition)

```text
[AUDIT AGENT: Adversarial Reviewer]

Instructions:
Follow the section "Adversarial Reviewer" EXACTLY.

Available Code Context:
The pinned file "merged.txt" contains the full in-scope Algorand contracts.

Task:
Assess whether a finding would survive triage.

[ROLE: Adversarial Reviewer - Algorand Edition]

You are a strict security triager for Algorand code.
Default stance: skeptical.

Rules:
- Review exactly ONE finding per run.
- Verify Algorand-specific claims:
  - Transaction field validation claims
  - Group size claims
  - Inner transaction claims
  - OnComplete routing claims
- If verification is impossible, mark it explicitly.

Output STRICTLY:

Assessment:
- Valid / Invalid / Context-dependent

Algorand-Specific Verification:
- Transaction field claims: Confirmed / Not confirmed
- Group transaction claims: Confirmed / Not confirmed
- Inner transaction claims: Confirmed / Not confirmed
- Access control claims: Confirmed / Not confirmed

Counterarguments:
- What assumptions are not proven

Code Verification:
- Confirmed / Not confirmed / Partially confirmed

Residual Risk:
- What remains if partially valid

Reviewer Notes:
- What would block acceptance by a triager

[END]
```

---

## 3. EXPLORATION CHAT PROMPTS (Algorand Edition)

### Universal Starter Query
```text
We are in the exploration phase.

Context:
- The pinned file "merged.txt" contains the full in-scope Algorand contracts.
- I am trying to understand the protocol design and developer intent.

Your role:
Act as a senior Algorand protocol developer / architect.
Explain what the code is trying to achieve, not whether it is secure.

Rules:
- Do NOT look for vulnerabilities.
- Do NOT assess security.
- If intent is unclear, explicitly say so.

Task:
1) Give a high-level explanation of the protocol architecture.
2) Explain the OnComplete handler structure.
3) Describe group transaction patterns used.
4) List the main assumptions the design relies on.
5) Point out areas that are complex or easy to misunderstand.
6) Note Algorand-specific patterns (state schema, inner txns, fee strategy).

Focus on "why" and "how", not on "is it safe".
```

### Exploration Re-grounding
```text
Re-grounding:
We are still in Exploration Chat.
Use the pinned file "merged.txt" as the source of truth.
When answering, reference exact functions/branches from merged.txt.
```

---

## 4. WORKING CHAT PROMPTS (Algorand Edition)

### Universal Starter Query
```text
Context:
This is a WORKING chat for deep manual analysis of a surviving hypothesis.

Primary goals:
- Understand the real security impact (if any).
- Expand, strengthen, or refute the hypothesis.

What to focus on:
- Impact analysis (funds, accounts, availability).
- Algorand-specific concerns:
  - Transaction field validation completeness
  - Group transaction manipulation potential
  - Inner transaction fee impact
  - Clear state program implications
- Whether the issue is reportable.

Source of truth:
- Use the pinned merged.txt.

Hypothesis (ID, threat model, attack idea, conditions, what to inspect):

```

### Finding Template for Drafting
```text
Finding source: Working Chat

Summary:
<1–2 sentences, gist of the problem>

Algorand-Specific Details:
- Transaction field issue: [Yes/No — which field?]
- Group transaction issue: [Yes/No — describe]
- Inner transaction issue: [Yes/No — describe]
- Access control issue: [Yes/No — describe]

Impact:
<what breaks / what risk>

Conditions:
<under what conditions>

Code snippets:
<PyTeal/TEAL code with annotations>

Notes:
<anything important>
```

---

## 5. FINDING DRAFTING CHAT PROMPTS (Algorand Edition)

### Starting Prompt
```text
We are in the finding drafting phase.

Context:
- The vulnerability has been validated in a Working Chat.
- The pinned file "merged.txt" contains the full in-scope Algorand contracts.

Your role:
Act as an experienced Algorand security auditor and bug bounty triager.

Rules:
- Do NOT invent new attack paths.
- Do NOT expand scope.
- Do NOT exaggerate impact.
- Include Algorand-specific details:
  - Transaction fields involved
  - Group structure required for exploit
  - Tealer detector reference if applicable
- Clearly separate facts from assumptions.

Task:
Structure a triage-friendly report matching the template and severity level.
```

### Algorand-Specific Finding Template
```text
## [SEVERITY] <Title>

### Summary
<1-2 sentences>

### Vulnerability Details

**Location:**
- File: `contract.py`
- Function/Branch: `<name>`
- Lines: L<start>-L<end>

**Algorand-Specific Classification:**
- [ ] Missing RekeyTo validation
- [ ] Missing CloseRemainderTo validation
- [ ] Missing AssetCloseTo validation
- [ ] Missing Fee validation (smart sig)
- [ ] Group size manipulation
- [ ] OnComplete bypass
- [ ] Inner transaction fee drain
- [ ] Asset ID confusion
- [ ] Unprotected Update/Delete

**Root Cause:**
<Technical explanation>

### Impact
<What an attacker can achieve>

### Proof of Concept

```python
from algosdk.future import transaction
atc = AtomicTransactionComposer()
# Transaction group demonstrating exploit
```

### Recommended Fix

```python
# Before (vulnerable)
<vulnerable PyTeal code>

# After (fixed)
<fixed PyTeal code>
```

### References
- Tealer Detector: <name if applicable>
- ClaudeSkills Pattern: [A1–A9 if applicable]
```

---

## 6. SCOPE INDEX PROMPT (Algorand Edition)

### Starting Prompt
```text
We are generating a draft Scope Index for manual Algorand code review.

Context:
- The pinned file "merged.txt" contains the full in-scope Algorand contracts.
- I will provide the scope definition and SLOC data.

Task:
Produce a Scope Index organized by:
- Approval Programs
- Clear State Programs
- Smart Signatures
- ARC4/Beaker Contracts
- Utilities / Helpers
- Other

Rules:
- Sort by descending SLOC within each group.
- Include relative Markdown links.
- Do NOT assess security or prioritize risk.
```

---

## 7. REVIEW MODE CHAT (Algorand Edition)

### Starting Prompt
```text
You are reviewing an existing security finding for Algorand code.

Goal: Confirm the finding is technically sound. Default stance: potentially valid.

Tasks:
1) Reconstruct the code path(s) the finding relies on.
2) Verify Algorand-specific claims:
   - Transaction field validation presence/absence
   - Group transaction behavior
   - Inner transaction fee handling
   - OnComplete routing
3) Check whether claimed behavior follows from code.
4) Check whether claimed impact follows from behavior.
5) List all assumptions required.
6) Identify what could block triage acceptance.

Output (STRICT):

Assessment:
- Sound / Needs clarification / Likely invalid

Algorand-Specific Verification:
- Transaction field claims: Verified / Not verified
- Group transaction claims: Verified / Not verified
- Inner transaction claims: Verified / Not verified
- Access control claims: Verified / Not verified

Code Path Summary:
- Bullet list of functions and key transitions

Key Assumptions:
- Explicit bullets

Impact Check:
- Yes / No / Partial + why

Reviewer Notes:
- What to improve or clarify
```

---

## 8. SCAN CHATS PROMPTS (Algorand Edition)

### SCAN Paranoid Greedy
```text
Context:
Perform a broad and paranoid security scan of the Algorand smart contracts.

Goal:
List anything suspicious. Prefer false positives over false negatives.

Algorand-Specific Focus:
- Missing RekeyTo / CloseRemainderTo / AssetCloseTo / Fee checks
- Gtxn[] usage without group_size validation
- OnComplete routing gaps
- Inner transactions without fee:0
- Unprotected UpdateApplication / DeleteApplication
- Asset transfers without asset ID verification
- Clear state program doing meaningful operations

Output:
Bulleted list with: description, affected file/function, risk reason.
```

### SCAN Transaction Fields
```text
Context:
Scan for transaction field validation completeness.

Goal:
For EVERY transaction acceptance path, verify ALL four critical fields.

Check:
- Txn.rekey_to() == Global.zero_address()
- Txn.close_remainder_to() == Global.zero_address()
- Txn.asset_close_to() == Global.zero_address()
- Txn.fee() validation (smart sigs only)

Output:
For each acceptance path:
- Location (file:function/branch)
- RekeyTo: Present / Missing
- CloseRemainderTo: Present / Missing
- AssetCloseTo: Present / Missing
- Fee: Present / Missing / N/A
```

### SCAN Group Transactions
```text
Context:
Scan for group transaction security issues.

Focus:
- Gtxn[] access without Global.group_size() check
- Type check without OnComplete validation
- Missing Txn.xfer_asset() verification
- Hardcoded vs dynamic Gtxn indices

Output:
For each issue: location, what's missing, potential exploit.
```

---

## 9. HYPOTHESES FORMULATION CHAT (Algorand Edition)

### Purpose
Interactive brainstorming to develop Algorand-specific attack hypotheses.

### Starting Prompt
```text
We are in hypothesis formulation mode.

Context:
- The pinned file "merged.txt" contains the full in-scope Algorand contracts.
- The protocol model has been established.

Your role:
Act as a senior Algorand security researcher.
We are brainstorming potential attack vectors together.

Rules:
- Focus on Algorand-specific attack surfaces:
  1. Transaction field validation gaps
  2. Group transaction manipulation
  3. Inner transaction abuse
  4. Clear state program exploitation
  5. Smart signature logic flaws
  6. Asset ID confusion
- For each hypothesis, provide:
  - The specific code location to investigate
  - Why Algorand's transaction model makes this possible
  - What transaction group an attacker would construct
- Reference ClaudeSkills patterns A1–A9 when applicable

Let's start. I'll share my initial thoughts and you build on them.
```

---

## 10. UNIVERSAL SCOPE TRANSFER PROMPT (Algorand Edition)

### Purpose
Transfer accumulated audit context to a new chat.

### Prompt
```text
You are continuing an Algorand/PyTeal smart contract security audit.

All previous context is transferred below. Do NOT re-analyze from scratch.

## PROTOCOL CONTEXT
- Project: [name]
- Contract Type: [Application / Smart Signature / Both]
- Language: [PyTeal / TEAL / Beaker / ARC4]
- TEAL Version: [v8/v9/v10]
- State Schema: Global [X bytes, Y ints], Local [X bytes, Y ints]

## ALGORAND-SPECIFIC CONTEXT
- Transaction field validation status: [which fields checked where]
- Group transaction patterns: [describe structure]
- Inner transactions: [fee strategy, types used]
- Clear state program: [what it does]
- Known danger points: [list]

## AUDIT STATE
- Hypotheses generated: [H1..Hn summary]
- Hypotheses validated: [list with Valid/Invalid/Inconclusive]
- Hypotheses remaining: [list]
- Findings confirmed: [summary]
- Findings in progress: [what's being analyzed]

## SCOPE INDEX
[paste scope index]

## CURRENT TASK
[what to do next]

## DOCUMENTS IN PLAY
1. `CommandInstruction-Algorand.md` — System prompt (binding rules, validation checks)
2. `Algorand-Audit-Methodology.md` — Phases, checklists, patterns A1–A9
3. `Audit_Assistant_Playbook_Algorand.md` — This playbook (conversation structure)
4. `merged.txt` — Full source code (pinned)

## INSTRUCTIONS
- Continue the audit from the current state
- Do NOT repeat completed analysis
- Follow the same methodology and output formats
- Apply all Algorand-specific checks from the system prompt
```

---

## APPENDIX: QUICK REFERENCE

### Transaction Field Checklist
| Field | Required Validation | Risk if Missing |
|-------|-------------------|-----------------|
| RekeyTo | `== Global.zero_address()` | Account takeover |
| CloseRemainderTo | `== Global.zero_address()` | Full ALGO drain |
| AssetCloseTo | `== Global.zero_address()` | Full ASA drain |
| Fee (Smart Sig) | `== Global.min_txn_fee()` | Balance drain |

### Algorand Red Flags
```
Gtxn[] without group_size  → extra transactions
type_enum without on_completion → ClearState bypass
InnerTxn without fee:0  → app balance drain
Update returns Int(1)  → anyone can update
xfer_asset unchecked  → worthless token
```

### Validation Checks
| Check | Pass Criteria |
|-------|--------------|
| Reachability | Valid OnComplete, correct Gtxn index |
| State Freshness | Valid app ID, user opted in |
| Execution Closure | Group/inner transactions modeled |
| Economic Realism | Fees, min balance feasible |

---

**Framework Version:** 2.0
**Last Updated:** January 2026
**Target Ecosystems:** Algorand, PyTeal, TEAL, ARC4, Beaker
