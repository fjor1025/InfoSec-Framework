# Audit Assistant Playbook (Cosmos-SDK Edition)
## Cognitive Framework for Cosmos-SDK Security Auditing

* **Status:** Experimental / Practitioner Tool
* **Audience:** Experienced blockchain security auditors working with Cosmos-SDK chains
* **Target Frameworks:** Cosmos SDK, CometBFT, IBC, Interchain Security, CosmWasm (native module integration)

This playbook describes a **minimal, reproducible flow** for working with LLMs when auditing **Cosmos-SDK-based blockchain applications**.

This playbook does NOT automate security audits.
It does NOT replace auditor judgment.
It structures how auditors think, explore, validate, and report findings.

---

## METHODOLOGY INTEGRATION

This playbook structures **conversations**. The actual audit **methodology** lives in:

| File | Purpose | When to Reference |
|------|---------|-------------------|
| `Cosmos-SDK-Security-Audit-Methodology.md` | Cosmos-specific threat model, vulnerability classes, checklists | During all audit phases |
| `CommandInstruction-Cosmos.md` | System prompt for Cosmos audit sessions | At start of any audit chat |
| `../Go-SmartContract/Go-Smart-Contract-Audit-Methodology.md` | Go-generic patterns (pointers, errors, panics) | For Go-level code analysis |

**Key Methodology Concepts to Apply:**
- **Threat Model Actors**: Validators (semi-trusted), Relayers (liveness-trust), Governance (weapon), Users (adversarial)
- **Vulnerability Classes**: State Desync, Keeper Permissions, Module Isolation, Governance Hooks, Slashing/Reward, Gas/DoS, Consensus Errors, IBC Attacks
- **Go Semantic Phases**: VALIDATION → SNAPSHOT → ACCOUNTING → MUTATION → COMMIT → EVENTS → ERROR
- **Validation Checks**: Reachability, State Freshness, Execution Closure, Economic Realism
- **Trail of Bits Patterns**: C1 (GetSigners), C2 (Non-determinism), C3 (Message Priority), C4 (Slow ABCI), C5 (ABCI Panic), C6 (Broken Bookkeeping)

---

## HOW TO USE THIS PLAYBOOK (REAL AUDIT FLOW)

**1. Prepare context**
* Build `merged.txt` with all in-scope `.go` files
* Gather project documentation (README, spec, ADRs, governance proposals)
* Identify SDK version, IBC version, and CometBFT version from `go.mod`
* Generate the Scope Index for navigation

**2. Architecture mapping (Day 1)**
* Start with **Exploration** — understand module structure
* Map keeper dependencies, store keys, message routing
* Identify trust boundaries: which modules call which keepers?
* Map ABCI lifecycle: what happens in BeginBlock, EndBlock, CheckTx?
* Identify IBC integration points (if applicable)
* Do NOT search for bugs yet

**3. Threat model construction**
* Identify all actors and their capabilities (Section 2 of methodology)
* For each module, determine: who can call it? what state does it modify?
* Map governance attack surface: what parameters can be changed?
* Map IBC attack surface: which channels, what packet types?

**4. Hypothesis generation**
* Generate attack hypotheses in **Main Chat**
* Use the vulnerability classes from Section 3 as a checklist
* Include IBC-specific hypotheses (Section 4)
* Include governance/upgrade hypotheses (Section 5)
* Include economic/game-theoretic hypotheses (Section 6)
* Discard weak hypotheses early

**5. Deep analysis**
* Move surviving hypotheses into **Working Chat**
* Focus on cross-module interactions and trust boundary violations
* Build PoC test code for confirmed findings
* Calculate economic impact for each finding

**6. Findings**
* When a real issue is confirmed, switch to **Drafting Chat**
* Use the Cosmos-SDK finding template (Section 9 of methodology)
* Include governance/consensus defense analysis
* Include IBC implications if cross-chain

**7. Coverage & signals**
* Use **SCAN** mode selectively for pattern detection
* Focus on: non-determinism, panics in ABCI, keeper permission gaps
* Treat SCAN outputs as hints, not findings

