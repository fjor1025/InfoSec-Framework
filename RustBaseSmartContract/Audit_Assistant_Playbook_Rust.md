# Audit Assistant Playbook (Rust Edition)
## Cognitive Framework for Rust Smart Contract Auditing

* **Status:** Experimental / Practitioner Tool
* **Audience:** Experienced smart contract auditors working with Rust ecosystems
* **Target Frameworks:** CosmWasm, Solana/Anchor, Substrate, General Rust

This playbook describes a **minimal, reproducible flow** for working with LLMs when auditing **Rust-based smart contracts**.

This playbook does NOT automate security audits.  
It does NOT replace auditor judgment.  
It structures how auditors think, explore, validate, and report findings.

---

## METHODOLOGY INTEGRATION

This playbook structures **conversations**. The actual audit **methodology** lives in:

| File | Purpose | When to Reference |
|------|---------|-------------------|
| `Rust-Smartcontract-workflow.md` | Rust-specific phases, checklists, attack patterns | During Code Path Explorer, hypothesis validation |
| `CommandInstruction-Rust.md` | System prompt for Rust audit sessions | At start of any audit chat |

**Key Methodology Concepts to Apply:**
- **Semantic Phases (Rust):** SNAPSHOT → VALIDATION → ACCOUNTING → MUTATION → COMMIT → ERROR
- **Validation Checks:** Reachability, State Freshness, Execution Closure, Economic Realism
- **Known Exploit Patterns:** Wormhole, Cashio, Anchor Protocol, Acala, etc.
- **Rust-Specific:** Ownership analysis, panic safety, arithmetic safety, error path cleanup

---

## HOW TO USE THIS PLAYBOOK (REAL AUDIT FLOW)

**1. Prepare context**
* Build `merged.txt` with all in-scope `.rs` files
* Gather project documentation (README, spec, whitepaper)
* Generate the Scope Index for navigation

**2. Initial understanding**
* Start with **Exploration**
* Work until the protocol model is stable (1–2 days depending on nSLOC)
* Focus on ownership patterns, state management, framework specifics
* Make notes but do NOT search for bugs yet

**3. Hypotheses**
* Generate attack hypotheses in **Main**
* Include Rust-specific attacks (panics, ownership, unsafe)
* Perform first-pass validation
* Discard weak hypotheses early

**4. Deep analysis**
* Move surviving hypotheses into **Working**
* Use one or multiple Working chats as needed
* Focus on Rust-specific concerns (ownership flow, error paths, arithmetic)
* Iterate: analysis → conclusion → report-ready notes

**5. Findings**
* When a real issue is confirmed, switch to **Drafting**
* Use the Rust-specific drafting template
* Include ownership analysis and PoC code

**6. Coverage & signals**
* Use **SCAN** selectively as a signal generator
* Focus on Rust-specific patterns (unwrap, unsafe, unchecked math)
* Treat SCAN outputs as hints, not findings

**7. Review**
* Use **Review Mode** to check reasoning completeness
* Verify Rust-specific claims (ownership, panics, etc.)

**8. Iteration**
* When chats become heavy, transfer context and continue in new chat
* Avoid returning to Main late; continue via Working

---

## AUDIT LIFECYCLE — one-screen

