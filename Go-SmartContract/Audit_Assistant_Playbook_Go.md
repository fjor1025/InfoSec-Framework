# Audit Assistant Playbook (Go Edition)
## Cognitive Framework for Go Smart Contract Auditing

* **Status:** Experimental / Practitioner Tool
* **Audience:** Experienced smart contract auditors working with Go ecosystems
* **Target Frameworks:** Cosmos SDK, Tendermint/CometBFT, IBC, General Go

This playbook describes a **minimal, reproducible flow** for working with LLMs when auditing **Go-based blockchain applications**.

This playbook does NOT automate security audits.  
It does NOT replace auditor judgment.  
It structures how auditors think, explore, validate, and report findings.

---

## METHODOLOGY INTEGRATION

This playbook structures **conversations**. The actual audit **methodology** lives in:

| File | Purpose | When to Reference |
|------|---------|-------------------|
| `Go-Smart-Contract-Audit-Methodology.md` | Go-specific phases, checklists, attack patterns | During Code Path Explorer, hypothesis validation |
| `CommandInstruction-Go.md` | System prompt for Go audit sessions | At start of any audit chat |

**Key Methodology Concepts to Apply:**
- **Semantic Phases (Go):** VALIDATION → SNAPSHOT → ACCOUNTING → MUTATION → COMMIT → EVENTS → ERROR
- **Validation Checks:** Reachability, State Freshness, Execution Closure, Economic Realism
- **Known Exploit Patterns:** Dragonberry, Jackfruit, Osmosis LP, Crescent AMM, etc.
- **Go-Specific:** Pointer safety, zero values, error handling, panic safety

---

## HOW TO USE THIS PLAYBOOK (REAL AUDIT FLOW)

**1. Prepare context**
* Build `merged.txt` with all in-scope `.go` files
* Gather project documentation (README, spec, ADRs)
* Generate the Scope Index for navigation

**2. Initial understanding**
* Start with **Exploration**
* Work until the protocol model is stable (1–2 days depending on nSLOC)
* Focus on keeper structure, message flow, module interactions
* Make notes but do NOT search for bugs yet

**3. Hypotheses**
* Generate attack hypotheses in **Main**
* Include Go-specific attacks (pointers, zero values, panics)
* Perform first-pass validation
* Discard weak hypotheses early

**4. Deep analysis**
* Move surviving hypotheses into **Working**
* Use one or multiple Working chats as needed
* Focus on Go-specific concerns (pointer mutation, error paths)
* Iterate: analysis → conclusion → report-ready notes

**5. Findings**
* When a real issue is confirmed, switch to **Drafting**
* Use the Go-specific drafting template
* Include pointer analysis and PoC test code

**6. Coverage & signals**
* Use **SCAN** selectively as a signal generator
* Focus on Go-specific patterns (ignored errors, panics, zero values)
* Treat SCAN outputs as hints, not findings

**7. Review**
* Use **Review Mode** to check reasoning completeness
* Verify Go-specific claims (pointers, errors, panics)

**8. Iteration**
* When chats become heavy, transfer context and continue in new chat
* Avoid returning to Main late; continue via Working

---

## AUDIT LIFECYCLE — one-screen