**8. Review**
* Use **Adversarial Reviewer** to check reasoning completeness
* Verify Cosmos-specific claims (IBC, governance, consensus)

---

## AUDIT LIFECYCLE — one-screen

```
[0] Local Setup
    └─ build merged.txt (all .go files)
    └─ collect docs (README, go.mod, ADRs, specs)
    └─ identify SDK/IBC/CometBFT versions
    └─ build scope index

[1] Architecture Mapping
    └─ map module structure and keeper dependencies
    └─ identify message flow (CheckTx → DeliverTx)
    └─ map ABCI lifecycle (BeginBlock/EndBlock)
    └─ map IBC integration points
    └─ identify trust boundaries

[2] Threat Model
    └─ classify actors (validator, relayer, gov, user)
    └─ map governance attack surface
    └─ map IBC attack surface
    └─ identify invariants and trust assumptions

[3] Main — Hypothesis Generation & Fast Filter
    └─ generate hypotheses per vulnerability class
    └─ include IBC, governance, economic attacks
    └─ discard → out; questionable/alive → continue

[4] Manual Audit Marathon
    └─ manual code reading
    └─ focus on keeper interactions, error paths
    └─ focus on BeginBlock/EndBlock safety

[5] Working — Deep Dive / Impact
    └─ surviving hypotheses
    └─ cross-module interaction analysis
    └─ economic impact calculation
    └─ PoC construction

[6] Drafting
    └─ formatting findings with Cosmos template
    └─ governance/consensus defense analysis
    └─ report format
```

### Key Properties
* Architecture Mapping — **prerequisite** for effective hypothesis generation
* Threat Model — **required** before generating hypotheses
* Main — **hypothesis pipeline**, a single chat per project
* Working — **live thinking zone** for deep analysis

> **AI accelerates filtering and formalization.**
> **Humans make decisions and sense the design.**

---

## **1. BUILD LAYER**

### Purpose
Prepare **one friendly file** with all in-scope Cosmos SDK code.

### Build Command (Cosmos SDK Module)
```bash
(
  echo "INDEX"
  find . -name "*.go" -type f ! -path "./vendor/*" ! -name "*_test.go" | sort
  echo ""
  echo "=== GO.MOD ==="
  cat go.mod
  echo ""
  echo "=== APP.GO (Module Registration) ==="
  find . -name "app.go" -exec echo "FILE: {}" \; -exec cat {} \; -exec echo "END FILE: {}" \;
  echo ""
  echo "=== PROTO DEFINITIONS ==="
  find . -name "*.proto" -type f | sort | while read f; do
    echo "FILE: $f"
    cat "$f"
    echo "END FILE: $f"
    echo ""
  done
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
* GO.MOD (dependency versions — critical for Cosmos SDK version identification)
* APP.GO (module registration order, keeper wiring)
* PROTO (message types, service definitions — reveals unregistered handlers)
* FILE / END FILE blocks (all source code)

---

## **2. MAIN CHAT PROMPTS**

### General Rules
* One run = one role
* One run = one mental task
* Response format **strictly fixed**

---

### 2.1 Cosmos Architecture Mapper

**Role:** Building a security-focused model of the Cosmos SDK application

```text
[AUDIT AGENT: Cosmos Architecture Mapper]

Instructions:
Build a security-focused architectural model of this Cosmos SDK application.

Available Code Context:
- The pinned file "merged.txt" contains the full in-scope Go code.
- Focus on: app.go, module registration, keeper wiring, ABCI hooks.

Task:
Produce the architecture model strictly in the required output structure.
Do NOT speculate. If information is missing, write "Unknown".

[ROLE: Cosmos Architecture Mapper]

You are a senior Cosmos SDK security auditor.
Your task is NOT to find bugs yet.
Your task is to build a precise security model of the application.

Output STRICTLY in this structure:

1. SDK & Dependency Versions
- Cosmos SDK version (from go.mod)
- CometBFT / Tendermint version
- IBC-go version (if present)
- Other critical dependencies

2. Module Registration (from app.go)
- List all registered modules
- Module initialization order
- Which modules have BeginBlocker/EndBlocker
- Module account permissions (minter, burner, staking)