```
[0] Local Setup
    └─ build merged.txt (all .rs files)
    └─ collect docs (README, Cargo.toml dependencies)
    └─ build scope index for manual audit

[1] Exploration
    └─ initial understanding of the protocol
    └─ map ownership patterns
    └─ understand framework (CosmWasm/Solana/Substrate)
    └─ make notes for further investigation

[2] Main — Idea Generation & Fast Filter
    └─ hypothesis generation (AI)
    └─ include Rust-specific attacks (panics, ownership, unsafe)
    └─ discard → out; questionable/alive → continue

[3] Manual Audit Marathon (loop)
    └─ manual code reading
    └─ focus on ownership flow, error paths

[4] Working — Deep Dive / Impact
    └─ surviving or interesting hypotheses
    └─ ownership analysis
    └─ error path tracing
    └─ preparing report raw material

[5] Drafting
    └─ formatting findings
    └─ Rust-specific PoC code
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
Prepare **one friendly file** with all in-scope Rust code.

### Input
* Working directory with **only in-scope Rust files**
* No third-party crates (dependencies via Cargo, not source)

### Build command (Rust)
```bash
(
  echo "INDEX"
  find src -name "*.rs" -type f | sort
  echo ""
  echo "=== CARGO.TOML ==="
  cat Cargo.toml
  echo ""
  echo "=== SOURCE FILES ==="
  find src -name "*.rs" -type f | sort | while read f; do
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
* CARGO.TOML (for dependency context)
* FILE / END FILE blocks

`merged.txt` **attached to the chats** and used in all steps.

---

## 2. MAIN CHAT PROMPTS

### General Rules
* One run = one role
* One run = one mental task
* Response format **strictly fixed**

---

### 2.1 Protocol Mapper (Rust Edition)

**Role:** Building a mental model of the Rust protocol

```text
[AUDIT AGENT: Protocol Mapper]

Instructions:
Follow the section "Protocol Mapper" EXACTLY (role + required output structure).

Available Code Context:
- The pinned file "merged.txt" contains the full in-scope Rust smart contracts.

Additional Context (README / spec / whitepaper):
- Use pinned project documentation if available.
- If no docs are pinned, ask me to paste relevant excerpts before making assumptions.

Task:
Produce the protocol model strictly in the required output structure.
Do NOT speculate. If information is missing, write "Unknown".

[ROLE: Protocol Mapper - Rust Edition]

You are a senior Rust/Web3 security auditor.

Analyze the provided Rust smart contracts and documentation.

Your task is NOT to find bugs yet.
Your task is to build a precise mental model of the protocol.

You MUST output strictly in the structure defined below.
No additional sections are allowed.

1. Protocol Purpose
- What problem does it solve?
- What blockchain/framework? (CosmWasm/Solana/Substrate/Other)

2. Assets
- What assets are at risk? (tokens, balances, NFTs, accounting units)
- How are they represented in Rust? (Uint128, custom types, etc.)

3. Trust Assumptions
- External dependencies (oracles, bridges, other contracts)
- Privileged roles (admin, owner, governance)
- Upgradeability/migration assumptions

4. State Management
- Key state structs and their purpose
- Storage patterns (Item, Map, IndexedMap, etc.)
- Ownership patterns (owned, borrowed, Arc/Rc)

5. Critical Flows
- User flows involving assets (deposit, withdraw, stake, swap)
- Admin flows
- For each flow, identify semantic phases: SNAPSHOT → VALIDATION → ACCOUNTING → MUTATION → COMMIT

6. Invariants
- What must always be true for the protocol to remain solvent?
- Reference: Universal invariants (no free money, no double spending, etc.)

7. Rust-Specific Concerns
- Any `unsafe` blocks? Where and why?
- Error handling patterns (Result, Option, custom errors)
- Panic potential (unwrap, expect, index access)
- Concurrency model (single-threaded, async)

8. Framework-Specific Notes
- **CosmWasm**: Entry points, IBC, submessages, migrations
- **Solana**: Account structure, PDAs, CPIs
- **Substrate**: Pallets, extrinsics, weights, storage

Do NOT speculate.
If information is missing, explicitly say "Unknown".

[END]
```

---

### 2.2 Attack Hypothesis Generator (Rust Edition)

**Role:** Generating Rust-specific attack scenarios

```text
[AUDIT AGENT: Attack Hypothesis Generator]

Instructions:
Follow the section "Attack Hypothesis Generator" EXACTLY
(role definition + constraints + output format).

Available Code Context:
- The pinned file "merged.txt" contains the full in-scope Rust smart contracts.

Protocol Context:
- Use the protocol model already produced in this chat by the Protocol Mapper.
- If the protocol model is missing or incomplete, ask me to provide it before proceeding.

Task:
Generate a bounded set of plausible attack hypotheses.
Do NOT validate exploits.
Do NOT search for concrete bugs yet.

[ROLE: Attack Hypothesis Generator - Rust Edition]

You are an adversarial security researcher specializing in Rust.

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
  - Grounded in protocol design and Rust-specific risks
- Include Rust-specific attack vectors:
  - Panic-based DoS (unwrap, expect, index bounds)
  - Arithmetic overflow/underflow
  - Ownership/borrowing violations
  - Unsafe code exploitation
  - Error path state corruption
- Include general Rust safety attack vectors (Awesome-Rust-Checker):
  - Unsound Send/Sync on generic types → data races (Rudra, 76 CVEs)
  - Panic safety: lifetime-bypass op + generic call → double-free/uninitialized (Rudra)
  - Self-deadlock via recursive lock acquisition (lockbud)
  - Lock-order inversion → deadlock (lockbud)
  - Atomic TOCTOU: load→check→store without CAS (lockbud)
  - Use-after-free via raw pointer outliving pointee (lockbud/RAPx)
  - Invalid free via MaybeUninit::assume_init without write (lockbud)
  - Memory leak via ManuallyDrop/Box::into_raw/proxy types without Drop (rCanary)
  - Timing side channel in crypto operations (MIRAI)
  - Taint flow from untrusted input to privileged operations (MIRAI)
- Include Solana-specific attack vectors (if Solana program):
  - Account validation bypass (missing owner/signer/discriminator)
  - Arbitrary CPI (unchecked program ID) [SVE-1016]
  - PDA exploitation (non-canonical bump, seed collision, PDA sharing)
  - Stale data after CPI (missing .reload()) [SF-10]
  - Type cosplay (same-layout struct confusion) [SVE-1010]
- Include Safe Solana Builder attack vectors (Frank Castle / SSB):
  - Duplicate mutable account: same account for two roles → free money [SSB]
  - CPI signer pass-through: unintended signer authority leaked [SSB-CPI-3]
  - SOL balance drain via CPI: callee spends excess SOL [SSB-CPI-4]
  - Post-CPI ownership change: attacker calls assign() during CPI [SSB-CPI-5]
  - init_if_needed hijack: pre-created account with attacker authority [SSB-ANC-2]
  - Token-2022 DoS: legacy transfer fails on Token-2022 mints [SSB-ANC-6]
  - Global vault blast radius: single PDA → exploit drains all users [SSB-CPI-8]
  - remaining_accounts injection: zero validation on injected accounts [SSB]
  - realloc dirty memory: stale data readable after shrink→grow [SSB-ANC-8]
  - Account reinitialization after improper close [SF-06]
  - Instruction introspection manipulation [SF-11]
  - Insecure randomness [SF-13]
  - Initialization frontrunning [SF-12]
  - Precision loss in token calculations [SF-17]
- Reference known exploit patterns:
  - CosmWasm: Anchor, Mirror, Astroport
  - Solana: Wormhole, Cashio, Mango, Jet-v1, Crema, spl-token-swap, Raydium, Nirvana
  - Substrate: Acala, Moonbeam
  - General Rust: Rudra 76 CVEs (Send/Sync variance), hyper (CVE-2021-32714, UnsafeDataflow), smallvec, crossbeam, once_cell unsafe impls
- Do NOT include purely speculative or unrealistic attacks.

Output STRICTLY in the following format:

For each hypothesis:

H<N>. <Short title>

Semantic Phase:
- Which phase is vulnerable? [SNAPSHOT/VALIDATION/ACCOUNTING/MUTATION/COMMIT/ERROR]
- Cross-phase interaction? (e.g., Snapshot→Mutation race)

Rust-Specific Vector:
- Panic risk? Arithmetic? Ownership? Unsafe?

Threat Model:
- Who is the adversary?
- What capabilities or privileges do they have?

Attack Idea:
- High-level description of the potential failure mode.
- Similar to known exploit? [Name if applicable]

Required Conditions:
- What must be true for this attack to work?

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

---

### 2.3 Code Path Explorer (Rust Edition)

**Role:** Deep testing of one hypothesis with Rust-specific analysis

```text
[AUDIT AGENT: Code Path Explorer]

Instructions:
Follow the section "Code Path Explorer" EXACTLY
(role definition + rules + output format).

Available Code Context:
The pinned file "merged.txt" contains the full in-scope Rust smart contracts.

Attack Hypothesis:
- Use hypothesis H<N> from the current Main Chat.
- Do NOT reinterpret or reformulate it unless explicitly asked.

Important: Do NOT analyze any hypothesis until I specify the exact H<N>.

Task:
Decide Valid / Invalid / Inconclusive and justify by tracing code paths.
Do NOT assume mitigations unless explicitly enforced in code.

[ROLE: Code Path Explorer - Rust Edition]

You are performing a deep logic audit of Rust smart contracts.

Use merged.txt to locate and analyze the relevant functions and code paths.
Your task is to determine whether a specific attack hypothesis
actually follows from the code.

**Methodology Reference:**
- Apply semantic phase analysis (SNAPSHOT → COMMIT → ERROR)
- Use the Rust-specific checklists from methodology
- Trace ownership and borrowing through the function

Your goals:
- Trace execution paths by semantic phase
- Track ownership changes (& → &mut → owned)
- Identify panic points (unwrap, expect, index, assert)
- Check arithmetic safety (checked_*, saturating_*)
- Analyze error paths for state cleanup
- Identify missing checks or incorrect ordering

Rules:
- Analyze exactly ONE hypothesis per run, specified by me as H<N>.
- Do NOT introduce new hypotheses.
- Do NOT expand scope beyond what the hypothesis assumes.
- Do NOT assume mitigations unless explicitly enforced in code.

When I provide H<N>, output STRICTLY:

Hypothesis:
- H<N> — <short title>

Ownership Analysis:
- Data flow: who owns what, where
- Borrowing pattern: &self vs &mut self
- Any unnecessary cloning?

Semantic Phase Trace:
- SNAPSHOT: What state is read? Is it fresh? Borrowing correct?
- VALIDATION: What checks exist? Can they panic? Can they be bypassed?
- ACCOUNTING: Any time/oracle dependencies? Arithmetic safety?
- MUTATION: What changes? Is value conserved? Overflow possible?
- COMMIT: Is state consistently written? Events emitted?
- ERROR: What happens on error? Is state cleaned up?

Rust-Specific Checks:
- [ ] No .unwrap()/.expect() in this path
- [ ] Arithmetic uses checked_*/saturating_*
- [ ] Bounds checking on array/vec access
- [ ] Match is exhaustive
- [ ] Error paths clean up state

Hypothesis Status:
- Valid / Invalid / Inconclusive

Validation Checks (ALL must pass for Valid):
- [ ] Reachability: Can this path execute on-chain?
- [ ] State Freshness: Does it work with current state?
- [ ] Execution Closure: Are external calls modeled?
- [ ] Economic Realism: Is cost/timing feasible?

Detailed Reasoning:
- Step-by-step reasoning through the code paths
- Include ownership transitions

Potential Exploit Path:
- If valid, describe a concrete exploit scenario with Rust code
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

### 2.4 Adversarial Reviewer (Rust Edition)

**Role:** Anti-false-positive with Rust-specific verification

```text
[AUDIT AGENT: Adversarial Reviewer]

Instructions:
Follow the section "Adversarial Reviewer" EXACTLY
(role definition + rules + output format).

Available Code Context:
The pinned file "merged.txt" contains the full in-scope Rust smart contracts.

Finding Under Review:
- I will paste a single security finding written by an auditor.
- Do NOT review anything until the finding is provided.

Task:
Assess whether the finding would survive triage.

[ROLE: Adversarial Reviewer - Rust Edition]

You are acting as a strict security triager for Rust smart contracts.

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
- If the finding claims specific Rust behavior, you MUST verify it:
  - Ownership claims
  - Panic conditions
  - Arithmetic safety
  - Error handling
- If verification is impossible, mark it explicitly.

When the finding is provided, output STRICTLY:

Assessment:
- Valid / Invalid / Context-dependent

Rust-Specific Verification:
- Ownership claims: Confirmed / Not confirmed
- Panic claims: Confirmed / Not confirmed  
- Arithmetic claims: Confirmed / Not confirmed
- Error handling claims: Confirmed / Not confirmed

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
Pay special attention to Rust-specific claims.
Do NOT introduce new vulnerabilities or scope.
Follow the same STRICT output format.
```

---

## 3. EXPLORATION CHAT PROMPTS (Rust Edition)

### Purpose
**Exploration Chat** is a mode for collaboratively *understanding* a Rust protocol before formalizing hypotheses.

### Universal Starter Query
```text
We are in the exploration phase.

Context:
- The pinned file "merged.txt" contains the full in-scope Rust smart contracts.
- No external crates are included (only standard library and framework).
- I am trying to understand the protocol design and developer intent.

Your role:
Act as a senior Rust protocol developer / architect.
Explain what the code is trying to achieve, not whether it is secure.

Rules:
- Do NOT look for vulnerabilities.
- Do NOT assess security or exploitability.
- Do NOT speculate beyond what can be inferred from code.
- If intent or assumptions are unclear, explicitly say so.

Task:
1) Give a high-level explanation of the protocol architecture.
2) Explain the ownership model and state management approach.
3) Identify key design decisions that are non-obvious.
4) List the main assumptions the design relies on.
5) Point out areas that are complex or easy to misunderstand.
6) Note any Rust-specific patterns (error handling, traits, generics).

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
Focus now on <FILE / MODULE>.
Use merged.txt and cite exact locations.
Explain the ownership patterns in this module.
```

---

## 4. WORKING CHAT PROMPTS (Rust Edition)

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
- Rust-specific concerns:
  - Ownership flow through the attack path
  - Panic potential and DoS impact
  - Arithmetic safety
  - Error path state corruption
- Secondary and cascading effects.
- Alternative actors, timings, and conditions.
- Whether the issue is reportable, and under what assumptions.

Allowed:
- Debate and challenge the hypothesis.
- Revisit validity if impact analysis reveals flaws.
- Explore multiple interpretations of the same issue.

Optional support:
- Help formulate PoC requirements in Rust
  (do NOT implement PoCs unless explicitly requested).

Out of scope:
- Generating new unrelated hypotheses.
- Auto-audit loops or mass scanning.
- Final report writing (handled elsewhere).

Source of truth:
- Use the pinned merged.txt and project documentation.

Your role:
Act as a senior Rust security auditor assisting in impact extraction
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
- Ownership flow
- Panic conditions
- Arithmetic operations
- Error handling
```

### Finding Template for Drafting
```text
Finding source: Working Chat

Summary:
<1–2 sentences, gist of the problem>

Rust-Specific Details:
- Ownership issue: [Yes/No — describe]
- Panic risk: [Yes/No — where]
- Arithmetic issue: [Yes/No — which operation]
- Error handling: [Yes/No — what's wrong]

Impact:
<what breaks / what risk>

Conditions:
<under what conditions, roles, states>

Code snippets:
<contracts / functions with ownership annotations>

Notes:
<anything important to keep but not included above>
```

---

## 5. FINDING DRAFTING CHAT PROMPTS (Rust Edition)

### Purpose
Preparing a clear, triage-friendly report on an already identified Rust issue.

### Starting Prompt
```text
We are in the finding drafting phase.

Context:
- The vulnerability has already been validated in a Working Chat.
- This chat is dedicated to preparing a clear, accurate vulnerability report.
- The pinned file "merged.txt" contains the full in-scope Rust smart contracts.

Your role:
Act as an experienced Rust security auditor and bug bounty triager.

General Rules:
- Do NOT invent new attack paths.
- Do NOT expand scope beyond the validated issue.
- Do NOT exaggerate impact.
- Be precise, conservative, and technically accurate.
- Include Rust-specific details:
  - Ownership analysis if relevant
  - Panic conditions if applicable
  - Arithmetic safety concerns
  - Error handling issues
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

### Rust-Specific Finding Template
```text
## [SEVERITY] <Title>

### Summary
<1-2 sentences describing the issue>

### Vulnerability Details

**Location:**
- File: `src/<file>.rs`
- Function: `<function_name>`
- Lines: L<start>-L<end>

**Rust-Specific Classification:**
- [ ] Panic risk (DoS)
- [ ] Arithmetic overflow/underflow
- [ ] Ownership/borrowing issue
- [ ] Error handling gap
- [ ] Unsafe code concern
- [ ] Access control bypass

**Root Cause:**
<Technical explanation of why the bug exists>

**Semantic Phase:**
<SNAPSHOT/VALIDATION/ACCOUNTING/MUTATION/COMMIT/ERROR>

### Impact
<What breaks, who loses what, severity justification>

### Proof of Concept

```rust
#[test]
fn test_exploit() {
    // Setup
    
    // Attack steps
    
    // Verify impact
}
```

### Recommended Fix

```rust
// Before (vulnerable)
<vulnerable code>

// After (fixed)  
<fixed code>
```

### References
- Similar to: <known exploit if applicable>
- Relevant Rust docs: <if applicable>
```

---

## 6. SCOPE INDEX PROMPT (Rust Edition)

### Purpose
Generate navigational artifact for Rust codebase review.

### Starting Prompt
```text
We are generating a draft Scope Index for manual Rust code review.

Context:
- The pinned file "merged.txt" contains the full in-scope Rust smart contracts.
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

Structure (Rust-specific):
- Core / State (`state.rs`, key structs)
- Entry Points (`contract.rs`, `lib.rs`)
- Messages (`msg.rs`, types)
- Error Handling (`error.rs`)
- Utilities / Helpers
- Tests (if in scope)
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

## 7. REVIEW MODE CHAT (Rust Edition)

### Purpose
Check completeness and correctness of Rust-specific reasoning.

### Starting Prompt
```text
You are reviewing an existing security finding for a Rust smart contract.

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
2) Verify Rust-specific claims:
   - Ownership/borrowing behavior
   - Panic conditions
   - Arithmetic operations
   - Error handling paths
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

Rust-Specific Verification:
- Ownership claims: Verified / Not verified
- Panic claims: Verified / Not verified
- Arithmetic claims: Verified / Not verified
- Error handling: Verified / Not verified

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

## 8. SCAN CHATS PROMPTS (Rust Edition)

### SCAN Paranoid Greedy (Rust)
```text
Context:
Perform a broad and paranoid security scan of the Rust smart contracts.

Goal:
List anything that looks suspicious, fragile, non-obvious, or inconsistent.

Instructions:
- Use the full code from merged.txt.
- Prefer false positives over false negatives.
- Do NOT validate findings or assess severity.

Rust-Specific Focus:
- .unwrap() and .expect() usage
- Unchecked arithmetic (+, -, *, /)
- unsafe blocks
- Missing bounds checks
- Non-exhaustive matches
- Clone in loops
- Error paths that don't clean state

General Focus:
- Missing or weak checks
- Unusual state transitions
- Edge states (zero supply, init, shutdown)
- Cross-contract interactions

Output:
Bulleted list.
For each item:
- Short description
- Affected file/function
- Why this might be risky (Rust-specific reason if applicable)
```

### SCAN Panic Points
```text
Context:
Scan for potential panic points in Rust smart contracts.

Goal:
Identify all locations where the contract could panic.

Focus:
- .unwrap() calls
- .expect() calls
- Array/Vec indexing without bounds check
- assert! and assert_eq! macros
- panic! macros
- Division operations (potential divide by zero)
- Integer overflow in debug mode

Output:
For each panic point:
- Location (file:line)
- Type (unwrap/expect/index/assert/panic/division/overflow)
- Context (what function, what data)
- Reachability (can user trigger this?)
- Impact (DoS? State corruption?)
```

### SCAN Arithmetic Safety
```text
Context:
Scan for arithmetic safety issues in Rust smart contracts.

Goal:
Identify unchecked arithmetic operations.

Focus:
- Addition (+) without checked_add
- Subtraction (-) without checked_sub
- Multiplication (*) without checked_mul
- Division (/) without checked_div or zero check
- Modulo (%) without zero check
- Type casting that could overflow
- Accumulator patterns

Output:
For each issue:
- Location (file:line)
- Operation type
- Values involved (if determinable)
- Whether overflow/underflow is possible
- Recommended fix
```

### SCAN Ownership Patterns
```text
Context:
Scan for potentially problematic ownership patterns in Rust smart contracts.

Goal:
Identify ownership/borrowing patterns that could indicate issues.

Focus:
- Unnecessary .clone() calls (especially in loops)
- &mut self when &self would suffice
- Moving values that should be borrowed
- References held across await points (if async)
- Complex lifetime annotations
- Rc/Arc usage patterns

Output:
For each pattern:
- Location
- Pattern type
- Why it might be problematic
- Suggested improvement
```

### SCAN Solana Account Validation (solana-fender + x-ray patterns)
```text
Context:
Perform a comprehensive Solana account validation scan aligned with
solana-fender (19 analyzers), x-ray SVE IDs, and OWASP Solana Top 10.

Goal:
Identify all account validation weaknesses in the Solana/Anchor program.

Focus — check ALL of these categories:

**Access Control [SVE-1001, SF-01, OWASP #3]**
- Authority/admin/owner fields using AccountInfo instead of Signer<'info>
- Instructions without is_signer validation
- Global singleton PDAs initializable by anyone (frontrunning) [SF-12]

**Account Validation [SVE-1002/1007/1010/1019, SF-02/03/07/08/09, OWASP #2/#6]**
- try_from_slice/BorshDeserialize without .owner == program_id check
- Borsh structs without discriminator field (type cosplay risk)
- Two+ Account<'info> fields without key() != constraint (duplicate accounts)
- SPL TokenAccount::unpack without authority match
- Init functions without reinitialization guard
- Sysvar accounts without ID validation [SF-15]

**CPI Security [SVE-1016, SF-04/10/18, OWASP #5]**
- invoke/invoke_signed without program ID validation
- Account data read after CPI without .reload()
- State mutation after CPI call (reentrancy risk)

**PDA Security [SVE-1014/1015, SF-05/16/19, OWASP #6]**
- create_program_address with user-provided bump seed
- PDA seeds without user-specific component (only mint+bump)
- PDA seeds without hardcoded string prefix (seed collision)

**Arithmetic [SVE-1003-1006, SF-14/17, OWASP #1/#4]**
- Unchecked arithmetic (+, -, *, /) — check if overflow-checks=true in Cargo.toml
- Division before multiplication (precision loss)
- checked_div where checked_ceil_div is needed

**Account Lifecycle [SF-06]**
- Closing accounts without discriminator set + data zeroed

**Transaction Security [SF-11/13, SVE-1017]**
- load_instruction_at_checked with absolute index
- Clock/slot-based randomness
- Slot comparison for malicious simulation

Output:
For each finding:
- Category code (SVE-XXXX or SF-NN)
- Location (file:function:line)
- Severity (Critical/High/Medium/Low)
- Description
- Anchor auto-mitigated? (Yes/No — check for Account<>, Signer<>, Program<> types)
- Recommended fix
```

### SCAN Solana CPI & PDA Deep Dive
```text
Context:
Deep scan specifically for CPI and PDA security in a Solana program.
These are the two most exploited vulnerability classes in Solana history
(Wormhole, Cashio, Crema, jet-v1).

Goal:
Map all CPI calls and PDA derivations, then validate each for security.

For each CPI call (invoke / invoke_signed / CpiContext):
1. What program is being called? Is it validated?
2. What accounts are passed? Are they all validated?
3. Is state updated BEFORE the CPI? (reentrancy protection)
4. Are accounts reloaded AFTER the CPI before reuse?
5. Is the CPI result properly error-handled?

For each PDA derivation (find_program_address / create_program_address / seeds=):
1. Are seeds unique per user/purpose? (not just mint+bump)
2. Does the first seed element have a hardcoded string prefix?
3. Is the canonical bump used? (not user-provided)
4. Is the bump stored in account data for efficient reuse?
5. Could two different PDA types share the same seed combination?

Output:
CPI MAP:
- [CPI-1] Location → Target program → Validated? → State before CPI? → Reload after?
- [CPI-2] ...

PDA MAP:
- [PDA-1] Type → Seeds → Canonical bump? → Prefix? → Unique? → Collision risk?
- [PDA-2] ...

Red flags to escalate to Working Chat.
```

### SCAN Solana Safe Builder (Frank Castle / SSB patterns)
```text
Context:
Deep scan using Safe Solana Builder rules drawn from real audit findings.
Covers CPI edge cases, Token-2022 compatibility, account lifecycle,
duplicate mutable accounts, and the Curiosity Principle adversarial mindset.
Complements the Account Validation and CPI/PDA SCANs above.

Goal:
Identify safe-solana-builder (SSB) pattern violations that automated tools miss.

PART A — RISK ASSESSMENT:
1. Classify program risk: 🟢 Low / 🟡 Medium / 🔴 Critical
   - 🔴 = vaults, AMM, lending, bridges, multi-CPI, admin keys, large TVL
   - Flag every admin key, upgrade authority, irreversible state transition

PART B — CURIOSITY PRINCIPLE (ask for every account input):
2. What happens if the same account is passed for two different roles?
3. What happens if this account is owned by a different program?
4. What happens if this is a Token-2022 mint instead of legacy?
5. What happens if the CPI returns success but didn't actually execute?
6. What happens if the program ID passed is a malicious lookalike?
7. What happens if this PDA bump is not canonical?

PART C — CPI SAFETY SURFACE (beyond basic program ID check):
8. Are signer privileges sanitized before CPI? (only needed signers passed) [SSB-CPI-3]
9. Is signer SOL balance verified before and after CPI? [SSB-CPI-4]
10. Is account ownership re-verified after CPI? (attacker can `assign`) [SSB-CPI-5]
11. Are CPI errors propagated (`?`)? Could callee return success without acting? [SSB-CPI-6]
12. Is invoke_signed used only when PDA must sign? No non-signer elevation? [SSB-CPI-7]

PART D — TOKEN-2022 COMPATIBILITY:
13. Does any code use legacy `token::transfer` (not `transfer_checked`)? [SSB-ANC-6]
14. Are account types using `InterfaceAccount` (not `Account<TokenAccount>`)? [SSB-ANC-6]
15. Is token program type `Interface<TokenInterface>` (not `Program<Token>`)? [SSB-ANC-6]
16. Are Token-2022 features (transfer hooks, confidential) flagged for review?

PART E — ANCHOR-SPECIFIC PITFALLS:
17. Any `init_if_needed` without reinitialization guard on existing state? [SSB-ANC-2]
18. Any `realloc` without `zero_init = true`? [SSB-ANC-8]
19. Any `UncheckedAccount` without substantive `/// CHECK:` comment? [SSB-ANC-1]
20. Cross-account relationships enforced via `has_one` (not manual compare)? [SSB-ANC-3]
21. Account closing via `close = recipient` (not manual lamport drain)? [SSB-ANC-4]

PART F — BLAST RADIUS & LIFECYCLE:
22. Is there a global vault PDA? → per-user PDAs preferred [SSB-CPI-8]
23. Are remaining_accounts validated with same rigor as named accounts? [SSB]
24. Account close: zero data + drain lamports + assign System Program (all 3 steps)?
25. Close recipient: trusted address or arbitrary user-supplied?
26. New accounts funded with rent.minimum_balance(size) (not hardcoded)?

PART G — NATIVE RUST (if non-Anchor):
27. 6-step validation sequence: key→owner→signer→writable→discriminator→data?
28. try_from_slice for deserialization (not raw byte casting / transmute)?
29. data_len >= T::LEN verified before deserialization?
30. No unwrap()/expect() in instruction handlers?

Output per finding:
- SSB pattern ID (SSB-CPI-N or SSB-ANC-N)
- Location (file, function, line)
- Severity (Critical/High/Medium/Low)
- Recommended fix
- Curiosity Principle question that exposes it
```

### SCAN General Rust Safety (Awesome-Rust-Checker patterns)
```text
Context:
Deep scan for general Rust safety issues: unsound unsafe code, concurrency bugs,
memory safety violations, and verification gaps. Uses detection patterns from
Rudra (76 CVEs), lockbud, RAPx, rCanary, and MIRAI.

Goal:
Systematically check for every Awesome-Rust-Checker pattern applicable to the codebase.

PART A — UNSAFE CODE SOUNDNESS (Rudra patterns):
For every `unsafe impl Send` or `unsafe impl Sync` for a generic type:
1. Are ALL generic type parameters bounded by Send (for Send impls) or Sync (for Sync impls)?
2. Is PhantomData<T> properly accounted for?
3. Does the API behavior justify weaker bounds? (e.g., concurrent queue: T: Send suffices for Sync)

For every `unsafe` block:
4. Does it contain a lifetime-bypassing op (ptr::read, Vec::set_len, from_raw_parts, transmute)?
5. After the lifetime bypass, can ANY generic/user-provided function be called? (panicking → double-free)
6. Is ptr::read used on a non-Copy type? (ownership duplication → double-free)

For every `impl Drop` with unsafe code:
7. Is the unsafe call an FFI extern (expected) or a Rust unsafe fn (suspicious)?
8. Could the destructor run twice (via ManuallyDrop::drop)?
9. Is the pointer valid at drop time? Could it be aliased elsewhere?

PART B — CONCURRENCY (lockbud patterns):
10. Are any Mutex/RwLock guards held while the SAME lock is re-acquired? (DoubleLock)
11. Are there two code paths that acquire locks A,B vs B,A? (ConflictLock)
12. Do Condvar wait/notify paths share a lock beyond the wait mutex?
13. Are atomic load→store pairs non-atomic? (should be compare_exchange or fetch_add)

PART C — MEMORY SAFETY (lockbud + RAPx patterns):
14. Are raw pointers used after their pointee is dropped?
15. Is MaybeUninit::assume_init() preceded by .write() on ALL control flow paths?
16. Are mem::uninitialized() or mem::zeroed() used on non-trivial types?
17. Are ManuallyDrop/Box::into_raw values eventually reclaimed?
18. Do structs with *mut T / *const T fields implement Drop?

PART D — VERIFICATION (MIRAI patterns):
19. Is crypto key/MAC comparison constant-time? (no early return on byte mismatch)
20. Does untrusted input flow to privileged operations without sanitization?
21. Are all reachable panic! / unwrap / expect paths intentional?

Output per finding:
- Pattern ID (RUST1–RUST10) and tool reference
- Location (file, function, line)
- Severity (Critical/High/Medium/Low)
- Confidence (High/Medium/Low)
- Whether tool would catch it (Rudra/lockbud/RAPx/rCanary/MIRAI)
- Recommended fix
```

---

---

## 9. HYPOTHESES FORMULATION CHAT (Rust Edition — experimental)

### Purpose
Transform vague intuitions about Rust code into testable security hypotheses.

### Hypotheses Formulation Chat — start-prompt
```text
Context:
This chat is dedicated to formulating security hypotheses for Rust smart contracts.

Scope:
- Transform vague intuitions, discomfort, or unclear design choices
  into neutral, well-formed security hypotheses.
- Focus on ownership patterns, error handling assumptions, arithmetic invariants,
  and non-obvious system states.
- Do NOT validate hypotheses.
- Do NOT analyze exploitability.
- Do NOT assess impact or severity.

Out of scope:
- Code path analysis.
- Adversarial reasoning.
- Proofs or refutations.
- Findings or report drafting.

Your role:
Act as a hypothesis formulator for Rust smart contracts.
Help me articulate *why something feels non-obvious or fragile*,
without asserting that it is a bug.

Rust-specific focus areas for hypothesis formulation:
- Ownership transfers that seem unnecessary or unusual
- Error paths that might leave state partially mutated
- Arithmetic that relies on implicit bounds
- Framework-specific patterns that deviate from best practices
- Cross-contract calls that assume specific response formats
- State that could be deserialized differently after migration

Solana-specific focus areas (if applicable):
- Account structs using AccountInfo where Signer/Account/Program types exist
- CPI calls where the program target comes from user input
- PDA seeds that look insufficient for uniqueness (no prefix, no user key)
- Accounts used after CPI without reload — could data be stale?
- Close functions that zero lamports but not discriminator/data
- Two mutable accounts of the same type without inequality constraint
- Init functions without reinitialization guards
- Division-before-multiplication patterns in token/fee calculations
- Clock/slot usage in security-critical randomness
- Instruction introspection with hardcoded absolute indexes

Solana Safe Builder focus areas (Frank Castle / SSB):
- CPI passing all remaining_accounts including unintended signers [SSB-CPI-3]
- No SOL balance check before/after CPI — excess spend undetected [SSB-CPI-4]
- Account ownership not re-verified after CPI — attacker can assign() [SSB-CPI-5]
- `init_if_needed` accepting pre-created accounts with attacker state [SSB-ANC-2]
- `realloc` without `zero_init = true` — stale memory after shrink→grow [SSB-ANC-8]
- Legacy `token::transfer` instead of `transfer_checked` — Token-2022 DoS [SSB-ANC-6]
- Global vault PDA for all users — one exploit drains everyone [SSB-CPI-8]
- `remaining_accounts` iterated without ownership/signer/type checks [SSB]
- `UncheckedAccount` without substantive `/// CHECK:` explanation [SSB-ANC-1]
- Apply Curiosity Principle: for every account, ask the 6 adversarial questions

General Rust safety focus areas (all targets):
- `unsafe impl Send/Sync` for generic types without proper trait bounds
- `unsafe` blocks containing ptr::read on non-Copy types or set_len + generic calls
- Drop impls calling Rust unsafe fns (vs FFI extern — the expected case)
- Mutex/RwLock re-acquisition in same call chain (self-deadlock)
- Lock acquisition order inconsistency across functions (A→B vs B→A)
- Atomic load→check→store without compare_exchange (TOCTOU)
- Raw pointers surviving beyond the lifetime of their pointee (UAF)
- MaybeUninit::assume_init() without preceding .write() on all paths
- ManuallyDrop / Box::into_raw / Box::leak without reclamation
- Structs with *mut T fields that don't implement Drop (memory leak)
- Secret-dependent branches or early-return in crypto comparisons
- Taint: user input reaching unsafe operations without validation
```

### Examples:
```text
This function uses .unwrap() on a storage load.
The developers probably assume the key always exists.
Help me formulate a hypothesis about when it might not exist.

The LP token calculation uses multiplication before division.
I'm not sure if this is safe with very large or very small values.
Help formulate a correct hypothesis about precision loss.

This CosmWasm reply handler doesn't check the reply ID.
I have a feeling this could be exploited but I can't articulate how.
Help me turn this into a testable hypothesis.

Below is an excerpt from the Cashio exploit analysis.
Don't look for bugs.
Help translate this into 2-3 neutral hypotheses
that can be tested in a different Solana program.

This hypothesis sounds too accusatory.
Reframe it so that it questions the assumption,
rather than asserting a risk.
```

---

## 10. UNIVERSAL SCOPE TRANSFER PROMPT (Rust Edition)

### Purpose
Move context to a new chat when the current one becomes too long.

### Prompt for "moving context" to a new chat

```text
You are the assistant preparing the context for moving a Rust smart contract audit to a new chat.
Please put together a brief but complete "context package" for the current conversation.

**Result Requirements:**

1. Write in a structured manner, without unnecessary fluff.
2. Don't invent anything that wasn't in the chat — if there's no information, mark it "not specified."
3. Include everything important for continuing work in the new chat.
4. Also note that the chat contains **pinned files** — list them and what they use (if known).

**Form your answer in this format:**

### 1) What is this project (1-3 sentences)
Include: Framework (CosmWasm/Solana/Substrate), main purpose, key contracts/modules.

### 2) Goal / Expected Result

### 3) Current Status (what has already been done)
Include: Which hypotheses were generated, which were validated/invalidated.

### 4) What are we currently discussing / deciding (main focus)

### 5) Key Decisions and Agreements (list)

### 6) Open Issues / Risks / What's Unclear

### 7) Next Steps (Todo Items for the Next 3-10 Tasks)

### 8) Terms / Entities / Important Names (Glossary)
Include: Key Rust types, state structs, entry points, error types.

### 9) Pinned Files and How They Are Used

* File Name → What is it for → Which Parts are Important

### 10) Rust-Specific Context
* Framework and version
* Key state management patterns
* Known .unwrap() / unsafe / unchecked arithmetic locations
* Ownership patterns worth tracking

### 11) What does the new chat need from me (what input to ask the user)

Add a block at the end:
**"Short Version (up to 10 lines)"** — so I can insert it as the starting context in a new chat.
```

---

## APPENDIX: QUICK REFERENCE

### Semantic Phases (Rust)
| Phase | Indicators | Key Checks |
|-------|------------|------------|
| SNAPSHOT | `&self`, `load`, `get`, `clone` | Borrowing, freshness, gas |
| VALIDATION | `ensure!`, `?`, error arms | Panic-free, complete |
| ACCOUNTING | `env.block.*`, fees | Time safety, precision |
| MUTATION | `&mut self`, `insert`, math | Ownership, conservation |
| COMMIT | `save`, `store`, events | Persistence, events |
| ERROR | `Result`, `Option`, `unwrap` | Cleanup, no corruption |

### Rust Red Flags
```
.unwrap()     → ok_or(Error)?
.expect()     → ok_or(Error)?
a + b         → checked_add
a - b         → checked_sub
vec[i]        → vec.get(i)
unsafe { }    → justify or remove
.clone()      → use references
for x in vec  → add limits
```

### Validation Checks
| Check | Pass Criteria |
|-------|--------------|
| Reachability | Function is `pub` with entry point |
| State Freshness | Works with realistic state |
| Execution Closure | External calls modeled |
| Economic Realism | Attack is profitable/feasible |

---

**Framework Version:** 3.2
**Last Updated:** March 2026
**Target Ecosystems:** CosmWasm, Solana/Anchor, Substrate, General Rust
**Enhanced with:** ClaudeSkills Trail of Bits patterns, InfoSec_Us_Team methodology, solana-fender (19 analyzers), x-ray SVE IDs, OWASP Solana Top 10, Awesome-Rust-Checker (Rudra/lockbud/RAPx/rCanary/MIRAI), Safe Solana Builder (Frank Castle — SSB patterns)