```
[0] Local Setup
    └─ build merged.txt (all .go files)
    └─ collect docs (README, go.mod dependencies)
    └─ build scope index for manual audit

[1] Exploration
    └─ initial understanding of the protocol
    └─ map keeper structure and module interactions
    └─ understand framework (Cosmos SDK/Tendermint/IBC)
    └─ make notes for further investigation

[2] Main — Idea Generation & Fast Filter
    └─ hypothesis generation (AI)
    └─ include Go-specific attacks (pointers, errors, panics)
    └─ discard → out; questionable/alive → continue

[3] Manual Audit Marathon (loop)
    └─ manual code reading
    └─ focus on pointer flow, error paths

[4] Working — Deep Dive / Impact
    └─ surviving or interesting hypotheses
    └─ pointer mutation analysis
    └─ error path tracing
    └─ preparing report raw material

[5] Drafting
    └─ formatting findings
    └─ Go-specific PoC test code
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
Prepare **one friendly file** with all in-scope Go code.

### Input
* Working directory with **only in-scope Go files**
* No vendor directory or test files (unless in scope)

### Build command (Go)
```bash
(
  echo "INDEX"
  find . -name "*.go" -type f ! -path "./vendor/*" ! -name "*_test.go" | sort
  echo ""
  echo "=== GO.MOD ==="
  cat go.mod
  echo ""
  echo "=== SOURCE FILES ==="
  find . -name "*.go" -type f ! -path "./vendor/*" ! -name "*_test.go" | sort | while read f; do
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
* GO.MOD (for dependency context)
* FILE / END FILE blocks

`merged.txt` **attached to the chats** and used in all steps.

---

## 2. MAIN CHAT PROMPTS

### General Rules
* One run = one role
* One run = one mental task
* Response format **strictly fixed**

---

### 2.1 Protocol Mapper (Go Edition)

**Role:** Building a mental model of the Go protocol

```text
[AUDIT AGENT: Protocol Mapper]

Instructions:
Follow the section "Protocol Mapper" EXACTLY (role + required output structure).

Available Code Context:
- The pinned file "merged.txt" contains the full in-scope Go smart contracts.

Additional Context (README / spec / ADRs):
- Use pinned project documentation if available.
- If no docs are pinned, ask me to paste relevant excerpts before making assumptions.

Task:
Produce the protocol model strictly in the required output structure.
Do NOT speculate. If information is missing, write "Unknown".

[ROLE: Protocol Mapper - Go Edition]

You are a senior Go/Cosmos security auditor.

Analyze the provided Go blockchain code and documentation.

Your task is NOT to find bugs yet.
Your task is to build a precise mental model of the protocol.

You MUST output strictly in the structure defined below.
No additional sections are allowed.

1. Protocol Purpose
- What problem does it solve?
- What framework? (Cosmos SDK/Tendermint/ABCI/Other)

2. Assets
- What assets are at risk? (tokens, balances, NFTs, accounting units)
- How are they represented? (sdk.Coin, sdk.Int, custom types)

3. Trust Assumptions
- External dependencies (oracles, bridges, IBC channels)
- Privileged roles (admin, governance, validators)
- Upgradeability/migration assumptions

4. Module/Keeper Structure
- Key keepers and their responsibilities
- Cross-keeper dependencies
- Module accounts and their purposes

5. Critical Flows
- User flows involving assets (deposit, withdraw, stake, swap)
- Admin flows
- For each flow, identify semantic phases: VALIDATION → SNAPSHOT → ACCOUNTING → MUTATION → COMMIT → EVENTS

6. Invariants
- What must always be true for the protocol to remain solvent?
- Module invariants registered?
- Reference: Universal invariants (no free money, no double spending, etc.)

7. Go-Specific Concerns
- Pointer vs value receivers?
- Error handling patterns (return error, panic, sdkerrors)
- Any panic-prone code paths?
- Concurrency model (single-threaded typical for chains)

8. Framework-Specific Notes
- **Cosmos SDK**: BeginBlock/EndBlock logic, IBC callbacks, governance hooks
- **Tendermint**: ABCI interface, validator set changes
- **IBC**: Packet handling, acknowledgements, timeouts

Do NOT speculate.
If information is missing, explicitly say "Unknown".

[END]
```

---

### 2.2 Attack Hypothesis Generator (Go Edition)

**Role:** Generating Go-specific attack scenarios

```text
[AUDIT AGENT: Attack Hypothesis Generator]

Instructions:
Follow the section "Attack Hypothesis Generator" EXACTLY
(role definition + constraints + output format).

Available Code Context:
- The pinned file "merged.txt" contains the full in-scope Go smart contracts.

Protocol Context:
- Use the protocol model already produced in this chat by the Protocol Mapper.
- If the protocol model is missing or incomplete, ask me to provide it before proceeding.

Task:
Generate a bounded set of plausible attack hypotheses.
Do NOT validate exploits.
Do NOT search for concrete bugs yet.

[ROLE: Attack Hypothesis Generator - Go Edition]

You are an adversarial security researcher specializing in Go blockchain code.

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
  - Denial of service (via panics or gas)
  - Privilege escalation
  - Irreversible state corruption
- Hypotheses must be:
  - Neutral
  - Technically plausible
  - Grounded in protocol design and Go-specific risks
- Include Go-specific attack vectors:
  - Pointer modification before validation
  - Zero-value struct exploitation
  - Ignored error returns
  - Panic in handler (chain halt)
  - Interface type assertion failures
- Reference known exploit patterns:
  - Cosmos SDK: Dragonberry, Jackfruit, Huckleberry, Elderflower
  - DeFi: Osmosis LP, Umee collateral, Crescent AMM
- Do NOT include purely speculative or unrealistic attacks.

Output STRICTLY in the following format:

For each hypothesis:

H<N>. <Short title>

Semantic Phase:
- Which phase is vulnerable? [VALIDATION/SNAPSHOT/ACCOUNTING/MUTATION/COMMIT/EVENTS/ERROR]
- Cross-phase interaction? (e.g., Snapshot→Mutation race)

Go-Specific Vector:
- Pointer issue? Zero value? Error handling? Panic?

Threat Model:
- Who is the adversary?
- What capabilities or privileges do they have?

Attack Idea:
- High-level description of the potential failure mode.
- Similar to known exploit? [Name if applicable]

Required Conditions:
- What must be true for this attack to work?

What to Inspect in Code:
- Specific keepers, handlers, or state variables
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

### 2.3 Code Path Explorer (Go Edition)

**Role:** Deep testing of one hypothesis with Go-specific analysis

```text
[AUDIT AGENT: Code Path Explorer]

Instructions:
Follow the section "Code Path Explorer" EXACTLY
(role definition + rules + output format).

Available Code Context:
The pinned file "merged.txt" contains the full in-scope Go smart contracts.

Attack Hypothesis:
- Use hypothesis H<N> from the current Main Chat.
- Do NOT reinterpret or reformulate it unless explicitly asked.

Important: Do NOT analyze any hypothesis until I specify the exact H<N>.

Task:
Decide Valid / Invalid / Inconclusive and justify by tracing code paths.
Do NOT assume mitigations unless explicitly enforced in code.

[ROLE: Code Path Explorer - Go Edition]

You are performing a deep logic audit of Go blockchain code.

Use merged.txt to locate and analyze the relevant functions and code paths.
Your task is to determine whether a specific attack hypothesis
actually follows from the code.

**Methodology Reference:**
- Apply semantic phase analysis (VALIDATION → COMMIT → ERROR)
- Use the Go-specific checklists from methodology
- Trace pointer mutations and error handling

Your goals:
- Trace execution paths by semantic phase
- Track pointer modifications vs value copies
- Identify panic points and unhandled errors
- Check zero-value struct handling
- Analyze error paths for state cleanup

Rules:
- Analyze exactly ONE hypothesis per run, specified by me as H<N>.
- Do NOT introduce new hypotheses.
- Do NOT expand scope beyond what the hypothesis assumes.
- Do NOT assume mitigations unless explicitly enforced in code.

When I provide H<N>, output STRICTLY:

Hypothesis:
- H<N> — <short title>

Pointer/Value Analysis:
- Which functions use pointer receivers?
- Where are pointers modified?
- Any aliasing concerns?

Semantic Phase Trace:
- VALIDATION: What checks exist? Can they be bypassed?
- SNAPSHOT: What state is loaded? Zero values handled?
- ACCOUNTING: Any time/oracle dependencies? Math safety?
- MUTATION: What changes? Is value conserved? Pointers safe?
- COMMIT: Is state consistently written? Gas accounted?
- EVENTS: Are all changes logged?
- ERROR: What happens on error? Is state cleaned up?

Go-Specific Checks:
- [ ] No ignored error returns in this path
- [ ] No panic in production code
- [ ] Zero-value structs handled safely
- [ ] Pointers not modified before validation
- [ ] Type assertions checked

Hypothesis Status:
- Valid / Invalid / Inconclusive

Validation Checks (ALL must pass for Valid):
- [ ] Reachability: Can this path execute on-chain?
- [ ] State Freshness: Does it work with current state?
- [ ] Execution Closure: Are external calls modeled?
- [ ] Economic Realism: Is cost/timing feasible?

Detailed Reasoning:
- Step-by-step reasoning through the code paths
- Include pointer/value analysis

Potential Exploit Path:
- If valid, describe a concrete exploit scenario with Go test code
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

### 2.4 Adversarial Reviewer (Go Edition)

**Role:** Anti-false-positive with Go-specific verification

```text
[AUDIT AGENT: Adversarial Reviewer]

Instructions:
Follow the section "Adversarial Reviewer" EXACTLY
(role definition + rules + output format).

Available Code Context:
The pinned file "merged.txt" contains the full in-scope Go smart contracts.

Finding Under Review:
- I will paste a single security finding written by an auditor.
- Do NOT review anything until the finding is provided.

Task:
Assess whether the finding would survive triage.

[ROLE: Adversarial Reviewer - Go Edition]

You are acting as a strict security triager for Go blockchain code.

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
- If the finding claims specific Go behavior, you MUST verify it:
  - Pointer mutation claims
  - Error handling claims
  - Zero value claims
  - Panic conditions
- If verification is impossible, mark it explicitly.

When the finding is provided, output STRICTLY:

Assessment:
- Valid / Invalid / Context-dependent

Go-Specific Verification:
- Pointer claims: Confirmed / Not confirmed
- Error handling claims: Confirmed / Not confirmed  
- Zero value claims: Confirmed / Not confirmed
- Panic claims: Confirmed / Not confirmed

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
Pay special attention to Go-specific claims.
Do NOT introduce new vulnerabilities or scope.
Follow the same STRICT output format.
```

---

## 3. EXPLORATION CHAT PROMPTS (Go Edition)

### Purpose
**Exploration Chat** is a mode for collaboratively *understanding* a Go protocol before formalizing hypotheses.

### Universal Starter Query
```text
We are in the exploration phase.

Context:
- The pinned file "merged.txt" contains the full in-scope Go smart contracts.
- No vendor dependencies are included (only first-party code).
- I am trying to understand the protocol design and developer intent.

Your role:
Act as a senior Go protocol developer / architect.
Explain what the code is trying to achieve, not whether it is secure.

Rules:
- Do NOT look for vulnerabilities.
- Do NOT assess security or exploitability.
- Do NOT speculate beyond what can be inferred from code.
- If intent or assumptions are unclear, explicitly say so.

Task:
1) Give a high-level explanation of the protocol architecture.
2) Explain the keeper structure and module interactions.
3) Identify key design decisions that are non-obvious.
4) List the main assumptions the design relies on.
5) Point out areas that are complex or easy to misunderstand.
6) Note any Go-specific patterns (error handling, pointer receivers, interfaces).

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

### Move to New Module
```text
Re-grounding before new topic:
We are continuing exploration of the same codebase.
Focus now on <KEEPER / MODULE>.
Use merged.txt and cite exact locations.
Explain the message flow and state changes in this module.
```

---

## 4. WORKING CHAT PROMPTS (Go Edition)

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
- Go-specific concerns:
  - Pointer mutation flow through the attack path
  - Error handling and state cleanup
  - Zero value exploitation
  - Panic conditions
- Secondary and cascading effects.
- Alternative actors, timings, and conditions.
- Whether the issue is reportable, and under what assumptions.

Allowed:
- Debate and challenge the hypothesis.
- Revisit validity if impact analysis reveals flaws.
- Explore multiple interpretations of the same issue.

Optional support:
- Help formulate PoC requirements in Go test format
  (do NOT implement PoCs unless explicitly requested).

Out of scope:
- Generating new unrelated hypotheses.
- Auto-audit loops or mass scanning.
- Final report writing (handled elsewhere).

Source of truth:
- Use the pinned merged.txt and project documentation.

Your role:
Act as a senior Go security auditor assisting in impact extraction
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
- Pointer mutations
- Error handling
- Zero value handling
- Panic conditions
```

### Finding Template for Drafting
```text
Finding source: Working Chat

Summary:
<1–2 sentences, gist of the problem>

Go-Specific Details:
- Pointer issue: [Yes/No — describe]
- Error handling: [Yes/No — what's wrong]
- Zero value: [Yes/No — where]
- Panic risk: [Yes/No — where]

Impact:
<what breaks / what risk>

Conditions:
<under what conditions, roles, states>

Code snippets:
<keepers / handlers with pointer annotations>

Notes:
<anything important to keep but not included above>
```

---

## 5. FINDING DRAFTING CHAT PROMPTS (Go Edition)

### Purpose
Preparing a clear, triage-friendly report on an already identified Go issue.

### Starting Prompt
```text
We are in the finding drafting phase.

Context:
- The vulnerability has already been validated in a Working Chat.
- This chat is dedicated to preparing a clear, accurate vulnerability report.
- The pinned file "merged.txt" contains the full in-scope Go smart contracts.

Your role:
Act as an experienced Go security auditor and bug bounty triager.

General Rules:
- Do NOT invent new attack paths.
- Do NOT expand scope beyond the validated issue.
- Do NOT exaggerate impact.
- Be precise, conservative, and technically accurate.
- Include Go-specific details:
  - Pointer vs value analysis if relevant
  - Error handling issues if applicable
  - Zero value concerns
  - Panic conditions
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

### Go-Specific Finding Template
```text
## [SEVERITY] <Title>

### Summary
<1-2 sentences describing the issue>

### Vulnerability Details

**Location:**
- File: `x/module/keeper/msg_server.go`
- Function: `HandleMsgUpdatePosition`
- Lines: L<start>-L<end>

**Go-Specific Classification:**
- [ ] Pointer mutation before validation
- [ ] Zero value exploitation
- [ ] Ignored error return
- [ ] Panic in handler
- [ ] Type assertion failure
- [ ] Access control bypass

**Root Cause:**
<Technical explanation of why the bug exists>

**Semantic Phase:**
<VALIDATION/SNAPSHOT/ACCOUNTING/MUTATION/COMMIT/EVENTS/ERROR>

### Impact
<What breaks, who loses what, severity justification>

### Proof of Concept

```go
func TestExploit(t *testing.T) {
    // Setup
    k, ctx := setupKeeper(t)
    
    // Attack steps
    msg := types.MsgExploit{...}
    _, err := k.HandleMsg(ctx, &msg)
    
    // Verify impact
    require.NoError(t, err)
    // Assert state corruption
}
```

### Recommended Fix

```go
// Before (vulnerable)
<vulnerable code>

// After (fixed)  
<fixed code>
```

### References
- Similar to: <known exploit if applicable>
- Relevant Go docs: <if applicable>
```

---

## 6. SCOPE INDEX PROMPT (Go Edition)

### Purpose
Generate navigational artifact for Go codebase review.

### Starting Prompt
```text
We are generating a draft Scope Index for manual Go code review.

Context:
- The pinned file "merged.txt" contains the full in-scope Go smart contracts.
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

Structure (Go-specific):
- Keepers (`keeper.go`, `msg_server.go`)
- Types (`types/`, messages, state)
- Handlers (`handler.go`, ABCI hooks)
- Queries (`grpc_query.go`, `query.go`)
- Genesis (`genesis.go`)
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

## 7. REVIEW MODE CHAT (Go Edition)

### Purpose
Check completeness and correctness of Go-specific reasoning.

### Starting Prompt
```text
You are reviewing an existing security finding for Go blockchain code.

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
2) Verify Go-specific claims:
   - Pointer mutation behavior
   - Error handling paths
   - Zero value handling
   - Panic conditions
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

Go-Specific Verification:
- Pointer claims: Verified / Not verified
- Error handling: Verified / Not verified
- Zero value claims: Verified / Not verified
- Panic claims: Verified / Not verified

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

## 8. SCAN CHATS PROMPTS (Go Edition)

### SCAN Paranoid Greedy (Go)
```text
Context:
Perform a broad and paranoid security scan of the Go smart contracts.

Goal:
List anything that looks suspicious, fragile, non-obvious, or inconsistent.

Instructions:
- Use the full code from merged.txt.
- Prefer false positives over false negatives.
- Do NOT validate findings or assess severity.

Go-Specific Focus:
- Pointer modifications before error checks
- Ignored error returns (_, _ := or _ =)
- panic() calls in production code
- Zero-value structs treated as valid
- Unbounded iterations (Iterator(nil, nil))
- Type assertions without checking

General Focus:
- Missing or weak checks
- Unusual state transitions
- Edge states (zero supply, init, shutdown)
- Cross-keeper interactions

Output:
Bulleted list.
For each item:
- Short description
- Affected file/function
- Why this might be risky (Go-specific reason if applicable)
```

### SCAN Error Handling
```text
Context:
Scan for error handling issues in Go blockchain code.

Goal:
Identify all locations where errors may be mishandled.

Focus:
- Ignored error returns (_, _ := or _ =)
- Errors not wrapped with context (sdkerrors.Wrap)
- Panic calls that could halt the chain
- Error types that leak internal state
- Missing error checks after store operations

Output:
For each issue:
- Location (file:line)
- Type (ignored/unwrapped/panic/leak)
- Context (what function, what operation)
- Impact (state corruption? chain halt?)
```

### SCAN Pointer Safety
```text
Context:
Scan for pointer-related issues in Go blockchain code.

Goal:
Identify potentially dangerous pointer patterns.

Focus:
- Pointer receivers that mutate state
- Pointer modification before validation
- Pointer aliasing (shared references)
- Nil pointer dereferences
- Slice/map passed by reference and modified

Output:
For each issue:
- Location (file:line)
- Pattern type
- Why it might be problematic
- Suggested fix
```

### SCAN Zero Values
```text
Context:
Scan for zero-value handling issues in Go blockchain code.

Goal:
Identify locations where Go's zero values could cause issues.

Focus:
- Zero-value structs returned from store.Get()
- Empty strings/slices treated as valid
- sdk.Int/sdk.Dec zero vs nil confusion
- Missing initialization checks
- Default values in message types

Output:
For each issue:
- Location
- What zero value is involved
- Why this could be exploited
- Recommended handling
```

---

## 9. HYPOTHESES FORMULATION CHAT (Go/Cosmos Edition)

### Purpose
Interactive brainstorming to develop Go/Cosmos-specific attack hypotheses beyond the structured generator.

### Starting Prompt
```text
We are in hypothesis formulation mode.

Context:
- The pinned file "merged.txt" contains the full in-scope Go/Cosmos contracts.
- The protocol model has been established.

Your role:
Act as a senior Go/Cosmos security researcher.
We are brainstorming potential attack vectors together.

Rules:
- Focus on Go/Cosmos-specific attack surfaces:
  1. Pointer mutation before validation (state corruption on error)
  2. Zero value exploitation (empty structs, nil from store.Get)
  3. Panic in BeginBlock/EndBlock (chain halt)
  4. Cross-module keeper trust (bank, staking, IBC interactions)
  5. IBC packet handling (OnRecvPacket, ack, timeout)
  6. Error path state leaks (partial writes before error return)
  7. Unbounded iteration (gas/block-time DoS)
  8. sdk.Dec precision loss (accumulated rounding)
- For each hypothesis, provide:
  - The specific keeper/handler function to investigate
  - The Go-specific mechanism that makes this possible
  - What message or transaction sequence an attacker would use
- Reference known patterns: C1–C6 from Trail of Bits, historical Cosmos exploits
  (Dragonberry, Jackfruit, Huckleberry, Osmosis LP, etc.)

Let's start. I'll share my initial thoughts and you build on them.
```

### Continuation Prompt
```text
Continue hypothesis formulation.

Rules still apply:
- Reference specific code from merged.txt
- Focus on Go/Cosmos attack surfaces
- Build on hypotheses already discussed, don't repeat
```

---

## 10. UNIVERSAL SCOPE TRANSFER PROMPT (Go/Cosmos Edition)

### Purpose
Transfer accumulated audit context to a new chat when the current one becomes too long.

### Prompt
```text
You are continuing a Go/Cosmos smart contract security audit.

All previous context is transferred below. Do NOT re-analyze from scratch.

## PROTOCOL CONTEXT
- Project: [name]
- Framework: [Cosmos SDK vX.Y.Z / Tendermint / CometBFT / Custom]
- Go Version: [1.21/1.22/etc.]
- SDK Version: [v0.47.x / v0.50.x / etc.]
- IBC: [Yes/No — ibc-go version]
- Module Structure: [list of custom modules]

## GO-SPECIFIC CONTEXT
- Pointer safety status: [which keepers use pointer receivers, known safe/unsafe paths]
- Error handling status: [known ignored errors, panic locations]
- Zero value handling: [known dangerous defaults]
- BeginBlock/EndBlock: [what they do, bounded/unbounded]
- Module interactions: [which keepers call which]

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
1. `CommandInstruction-Go.md` — System prompt (binding rules, validation checks, 6 lenses)
2. `Go-Smart-Contract-Audit-Methodology.md` — Phases, checklists, patterns C1–C6
3. `Audit_Assistant_Playbook_Go.md` — This playbook (conversation structure)
4. `merged.txt` — Full source code (pinned)

## INSTRUCTIONS
- Continue the audit from the current state
- Do NOT repeat completed analysis
- Follow the same methodology and output formats
- Apply all Go-specific checks from the system prompt
- Reference exact function/line locations from merged.txt
```

---

## APPENDIX: QUICK REFERENCE

### Semantic Phases (Go)
| Phase | Indicators | Key Checks |
|-------|------------|------------|
| VALIDATION | `ValidateBasic()`, early `if` | Complete? Signatures? |
| SNAPSHOT | `k.Get*()`, `store.Get()` | Zero values? Nil? |
| ACCOUNTING | `ctx.BlockTime()`, oracles | Time safety? Math? |
| MUTATION | `store.Set()`, pointer mod | Conservation? Pointers? |
| COMMIT | `Save*()`, protobuf marshal | Atomic? Gas? |
| EVENTS | `EmitEvent()` | Complete? Safe? |
| ERROR | `return err`, `panic()` | Cleanup? Rollback? |

### Go Red Flags
```
_, _ :=       → check errors
pos.Field =   → validate first
panic()       → return error
Position{}    → check for nil
Iterator(nil) → add bounds
msg.(*Type)   → use ok pattern
```

### Validation Checks
| Check | Pass Criteria |
|-------|--------------|
| Reachability | Handler registered, message routed |
| State Freshness | Works with realistic KV state |
| Execution Closure | External calls modeled |
| Economic Realism | Attack is profitable/feasible |

---

**Framework Version:** 2.0  
**Last Updated:** January 2026  
**Target Ecosystems:** Cosmos SDK, Tendermint, CometBFT, IBC, General Go