3. Keeper Dependency Graph
- For each custom module's keeper:
  - Which external keepers does it depend on?
  - What interface does it use for each?
  - Which methods from each interface are actually called?

4. Message Flow
- List all MsgServer methods per module
- For each: entry point → validation → state changes → cross-module calls
- Flag any unregistered proto RPCs (compare proto service defs vs RegisterServices)

5. ABCI Lifecycle
- BeginBlocker: What each module does (bounded? panic-safe? deterministic?)
- EndBlocker: What each module does
- CheckTx customizations (custom AnteHandlers)
- PrepareProposal / ProcessProposal (if v0.47+)

6. IBC Integration (if applicable)
- Which modules implement IBCModule interface
- Channel types (ORDERED/UNORDERED)
- Packet types and their handlers
- OnRecvPacket / OnAcknowledgement / OnTimeout logic

7. Trust Boundaries
- What state can external users modify?
- What state requires governance?
- What state requires validator consensus?
- What state depends on IBC counterparty?

8. Registered Invariants
- List all invariants
- For each: can an external user break it?

Do NOT speculate.
If information is missing, explicitly say "Unknown".

[END]
```

---

### 2.2 Cosmos Threat Model Builder

**Role:** Constructing a Cosmos-specific threat model

```text
[AUDIT AGENT: Cosmos Threat Model Builder]

Instructions:
Build the threat model using the architecture model and methodology Section 2.

Available Code Context:
- The pinned file "merged.txt" and the architecture model from the previous step.

Task:
Produce a threat model for this specific Cosmos SDK application.

[ROLE: Cosmos Threat Model Builder]

Using the architecture model, answer:

1. Actor Capabilities
For each actor type (User, Validator, Relayer, Governance, Admin):
- What messages can they send?
- What state can they modify?
- What is their trust level?
- What is their attack motivation?

2. Economic Attack Surface
- What is the TVL or value at risk?
- What is the cost to capture governance?
- Are there MEV opportunities?
- Can validators extract value via ordering?

3. Cross-Module Attack Surface
- Which keeper calls cross module boundaries?
- Can errors in Module A corrupt Module B's state?
- Are there hook callback chains that could cascade failures?

4. IBC Attack Surface (if applicable)
- What happens if a malicious counterparty chain sends crafted packets?
- What if a relayer delays all packets by the maximum timeout?
- What if IBC tokens are burned/minted unexpectedly?

5. Governance Attack Surface
- What parameters can governance change?
- What is the minimum cost to pass a governance proposal?
- Can a governance proposal brick the chain?
- Can upgrade proposals inject backdoors?

6. Key Invariants Under Threat
For each invariant: what actor, with what capability, could break it?

Do NOT speculate beyond the code.
If information is missing, write "Unknown".

[END]
```

---

### 2.3 Cosmos Hypothesis Generator

**Role:** Generating Cosmos-specific attack hypotheses using the 8 vulnerability classes

```text
[AUDIT AGENT: Cosmos Hypothesis Generator]

Instructions:
Generate attack hypotheses using the vulnerability classes from
Cosmos-SDK-Security-Audit-Methodology.md Section 3.

Available Code Context:
- merged.txt, architecture model, and threat model from previous steps.

Constraints:
- Generate at most **20 hypotheses**
- Organize by vulnerability class:
  1. State Desynchronization
  2. Incorrect Keeper Permissions
  3. Improper Module Isolation
  4. Unsafe Governance Hooks
  5. Slashing / Reward Manipulation
  6. Gas & DoS Vectors
  7. Consensus-Level Logic Errors (Non-Determinism)
  8. IBC-Specific Attacks
- For each hypothesis include:
  - Vulnerability class
  - Semantic phase affected
  - Actor and capability required
  - Similar to known exploit? (Dragonberry, Jackfruit, Osmosis, etc.)
  - What to inspect in code

Output STRICTLY:

H<N>. <Short title>

Vulnerability Class: [1-8]
Semantic Phase: [VALIDATION/SNAPSHOT/ACCOUNTING/MUTATION/COMMIT/ERROR]
Actor: [User/Validator/Relayer/Governance]
Attack Idea: [2-3 sentences]
Known Pattern Match: [exploit name or "Novel"]
Required Conditions: [bullet list]
What to Inspect: [specific files/functions/keepers]

[END]
```

---

### 2.4 Cosmos Code Path Explorer

**Role:** Deep validation of one Cosmos-specific hypothesis

```text
[AUDIT AGENT: Cosmos Code Path Explorer]

Instructions:
Validate ONE hypothesis from the Cosmos Hypothesis Generator.

When I provide H<N>, output STRICTLY:

Hypothesis:
- H<N> — <short title>
- Vulnerability Class: [from hypothesis]

Trust Boundary Analysis:
- Which trust boundary is being violated?
- What trust assumption is the attacker exploiting?

Keeper Interaction Trace:
- Which keepers are involved?
- What interface methods are called?
- Are errors from keeper calls checked?

Semantic Phase Trace:
- VALIDATION: What checks exist? Can they be bypassed?
- SNAPSHOT: What state is loaded? Is it fresh?
- ACCOUNTING: Any time/oracle dependencies?
- MUTATION: What state changes? Cross-module effects?
- COMMIT: Is state consistently committed?
- ERROR: What happens on error? Partial state cleanup?

Cosmos-Specific Checks:
- [ ] No non-determinism in this path
- [ ] No panics in BeginBlocker/EndBlocker path
- [ ] Keeper interface doesn't over-expose capabilities
- [ ] Module account balance tracking is consistent
- [ ] IBC packet validation is complete (if applicable)
- [ ] Governance cannot bypass this control (if applicable)

Go-Specific Checks:
- [ ] No ignored error returns
- [ ] No panic in production code
- [ ] Zero-value structs handled safely
- [ ] Pointers not modified before validation

Hypothesis Status: Valid / Invalid / Inconclusive

Validation Checks:
- [ ] Reachability: Handler registered? Message routed?
- [ ] State Freshness: Works with realistic state?
- [ ] Execution Closure: Cross-module and IBC calls modeled?
- [ ] Economic Realism: Attack profitable/feasible?

Detailed Reasoning:
[Step-by-step code path analysis]

Potential Exploit Path:
[If valid: concrete scenario with transaction sequence]
[If invalid: what prevents exploitation]

[END]
```

---

### 2.5 Cosmos Adversarial Reviewer

**Role:** Triage-grade review of Cosmos-specific findings

```text
[AUDIT AGENT: Cosmos Adversarial Reviewer]

Instructions:
Review ONE finding with skeptical stance.
Verify Cosmos-specific claims.

When the finding is provided, output STRICTLY:

Assessment: Valid / Invalid / Context-dependent

Cosmos-Specific Verification:
- Trust boundary claims: Confirmed / Not confirmed
- Keeper interaction claims: Confirmed / Not confirmed
- IBC claims (if any): Confirmed / Not confirmed
- Governance defense claims: Confirmed / Not confirmed
- Consensus impact claims: Confirmed / Not confirmed
- Economic impact claims: Confirmed / Not confirmed

Go-Specific Verification:
- Pointer claims: Confirmed / Not confirmed
- Error handling claims: Confirmed / Not confirmed
- Non-determinism claims: Confirmed / Not confirmed
- Panic claims: Confirmed / Not confirmed

Counterarguments:
- What assumptions are not proven by the finding
- What mitigations exist that the finding doesn't address

Code Verification:
- Confirmed / Not confirmed / Partially confirmed
- Reference exact functions and state

Residual Risk:
- What remains if the finding is partially valid

Reviewer Notes:
- What would block acceptance by a triager
- What clarification or evidence is missing
- Does the economic impact analysis hold?

[END]
```

---

## **3. EXPLORATION CHAT PROMPTS**

### Universal Starter Query
```text
We are in the exploration phase of a Cosmos SDK audit.

Context:
- merged.txt contains all in-scope .go and .proto files
- I am trying to understand the application architecture

Your role:
Act as a senior Cosmos SDK developer/architect.
Explain what the application does, not whether it is secure.

Tasks:
1) High-level architecture: What problem does this chain solve?
2) Module structure: List each custom module and its purpose
3) Keeper wiring: How do modules interact via keeper interfaces?
4) ABCI lifecycle: What happens in BeginBlock and EndBlock?
5) IBC integration: Which modules use IBC? What packet types?
6) Governance: What can governance change? What proposals are defined?
7) Key design decisions: What is non-obvious about this architecture?
8) Assumptions: What must hold true for this system to be correct?

Focus on "why" and "how", not "is it safe".
```

### Module Deep-Dive
```text
Re-grounding for module exploration:
Focus on x/<MODULE_NAME>.
From merged.txt, explain:
1) This module's keeper struct and its dependencies
2) All message handlers and their state transitions
3) BeginBlocker/EndBlocker logic for this module
4) Registered invariants
5) Parameter space and validation
6) IBC callbacks (if any)
7) How this module interacts with x/bank, x/staking, x/gov
```

---

## **4. WORKING CHAT PROMPTS**

### Universal Starter
```text
This is a WORKING chat for deep analysis of a surviving Cosmos hypothesis.

Input: A hypothesis from Main that was not discarded.

Goals:
- Understand real security impact
- Analyze cross-module interactions
- Calculate economic impact
- Build PoC test code

Cosmos-Specific Focus:
- Trust boundary violations
- Keeper permission misuse
- ABCI lifecycle timing (BeginBlock/EndBlock ordering)
- IBC packet handling edge cases
- Governance param manipulation scenarios
- Invariant breakage paths

Source of truth: merged.txt and project documentation.

Hypothesis:
[paste hypothesis]
```

### Economic Impact Analysis
```text
For the validated finding, calculate:

1. Funds at risk: What is the maximum extractable value?
2. Attack cost: What capital/gas/time does the attacker need?
3. Profitability: Is the attack profitable after costs?
4. Detection: How quickly would the attack be noticed?
5. Reversibility: Can governance or an upgrade fix the damage?
6. Systemic impact: Does this affect chain liveness?

Use concrete numbers based on:
- Current TVL estimates
- Gas costs for the transaction sequence
- Governance voting period (for defense timing)
- IBC timeout periods (for cross-chain extraction)
```

---

## **5. FINDING DRAFTING CHAT**

### Starting Prompt
```text
We are in finding drafting for a Cosmos SDK vulnerability.

Context:
- The vulnerability has been validated in a Working Chat
- Use the Cosmos-SDK Finding Template from methodology Section 9

Rules:
- Include root cause category (from Section 3)
- Include governance/consensus defense analysis
- Include economic impact calculation
- Include PoC as a Go test function
- Do NOT exaggerate — state facts with code evidence

Template includes required sections:
- Root Cause (with Cosmos category classification)
- Exploit Narrative (with transaction sequence)
- On-Chain Consequences (impact matrix)
- Why Consensus/Governance Does Not Prevent It
- Recommended Fix
- Severity Justification
```

---

## **6. SCAN CHAT PROMPTS**

### SCAN: Non-Determinism
```text
Scan for non-determinism in all production code paths.

Focus:
- Map iteration (range over map[])
- System time (time.Now() instead of ctx.BlockTime())
- Floating point arithmetic
- Goroutines and select statements
- Platform-dependent integer sizes
- math/rand without deterministic seeding
- unsafe, reflect, runtime packages

For each finding: location, type, and whether it's in a consensus-critical path.
```

### SCAN: ABCI Safety
```text
Scan BeginBlocker and EndBlocker for all modules.

Focus:
- Unbounded iterations (Iterator without limits)
- Panic-prone SDK constructors (sdk.NewCoins, MustNewDecFromStr, MustUnmarshal)
- Division by zero possibilities
- Slice index out of bounds
- Error paths that could leave state inconsistent

For each finding: module, method, line, and chain halt risk level.
```

### SCAN: Keeper Permissions
```text
Scan all keeper interfaces and their implementations.

Focus:
- Over-permissioned interfaces (MintCoins, BurnCoins exposed unnecessarily)
- Missing authorization checks in keeper methods
- Store key exposure outside the module
- Hook callbacks that could panic

For each finding: module, interface, method, and risk.
```

### SCAN: IBC Safety
```text
Scan all IBC-related code.

Focus:
- OnRecvPacket: is packet data fully validated?
- OnAcknowledgement: are errors handled? Is state cleaned up?
- OnTimeout: is the reversal operation correct?
- Channel ordering: does the module enforce the correct order?
- Capability claims: are ports/channels correctly capability-gated?
- Denomination tracking: are IBC denoms (ibc/HASH) handled correctly?

For each finding: module, callback, issue, and IBC-specific impact.
```

### SCAN: Governance Safety
```text
Scan governance integration.

Focus:
- Parameter validation: do all ParamSetPairs have non-trivial validators?
- Proposal handlers: can they panic? Are they bounded?
- Authority checks: is governance authority correctly propagated?
- MsgExec bypass: can authz wrap governance-sensitive operations?
- Community pool: are spend proposals validated?

For each finding: module, parameter/proposal, and governance risk.
```

---

## **7. SCOPE TRANSFER PROMPT**

```text
You are continuing a Cosmos-SDK security audit.

## PROTOCOL CONTEXT
- Project: [name]
- Cosmos SDK: [version]
- CometBFT: [version]
- IBC-Go: [version]
- Custom Modules: [list]
- IBC Channels: [list of channel types/ordering]

## ARCHITECTURE STATE
- Module dependency graph: [summary]
- BeginBlock/EndBlock: [what each module does]
- IBC integration: [summary]
- Governance surface: [changeable parameters]

## AUDIT STATE
- Hypotheses generated: [H1..Hn summary]
- Hypotheses validated: [Valid/Invalid/Inconclusive]
- Findings confirmed: [summary]
- Current task: [what to do next]

## DOCUMENTS IN PLAY
1. `CommandInstruction-Cosmos.md` — System prompt
2. `Cosmos-SDK-Security-Audit-Methodology.md` — Methodology
3. `Audit_Assistant_Playbook_Cosmos.md` — This playbook
4. `merged.txt` — Full source code

Continue from current state. Do NOT repeat completed analysis.
```

---

## APPENDIX: QUICK REFERENCE

### Cosmos Vulnerability Classes
| # | Class | Impact | Signal |
|---|-------|--------|--------|
| 1 | State Desync | Fund theft, invariant break | Custom balance tracking parallel to x/bank |
| 2 | Keeper Permissions | Unauthorized actions | MintCoins/BurnCoins in interface |
| 3 | Module Isolation | Cross-module corruption | Hook panics, shared store keys |
| 4 | Governance Hooks | Chain takeover | Unbounded params, unsafe proposals |
| 5 | Slashing/Rewards | Economic security erosion | Reward rounding, slashing evasion |
| 6 | Gas/DoS | Chain halt | Unbounded iterators, no pagination |
| 7 | Consensus Errors | Chain fork | Maps, floats, time.Now(), goroutines |
| 8 | IBC Attacks | Cross-chain theft | Unvalidated packets, proof bypass |

### Trail of Bits Patterns (C1-C6)
| ID | Name | Severity | Signal |
|----|------|----------|--------|
| C1 | Incorrect GetSigners | CRITICAL | GetSigners()[0] != msg.Sender |
| C2 | Non-Determinism | CRITICAL | Map iteration, time.Now(), floats |
| C3 | Message Priority | HIGH | No custom CheckTx priority |
| C4 | Slow ABCI | CRITICAL | Iterator(nil, nil) in EndBlocker |
| C5 | ABCI Panic | CRITICAL | sdk.NewCoins in BeginBlocker |
| C6 | Broken Bookkeeping | HIGH | Custom balance != bank balance |

### Severity Matrix
| Severity | Criteria |
|----------|----------|
| CRITICAL | Chain halt, unbounded fund loss, consensus failure |
| HIGH | Bounded fund loss, privilege escalation, state corruption |
| MEDIUM | Temporary DoS, governance manipulation, yield theft |
| LOW | Gas inefficiency, missing events, minor rounding |

---

**Framework Version:** 1.0
**Last Updated:** February 2026
**Target Ecosystems:** Cosmos SDK, CometBFT, IBC, Interchain Security
