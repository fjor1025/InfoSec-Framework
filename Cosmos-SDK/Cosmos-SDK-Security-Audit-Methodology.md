# Cosmos-SDK Security Audit Methodology

> **Integration Note:** This file contains the Cosmos-SDK-specific security framework.
> For LLM conversation structure, see `Audit_Assistant_Playbook_Cosmos.md`.
> For the system prompt, see `CommandInstruction-Cosmos.md`.
> For Go-generic methodology, see `../Go-SmartContract/Go-Smart-Contract-Audit-Methodology.md`.
> For Rust/CosmWasm methodology, see `../RustBaseSmartContract/Rust-Smartcontract-workflow.md`.

---

## Section 1: Cosmos-SDK Architecture Security Model

### 1.1 Module System

Cosmos-SDK applications are composed of independent modules, each owning its own state, message types, and business logic. Security boundaries exist at the module interface layer.

**Attack Surface Points:**
- Module registration order in `app.go` determines initialization sequence; misordering can leave modules with uninitialized dependencies
- Custom modules that override or shadow built-in module routes (`x/bank`, `x/staking`, `x/gov`) can intercept or suppress standard behavior
- Module `AppModuleBasic` vs `AppModule` interface compliance — missing method implementations degrade to silently doing nothing
- `RegisterServices` must bind all `MsgServer` and `QueryServer` methods; unregistered handlers silently drop messages (C1 pattern from Trail of Bits: Gravity Bridge missing `CancelCall` handler)

**Key Invariant:** Every proto-defined RPC must have a registered handler. Every module must explicitly declare its store keys, and no two modules may share a store key.

### 1.2 Keepers & Store Access Patterns

Keepers are the gatekeepers to module state. The object-capability model restricts cross-module access to explicitly passed keeper interfaces.

**Security-Critical Patterns:**

| Pattern | Risk | Exploit |
|---------|------|---------|
| `storeKey` exposed outside module | Full state read/write by any module | Malicious module overwrites validator set |
| Keeper interface too broad | Module granted unnecessary capabilities | Module A calls `BurnCoins` via overly-permissive BankKeeper |
| Missing `BlockedAddr` check | Direct sends to module accounts bypass accounting | DoS via broken invariant (Desmos bug) |
| Keeper method uses pointer receiver on shared state | Cross-handler state corruption | Pointer aliasing between sequential messages in same block |

**Audit Rule:** For every keeper method, trace: (1) which store keys it reads/writes, (2) which external keepers it calls, (3) whether errors from external calls are checked and propagated.

### 1.3 Msg / Handler Flow

Transaction lifecycle through the SDK:

```
Raw bytes → TxDecoder → []sdk.Msg → ValidateBasic() per Msg
         → AnteHandler chain (auth, fee deduction, sig verify)
         → MsgServiceRouter → Module's MsgServer method
         → PostHandler (optional: tips)
         → State committed to deliverState if no error
```

**Attack Surface at Each Stage:**

1. **TxDecoder**: Malformed protobuf → panics in unmarshal (especially with `MustUnmarshal` patterns)
2. **ValidateBasic()**: Stateless validation only — cannot check on-chain state, so attackers pass validation with structurally valid but semantically invalid messages
3. **MsgServiceRouter**: Unregistered message types silently fail (Gravity Bridge pattern)
4. **MsgServer execution**: The core attack surface — state reads, writes, cross-module calls
5. **Multi-message transactions**: Cosmos allows multiple messages per transaction, all executed atomically. An attacker bundles setup + exploit + extraction in one transaction

### 1.4 AnteHandler Risks

AnteHandlers execute before message processing and are chained in sequence. Order matters.

**Vulnerability Classes:**

- **AnteHandler ordering**: Fee deduction before signature verification means invalid transactions still pay fees (design intent), but custom ante decorators inserted before `SigVerificationDecorator` cannot trust `msg.GetSigners()` because signatures have not been verified yet
- **Nested message bypass**: `x/authz` and `MsgExec` allow one user to execute messages on behalf of another. AnteHandlers that check `msg.GetSigners()` directly do not see the inner messages. A custom fee-exempt check on `MsgTypeURL` can be bypassed by wrapping the exempt message inside `MsgExec`
- **Gas manipulation in CheckTx vs DeliverTx**: `CheckTx` uses node-local `minGasPrices`; `DeliverTx` uses global `MinGasPrice`. Discrepancy allows spam that passes `CheckTx` but fails in `DeliverTx`, wasting validator resources
- **Sequence number caching**: AnteHandler increments account sequence in `checkState`. A successful `CheckTx` followed by a failed `DeliverTx` can desynchronize sequence tracking between mempool and execution state

**Audit Rule:** Map every custom `AnteDecorator` and verify: (1) it cannot panic, (2) it correctly handles multi-message transactions, (3) it does not trust auth-dependent data before `SigVerificationDecorator` runs.

### 1.5 BeginBlock / EndBlock Attack Surfaces

These ABCI methods execute outside the context of any user transaction. No gas is charged to any account.

**Critical Properties:**
- **Panics are fatal**: Unlike message handlers (where SDK catches panics via `defer/recover`), a panic in `BeginBlocker` or `EndBlocker` halts the chain permanently until a coordinated upgrade
- **Unbounded computation**: No gas meter limits these methods. An `O(n)` iteration over user state that grows unboundedly will eventually exceed block time limits, causing liveness failure
- **Non-determinism is fatal**: Any divergence between validators in these methods causes a consensus split (fork). Map iteration, floating point, `time.Now()`, goroutines, and platform-dependent integer sizes are all vectors

**Real-World Patterns:**
- Osmosis math library DoS (Trail of Bits): Specially crafted input to decimal math caused `O(2^n)` computation in `EndBlocker`
- THORChain halt: Map iteration order divergence in `EndBlocker` caused different validators to error at different indexes

**Audit Rule:** Every `BeginBlocker` and `EndBlocker` must be: (1) bounded in computation, (2) panic-safe (no `sdk.NewCoins()` with unvalidated input, no `sdk.MustNewDecFromStr()`), (3) fully deterministic.

---

## Section 2: Threat Model & Trust Assumptions

### 2.1 Actor Classification

| Actor | Trust Level | Capabilities | Attack Motivation |
|-------|------------|--------------|-------------------|
| **Validators** | Semi-trusted | Propose blocks, vote on consensus, see mempool, order transactions within blocks | MEV extraction, censorship, double-signing for profit |
| **Delegators** | Untrusted | Choose validators, submit governance votes proportional to stake, can redelegate | Governance capture, validator collusion via delegation concentration |
| **Governance participants** | Semi-trusted | Submit proposals, deposit, vote. Governance can change any on-chain parameter and execute arbitrary code via upgrade proposals | Parameter manipulation, treasury drain, upgrade-based backdoor |
| **Relayers** | Untrusted (liveness-only trust) | Submit IBC packets, client updates, connection/channel handshakes. Cannot forge proofs, but can delay, reorder, or selectively relay packets | Liveness attacks, selective censorship of IBC packets, front-running cross-chain arbitrage |
| **External users** | Adversarial | Submit transactions, craft malformed messages, exploit timing | Fund theft, DoS, state corruption |
| **Module developers** | Trusted (but error-prone) | Write module code, define keeper interfaces, register handlers | Introducing bugs, over-permissioned keeper interfaces |

### 2.2 Trust Boundaries

```
                    ┌─────────────────────────────┐
                    │   Consensus (CometBFT)       │
                    │   Trust: 2/3 honest validators│
                    └────────────┬────────────────┘
                                 │ ABCI
                    ┌────────────▼────────────────┐
                    │   Application (Cosmos SDK)    │
                    │   Trust: Module code correct  │
                    │   ┌────────┐ ┌────────┐      │
                    │   │Module A│ │Module B│      │
                    │   │Keeper A│ │Keeper B│      │
                    │   └───┬────┘ └────┬───┘      │
                    │       │  Interface │          │
                    │       └────────────┘          │
                    └────────────┬────────────────┘
                                 │ IBC
                    ┌────────────▼────────────────┐
                    │   Counterparty Chain          │
                    │   Trust: Light client + proofs│
                    └─────────────────────────────┘
```

**Trust Boundary Rules:**
1. **Consensus → Application**: Application trusts that >2/3 validators are honest. If this fails, the chain can produce arbitrary state (double-spend, censorship). Application code cannot defend against this.
2. **Module → Module**: Trust is mediated by keeper interfaces. A module MUST NOT trust another module's output beyond what the interface guarantees. The bank module's `SendCoins` can fail; the error MUST be checked.
3. **Application → IBC Counterparty**: Trust reduces to light client verification + proof checking. The counterparty chain's validator set could be Byzantine. Never trust IBC packet data without validation.
4. **Application → Relayer**: Zero trust for correctness (proofs protect against forgery). Trust only for liveness (relayer must eventually relay packets).

### 2.3 What Governance Can Do (And How It Can Be Weaponized)

Governance proposals with sufficient voting power can:
- Change any module parameter (including `MinDeposit`, `VotingPeriod`, `QuorumThreshold`)
- Execute software upgrades that replace all module logic
- Spend community pool funds to arbitrary addresses
- Register new IBC clients and connections
- (In some chains) Execute arbitrary SDK messages via `MsgExec` proposals

**Governance Attack Vectors:**
- **Flash governance**: Acquire voting power (via liquid staking tokens, market purchase, or bribery), vote, then sell. If voting period is short and quorum is low, governance capture is cheap.
- **Parameter poisoning**: Change `UnbondingTime` to 1 second → validators can immediately unbond and double-sign without economic penalty
- **Upgrade trojan**: Submit a benign-looking upgrade proposal whose migration handler contains a backdoor state mutation

---

## Section 3: Core Vulnerability Classes

### 3.1 State Desynchronization

**Description:** Internal accounting maintained by a custom module diverges from the canonical state in `x/bank` or other SDK modules.

**Why It Happens in Cosmos-SDK:**
- Cosmos allows direct token transfers via `x/bank`'s `MsgSend` to any address, including module accounts. If a module tracks deposits internally but does not intercept direct bank sends, the module's bookkeeping diverges.
- IBC transfers via `x/ibc-transfer` burn tokens on the source chain and mint on the destination. If a module tracks token supply internally, IBC transfers create phantom supply changes.

**Realistic Exploit Scenario:**
A lending protocol tracks `totalDeposited` via custom state. An attacker sends tokens directly to the module account via `MsgSend`, inflating the module's actual balance above `totalDeposited`. If an invariant checks `moduleBalance == totalDeposited`, this triggers a chain halt. If the module computes exchange rates using `moduleBalance / totalShares`, the attacker manipulates the exchange rate.

**Impact:**
- Economic: Exchange rate manipulation → profit extraction
- Systemic: Invariant violation → chain halt (DoS for all users)

**Real-World Instance:** Umee TOB-UMEE-21 — token:uToken exchange rate manipulation via direct transfer and IBC supply reduction.

**Audit Heuristic:** For every module that maintains custom balance tracking: (1) Can tokens arrive via `MsgSend`? Use `BlockedAddr` to prevent. (2) Can tokens leave via IBC? Check if `x/ibc-transfer` burns affect the module's accounting. (3) Is the module account on the bank module's blocklist?

---

### 3.2 Incorrect Keeper Permissions

**Description:** Keeper interfaces expose more capabilities than a module needs, or keeper methods lack access control verification.

**Why It Happens in Cosmos-SDK:**
- The object-capability model depends on developers correctly restricting keeper interfaces. If module A's `BankKeeper` interface includes `MintCoins`, module A can mint tokens even if it has no business reason to do so.
- Keeper methods that perform administrative actions (param changes, account creation) often rely on the caller to verify authority. If the caller doesn't verify, the action is unprotected.

**Realistic Exploit Scenario:**
A custom module exposes a `MsgUpdateConfig` handler that calls `k.SetConfig()` without checking `msg.GetSigners()[0] == k.authority`. Any user can change module parameters.

**Impact:**
- Economic: Parameter manipulation → drain funds via favorable rates
- Systemic: If the parameter controls consensus-relevant behavior, manipulation causes chain divergence

**Audit Heuristic:** For every keeper interface: (1) List all methods. (2) For each method, determine if the consuming module actually needs it. (3) For every state-mutating keeper method, verify the caller checks authorization. (4) Search for `MintCoins`, `BurnCoins`, `SendCoinsFromModuleToAccount` in keeper interfaces — these must be strictly needed.

---

### 3.3 Improper Module Isolation

**Description:** Modules share state or side-effect through unintended channels, breaking the object-capability boundary.

**Why It Happens in Cosmos-SDK:**
- Store key leakage: If one module accidentally uses another's store key, it can read/write arbitrary state in the other module
- Hook callbacks: Modules register hooks (e.g., staking hooks) that execute in the context of another module's transaction. If the hook panics or modifies unexpected state, the calling module's transaction is corrupted.
- Shared protobuf types: Two modules using the same protobuf message type can accidentally unmarshal state from the wrong module's store

**Realistic Exploit Scenario:**
Module A registers a staking hook that panics when a specific delegation amount is processed. An attacker delegates exactly that amount, causing `EndBlocker` to panic and halt the chain.

**Impact:**
- Systemic: Chain halt from hook panics
- Economic: State corruption if hooks modify unrelated module state

**Audit Heuristic:** (1) Trace all hook registrations and verify they cannot panic. (2) Verify store keys are unique per module. (3) Check that `InitGenesis` order matches dependency graph.

---

### 3.4 Unsafe Governance Hooks

**Description:** Custom governance proposal handlers execute with elevated privileges and insufficient input validation.

**Why It Happens in Cosmos-SDK:**
- `x/gov` proposal handlers execute after a proposal passes. The handler receives deserialized proposal content and executes it with the governance module's authority.
- Parameter change proposals (`ParamChangeProposal`) modify module parameters directly. If the parameter space lacks validation, any value is accepted — including values that break invariants.
- Software upgrade proposals trigger `RunMigrations` which can execute arbitrary state mutations.

**Realistic Exploit Scenario:**
A parameter change proposal sets `MaxValidators` to 1, immediately reducing the active validator set. Combined with front-running of the governance execution, the proposer's validator is the sole remaining validator, achieving full control.

**Impact:**
- Economic: Treasury drain via `CommunityPoolSpendProposal`
- Systemic: Chain takeover via validator set manipulation, upgrade backdoors

**Audit Heuristic:** (1) For every `ParamChangeProposal`-eligible parameter, verify validation bounds exist. (2) For custom proposal types, verify the handler cannot brick the chain. (3) Check if `MsgExec`-style wrappers bypass governance-specific authorization checks.

---

### 3.5 Slashing / Reward Manipulation

**Description:** Validators or delegators exploit reward distribution or slashing mechanics to extract value or avoid penalties.

**Why It Happens in Cosmos-SDK:**
- Reward distribution in `x/distribution` uses a withdrawal pattern that calculates accumulated rewards since last withdrawal. If the calculation has rounding errors or can be triggered by an unauthorized party, rewards are misallocated.
- Slashing in `x/slashing` uses signed blocks windows and downtime tracking. If the window parameters are set incorrectly, validators can evade slashing by strategically missing blocks.
- `x/evidence` handles double-signing evidence. If evidence submission has no expiry or the age check is wrong, expired evidence can slash validators unfairly (or current evidence can be suppressed).

**Realistic Exploit Scenario:**
A validator observes they will be slashed for downtime. They immediately redelegate their self-delegation to another validator before the slashing executes. If the redelegate message is processed before `BeginBlocker` applies the slash, the validator evades the penalty.

**Impact:**
- Economic: Reward theft, slashing evasion → undermines economic security model
- Systemic: If slashing can be evaded cheaply, the cost of attacking consensus drops below MEV profit

**Audit Heuristic:** (1) Verify reward calculation handles zero-share-state correctly (no division by zero). (2) Check ordering of BeginBlocker operations — does slashing happen before or after redelegation processing? (3) Verify evidence has correct age bounds and cannot be submitted multiple times.

---

### 3.6 Gas & DoS Vectors

**Description:** Attackers exploit gas metering gaps or unbounded computation to halt the chain or degrade performance.

**Why It Happens in Cosmos-SDK:**
- `BeginBlocker`/`EndBlocker` have no per-user gas metering. Unbounded iterations in these methods scale with state size.
- Store iterators over unbounded keyspaces (`Iterator(nil, nil)`) scan the entire state.
- Protobuf deserialization gas is often underpriced — large messages consume more CPU than their gas cost reflects.
- Multi-message transactions can bundle many state-mutating operations, amplifying gas-to-computation ratio.

**Realistic Exploit Scenario:**
A spammer creates millions of small delegations to a single validator. `EndBlocker`'s reward distribution iterates over all delegations. Eventually, a single block's `EndBlocker` exceeds the block time limit, halting the chain.

**Impact:**
- Systemic: Chain halt (all users affected, requires emergency upgrade)
- Economic: Degraded performance increases transaction costs for legitimate users

**Audit Heuristic:** (1) Every `Iterator` call must be bounded (pagination, max iterations, or bounded keyspace). (2) Every `BeginBlocker`/`EndBlocker` must have known computational complexity relative to state size. (3) Protobuf message size limits must be enforced in `ValidateBasic()`.

---

### 3.7 Consensus-Level Logic Errors

**Description:** Application logic produces non-deterministic execution across validators, causing consensus failure.

**Why It Happens in Cosmos-SDK:**
- Go maps have non-deterministic iteration order. Any code path that iterates a map where the order affects output (first error returned, first element selected, accumulated value) causes validators to diverge.
- Go's `int` type is platform-dependent (32-bit vs 64-bit). Arithmetic on large values overflows differently on different architectures.
- `time.Now()` returns local system time, which differs across validators. `ctx.BlockTime()` (consensus header time) must be used instead.
- Floating-point arithmetic lacks associativity — `(a+b)+c ≠ a+(b+c)` due to finite precision. Cross-compilers may reorder operations.
- Goroutines and `select` statements have non-deterministic scheduling.

**Realistic Exploit Scenario:**
A module uses `time.Now()` in authorization grant expiration check. Validator A's clock is ahead, so the grant is expired; Validator B's clock is behind, so the grant is valid. They produce different execution results and the chain forks.

**Impact:**
- Systemic: Chain halt or fork — the most severe category of Cosmos-SDK bug

**Real-World Instance:** Cosmos SDK Security Advisory Jackfruit — `x/authz` used `time.Now()` instead of `ctx.BlockTime()`.

**Audit Heuristic:** Automated detection:
```bash
grep -rn "range.*map\[" --include="*.go" | grep -v "_test.go"   # Map iteration
grep -rn "time\.Now()" --include="*.go" | grep -v "_test.go"     # Local time
grep -rn "float64\|float32" --include="*.go" | grep -v "_test.go" # Floats
grep -rn "go func\|go " --include="*.go" | grep -v "_test.go"    # Goroutines
grep -rn "math/rand" --include="*.go" | grep -v "_test.go"       # Non-deterministic rand
grep -rn "unsafe\|reflect\|runtime" --include="*.go" | grep -v "_test.go" # Unsafe packages
```

---

### 3.8 IBC-Specific Attack Classes

_See Section 4 for full IBC Security Deep Dive._

**Summary of IBC vulnerability root causes:**
- Proof verification bypass (Dragonberry — ics23 `ExistenceProof` could prove non-existent keys)
- Client height manipulation (Jackfruit — height offset allowed replaying old state)
- Packet memo injection (Barberry — crafted memo in ICS-20 transfers triggered unexpected behavior)
- Token denomination confusion (ibc/HASH tokens treated as native tokens)
- Channel ordering violations (UNORDERED channels allowing out-of-sequence processing)

---

## Section 4: IBC Security Deep Dive

### 4.1 Channel / Connection Lifecycle Risks

**Connection Handshake (OpenInit → OpenTry → OpenAck → OpenConfirm):**
- Each step requires proof verification against the counterparty's light client
- **Risk**: If client state is stale or compromised, the connection links to a malicious chain
- **Risk**: Connection version negotiation can be manipulated to force a less-secure protocol version
- **Audit Check**: Verify that `OnChanOpenInit` and `OnChanOpenTry` validate the counterparty's port ID, channel ordering, and version string

**Channel Lifecycle:**
- Channels are bound to ports via capabilities. Only the module that claimed the port capability can operate on the channel.
- **Risk**: If capability claims happen in wrong order during `InitGenesis`, a module can claim another module's port
- **Risk**: Channel closing does not automatically refund in-flight packets. Tokens locked in escrow on a closed channel may be permanently lost.

### 4.2 Packet Replay & Timeout Misuse

**Packet Commitments:**
- Sending chain commits a packet hash to state. Receiving chain verifies the commitment via light client proof.
- After acknowledgement or timeout, the commitment is deleted. This prevents replay.
- **Risk**: If the commitment deletion fails (error not checked in `OnAcknowledgementPacket`), the same packet can be relayed again, double-delivering tokens.

**Timeout Mechanics:**
- Packets have timeout height and timeout timestamp. If neither is reached on the counterparty, the packet can be reclaimed on the source chain.
- **Risk**: Setting timeout too short allows the sender to trigger timeout and reclaim tokens while the counterparty has already processed the packet (race condition is prevented by proof checking, but custom module logic might not handle this correctly)
- **Risk**: `OnTimeoutPacket` handler must correctly reverse the send operation. If it mints tokens instead of unlocking escrowed tokens, or unlocks the wrong amount, the supply inflates.

### 4.3 Ordering Guarantees

- **ORDERED channels**: Packets must be delivered in sequence. If packet N is lost, packets N+1, N+2, ... are blocked until timeout.
- **UNORDERED channels**: Packets can arrive in any order. Each packet is processed independently.
- **Risk with ORDERED**: A malicious relayer can stall an ordered channel by not relaying a single packet, causing a liveness failure for the module.
- **Risk with UNORDERED**: Module logic that assumes sequential processing (e.g., "ack for deposit must arrive before withdrawal request") breaks on unordered channels.
- **Audit Check**: Verify the module's channel ordering matches its semantic requirements. If the module needs guaranteed ordering, it must use ORDERED and handle stall recovery.

### 4.4 Relayer Trust Assumptions

Relayers are trusted ONLY for liveness. They cannot:
- Forge packets (proofs prevent this)
- Modify packet data (proofs prevent this)
- Create fake light client updates (proof verification prevents this)

Relayers CAN:
- Delay packet delivery (liveness attack)
- Selectively relay packets (censorship)
- Front-run observed packets (submit their own transactions first)
- Choose which channel to relay to (if multiple channels exist)
- Submit client updates with slightly stale headers (within unbonding period)

**Audit Check:** Verify the protocol functions correctly if: (1) all packets are delayed by the maximum timeout period, (2) packets arrive in worst-case order (most disadvantageous to the protocol), (3) the relayer front-runs every cross-chain operation.

### 4.5 Cross-Chain Invariant Violations

**Token Supply Invariants:**
- ICS-20 transfer: Source chain escrows tokens → relayer submits proof → destination chain mints vouchers
- On return: Destination chain burns vouchers → relayer submits proof → source chain unlocks escrowed tokens
- **Invariant**: Total supply = escrowed_on_source + minted_vouchers_on_destination
- **Violation Vector**: If `OnRecvPacket` mints without verifying the escrow proof correctly (Dragonberry-class), tokens are created from nothing

**State Consistency Invariants:**
- Cross-chain state updates (e.g., interchain accounts, interchain queries) assume the counterparty state read is fresh
- **Risk**: The light client header might be several blocks behind. If the queried state changed between the header and the current block, the application acts on stale data
- **Audit Check**: Determine the maximum staleness of cross-chain state and verify the protocol tolerates this delay

**Interchain Security Invariants:**
- Consumer chains share the provider chain's validator set via CCV (Cross-Chain Validation)
- Evidence of misbehavior on the consumer chain must be relayed to the provider for slashing
- **Risk**: If evidence relay is delayed beyond the unbonding period, the misbehaving validator unbonds on the provider and escapes slashing
- **Risk**: If the consumer chain halts, the CCV module's `EndBlocker` on the provider may not receive expected packets, potentially blocking provider chain operations

---

## Section 5: Governance & Upgrade Security

### 5.1 Parameter Change Attacks

**Mechanism:** `ParamChangeProposal` allows governance to modify any module's registered parameters. The new value is validated by `ParamSetPairs` validation functions.

**Attack Vectors:**

| Parameter | Dangerous Value | Consequence |
|-----------|----------------|-------------|
| `UnbondingTime` | 1 second | Validators unbond instantly → no slashing penalty → cost-of-attack drops to zero |
| `MaxValidators` | 1 | Single validator controls consensus → censorship + double-spend |
| `SlashFractionDoubleSign` | 0 | No penalty for equivocation → free double-signing |
| `MinDeposit` | 1uatom | Governance spam → proposal flooding |
| `VotingPeriod` | 1 block | Flash governance — no time for community review |
| `QuorumThreshold` | 0.01% | Tiny minority controls governance |
| Custom module params | Module-specific | E.g., setting oracle update frequency to 0 → division by zero in rate calculation |

**Audit Heuristic:** (1) For every `ParamSetPairs` registration, verify the validation function rejects dangerous values. (2) Verify that parameter changes take effect at a safe time (e.g., at next epoch, not mid-block). (3) Check for parameter dependencies — changing parameter A might break invariants that depend on parameter A's relationship with parameter B.

### 5.2 Malicious Upgrades

**Mechanism:** `MsgSoftwareUpgrade` schedules a chain halt at a future height, after which nodes must run new binary. The new binary includes `RegisterMigration` handlers that transform state.

**Attack Vectors:**
- **Migration handler backdoor**: The migration function runs once and has full store access. It can inject arbitrary state (create accounts with balances, change validator set, modify governance).
- **Version skipping**: If the upgrade plan name doesn't match the binary's expected upgrade name, the chain halts and cannot restart.
- **Downgrade attack**: If upgrade height is in the past relative to some node's state, that node cannot sync.

**Audit Heuristic:** (1) Read every `RegisterMigration` handler line-by-line. (2) Verify the migration handler has bounded computation. (3) Check that store version increments are correct and sequential.

### 5.3 Governance Capture

**Cost to capture governance:**
```
capture_cost = token_price × total_staked × quorum × (1 - abstain_rate) × threshold
```

**Attack Amplifiers:**
- Liquid staking tokens (stATOM, stkATOM) can be borrowed on DeFi, voted, and returned — reducing effective capture cost to the borrowing fee
- Low voter turnout means the quorum is the binding constraint, not the threshold
- Lenient redelegation rules allow concentrating voting power temporarily

**Audit Heuristic:** (1) Calculate the dollar cost to capture governance given current staking parameters. (2) Verify whether the protocol's treasury value exceeds this cost (if so, governance capture is profitable). (3) Check if the protocol uses a timelock or veto mechanism to provide emergency defense.

### 5.4 Emergency Halt Risks

**Mechanism:** Some chains implement `MsgHalt` or crisis module invariant checks that stop the chain if an invariant is broken.

**Attack Vectors:**
- Deliberately breaking an invariant to trigger a chain halt (DoS)
- The broken bookkeeping pattern (Section 3.1) — sending tokens directly to a module account breaks the balance invariant, triggering the crisis module
- Submitting `MsgVerifyInvariant` with a known-broken invariant to halt the chain

**Audit Heuristic:** (1) List all registered invariants. (2) For each invariant, determine if an external user can break it without the module's cooperation. (3) If yes, the invariant should log and continue, not halt.

---

## Section 6: Economic & Game-Theoretic Attacks

### 6.1 Validator Bribery

**Model:** An attacker pays validators off-chain to perform specific actions (censor transactions, include specific ordering, double-sign).

**Cosmos-Specific Factors:**
- Validators are identifiable (public keys, operator addresses) → bribery is targetable
- Delegators can be bribed to redelegate to a colluding validator → concentrates voting power
- CometBFT uses a weighted round-robin proposer selection → a bribed proposer controls block content for their slot

**Profitability Threshold:**
```
bribe_budget < MEV_extractable + stolen_funds - slashing_penalty
```

If `SlashFractionDoubleSign` is low and MEV is high, bribery is profitable.

### 6.2 Slashing Evasion

**Tactics:**
- **Redelegation race**: Redelegate to another validator before `BeginBlocker`'s `HandleValidatorSignature` applies the slash. The SDK's slashing module slashes the delegation at the infraction height, but the UX complexity means many implementations handle this incorrectly.
- **Self-delegation minimization**: Reduce self-delegation to near-zero. If slashed, the validator loses almost nothing. Delegators bear the cost.
- **Evidence suppression**: Prevent double-sign evidence from reaching the chain within the evidence age window.

**Audit Heuristic:** (1) Verify that slashing applies retroactively to redelegations in-flight at the infraction height. (2) Check minimum self-delegation enforcement. (3) Verify evidence age window is long enough (typically > unbonding period).

### 6.3 MEV & Front-Running in Cosmos

**Cosmos-Specific MEV Vectors:**
- **Block proposer advantage**: The proposer sees the mempool and can reorder transactions within the block. In CometBFT v0.38+, `PrepareProposal` and `ProcessProposal` give the proposer explicit control over block content.
- **Cross-chain MEV**: A relayer/validator on both chains can observe pending IBC packets and front-run the cross-chain operation (e.g., front-running a large DEX swap that arrives via IBC).
- **Batch auction bypass**: Cosmos chains that use batch auctions (e.g., Osmosis superfluid) can be gamed if the batch execution in `EndBlocker` processes positions in a predictable order.

**Audit Heuristic:** (1) Check if `PrepareProposal`/`ProcessProposal` are implemented and whether they constrain proposer behavior. (2) Identify all price-sensitive operations and check if they are front-runnable. (3) For DEX modules, check if swap execution order within a block is deterministic and exploitable.

### 6.4 Inflation Manipulation

**Mechanism:** Cosmos's `x/mint` module adjusts inflation rate based on the bonded ratio (`BondedRatio`). If `BondedRatio` < `GoalBonded`, inflation increases to incentivize staking.

**Attack Vectors:**
- **Rapid unstaking**: A whale rapidly unbonds, reducing `BondedRatio`, spiking inflation. The whale then re-bonds at the higher inflation rate, capturing disproportionate staking rewards.
- **IBC-mediated supply manipulation**: Transferring staked tokens to another chain (via liquid staking + IBC) reduces `BondedRatio` on the source chain without actually reducing the economic commitment.

**Audit Heuristic:** (1) Check if inflation parameters can be gamed by rapid stake/unstake cycles. (2) Verify `BondedRatio` calculation accounts for liquid-staked tokens. (3) Check if `EpochProvisions` or similar mechanisms smooth inflation changes to prevent spikes.

---

## Section 7: Audit Checklist (Practitioner-Grade)

### 7.1 Module-by-Module Review Steps

For **each custom module** in the chain under audit:

```markdown
### Module: x/<name>

#### 7.1.1 Message Handlers
- [ ] All proto-defined RPCs have registered handlers in `RegisterServices`
- [ ] Every `MsgServer` method checks authorization (`msg.GetSigners()[0]` against expected authority)
- [ ] `ValidateBasic()` rejects malformed messages (nil fields, negative amounts, invalid addresses)
- [ ] Multi-message transaction interactions tested (can two messages in one tx achieve what one cannot?)
- [ ] Error returns from all bank/staking/IBC keeper calls are checked
- [ ] No panics in message handling code paths (search: `panic(`, `Must`, `MustUnmarshal`)

#### 7.1.2 BeginBlocker / EndBlocker
- [ ] Computation is bounded (no `Iterator(nil, nil)`, no unbounded loops)
- [ ] No panic-prone SDK constructors (`sdk.NewCoins`, `sdk.MustNewDecFromStr`, `sdk.NewDec`)
- [ ] No non-deterministic operations (map iteration, `time.Now()`, goroutines, floats)
- [ ] No external dependencies (network calls, file I/O)
- [ ] Gas-equivalent cost analysis: could this method exceed block time?

#### 7.1.3 Genesis
- [ ] `InitGenesis` validates all genesis state (not just trusting import)
- [ ] `ExportGenesis` exports all state needed for reconstruction
- [ ] `InitGenesis` initialization order matches module dependency order in `app.go`
- [ ] Default genesis state is safe (doesn't create accounts with excessive balances)

#### 7.1.4 Queries
- [ ] Query handlers do not modify state (read-only)
- [ ] Queries do not expose sensitive information (private keys, pending transactions)
- [ ] Queries with pagination have sensible max page sizes
- [ ] Queries do not enable information-theoretic attacks (timing, existence proofs)

#### 7.1.5 Parameters
- [ ] All parameters have validation functions in `ParamSetPairs`
- [ ] Validation functions reject dangerous values (zero denominators, unbounded sizes)
- [ ] Parameter changes take effect safely (not mid-operation)
- [ ] Parameter interdependencies are documented and validated
```

### 7.2 Keeper Permission Audit

```markdown
### Keeper Interface Audit

For each external keeper dependency:

| Module | Required Interface | Methods Used | Justification |
|--------|-------------------|--------------|---------------|
| x/bank | `BankKeeper` | `SendCoins`, `GetBalance` | Transfer user deposits |
| x/staking | `StakingKeeper` | `GetValidator`, `Delegate` | Liquid staking operations |
| x/auth | `AccountKeeper` | `GetAccount`, `SetAccount` | Account existence check |

#### Verification:
- [ ] Interface includes ONLY methods the module actually calls
- [ ] No unused `MintCoins`, `BurnCoins`, or `SetBalance` in interface
- [ ] Keeper interface defined in module's `types/expected_keepers.go`
- [ ] Interface tested with mock keepers (not real bank keeper in tests)
```

### 7.3 Store Key Isolation Verification

```markdown
### Store Key Audit

- [ ] Each module has its own unique `StoreKey` in `app.go`
- [ ] No module references another module's `StoreKey` directly
- [ ] Store key names are distinct (no prefix collisions: e.g., "bank" vs "bank_reserve")
- [ ] `MemStoreKey` (transient store) is only used for per-block ephemeral data
- [ ] IAVL tree structure: no key encoding overlaps between modules
- [ ] Prefix store usage: verify prefix bytes are unique within each module's store

### Key Encoding Audit:
- [ ] Keys are deterministically encoded (no struct hashing, no map-dependent ordering)
- [ ] Variable-length key components are length-prefixed or delimited
- [ ] No key component can contain the delimiter character
- [ ] Key lengths have upper bounds (to prevent storage bloat attacks)
```

### 7.4 Invariant Review Checklist

```markdown
### Invariant Audit

For each registered invariant:

| Invariant | Module | Can External User Break It? | Severity If Broken |
|-----------|--------|----------------------------|-------------------|
| Supply invariant | x/bank | No (protected by module-level balance tracking) | Chain halt |
| Module balance = sum of deposits | x/custom | YES — direct MsgSend to module account | Chain halt |
| No negative balances | x/bank | No (checked in SendCoins) | Chain halt |

#### Verification:
- [ ] All invariants are registered in `RegisterInvariants`
- [ ] Invariants are tested in `_test.go` files
- [ ] Breaking conditions are enumerated and verified impossible via normal user actions
- [ ] Invariants that CAN be broken externally should log + continue, NOT halt
- [ ] The crisis module's `InvariantCheckPeriod` is reasonable (not every block on large chains)
```

### 7.5 Governance Hook Review

```markdown
### Governance Integration Audit

- [ ] All custom proposal types validate their content in `ValidateBasic()`
- [ ] Proposal handlers cannot panic
- [ ] Proposal handlers have bounded execution time
- [ ] Parameter change proposals validate new values against safety bounds
- [ ] Software upgrade proposals have correct plan names and heights
- [ ] `MsgExec` (authz) cannot be used to bypass governance-only restrictions
- [ ] Governance module's `authority` address is correctly set in all modules
- [ ] Community pool spend proposals validate recipient addresses
```

---

## Section 8: Exploit & PoC Design Guidance

### 8.1 Constructing Cosmos-SDK PoCs

**Test Framework Setup:**

```go
package keeper_test

import (
    "testing"
    "github.com/stretchr/testify/require"
    "github.com/cosmos/cosmos-sdk/testutil/testdata"
    sdk "github.com/cosmos/cosmos-sdk/types"
    // Import your module's keeper, types, and test helpers
)

// TestExploit_StateDesync demonstrates broken bookkeeping
func TestExploit_StateDesync(t *testing.T) {
    // 1. Setup: Use the module's test helpers to create a keeper with mocked dependencies
    app := simapp.Setup(t, false)
    ctx := app.BaseApp.NewContext(false, tmproto.Header{Height: 1})

    // 2. Pre-conditions: Establish baseline state
    attacker := sdk.AccAddress([]byte("attacker_addr_______"))
    moduleAcc := app.AccountKeeper.GetModuleAddress("custom_module")
    initialDeposit := sdk.NewCoins(sdk.NewCoin("uatom", sdk.NewInt(1000)))

    // Fund attacker
    app.BankKeeper.MintCoins(ctx, "mint", initialDeposit)
    app.BankKeeper.SendCoinsFromModuleToAccount(ctx, "mint", attacker, initialDeposit)

    // 3. Attack: Send tokens directly to module account (bypassing module's deposit logic)
    directSend := sdk.NewCoins(sdk.NewCoin("uatom", sdk.NewInt(100)))
    err := app.BankKeeper.SendCoins(ctx, attacker, moduleAcc, directSend)
    require.NoError(t, err)

    // 4. Verify impact: Module's internal tracking is now desynced
    moduleBalance := app.BankKeeper.GetAllBalances(ctx, moduleAcc)
    internalTracking := app.CustomKeeper.GetTotalDeposited(ctx)

    require.True(t, moduleBalance.AmountOf("uatom").GT(internalTracking),
        "Module balance (%s) > internal tracking (%s) — bookkeeping broken",
        moduleBalance, internalTracking)
}
```

### 8.2 Simulating Validator Behavior

```go
// TestExploit_ValidatorMEV demonstrates proposer-driven transaction ordering
func TestExploit_ValidatorMEV(t *testing.T) {
    app := simapp.Setup(t, false)

    // Simulate block proposal with controlled transaction ordering
    header := tmproto.Header{
        Height:          10,
        Time:            time.Now(),
        ProposerAddress: validatorAddr,
    }
    ctx := app.BaseApp.NewContext(false, header)

    // Create victim's pending swap transaction
    victimSwap := &dextypes.MsgSwap{
        Sender:   victimAddr,
        TokenIn:  sdk.NewCoin("uatom", sdk.NewInt(10000)),
        TokenOut: "uosmo",
    }

    // Proposer front-runs with their own swap
    attackerSwap := &dextypes.MsgSwap{
        Sender:   attackerAddr,
        TokenIn:  sdk.NewCoin("uatom", sdk.NewInt(100000)),
        TokenOut: "uosmo",
    }

    // Execute in order: attacker → victim → attacker_back
    // Simulate block execution
    app.BeginBlock(abci.RequestBeginBlock{Header: header})

    // Attacker's front-run
    _, err := app.DeliverTx(encodeTx(attackerSwap))
    require.NoError(t, err)

    // Victim's transaction (worse price due to front-run)
    _, err = app.DeliverTx(encodeTx(victimSwap))
    require.NoError(t, err)

    // Attacker's back-run (profit from price movement)
    _, err = app.DeliverTx(encodeTx(attackerBackSwap))
    require.NoError(t, err)

    app.EndBlock(abci.RequestEndBlock{Height: 10})
    app.Commit()

    // Verify: attacker profited, victim got worse price
}
```

### 8.3 Demonstrating Economic Impact

**Template for economic impact proof:**

```markdown
## Economic Impact Analysis

### Setup State:
- Module TVL: 10,000,000 uatom
- Exchange rate at start: 1.0 token per share
- Attacker's capital: 100,000 uatom

### Attack Sequence:
1. Attacker sends 100,000 uatom directly to module account (cost: 100,000 uatom + gas)
2. Exchange rate distorted: now (10,100,000 / 10,000,000) = 1.01 per share
3. Attacker had 50,000 shares. Redeems at new rate: 50,000 * 1.01 = 50,500 uatom
4. Net profit: 50,500 - 100,000 (direct send) = -49,500 (LOSS in this scenario)

### Break-Even Analysis:
- Attack is profitable when: attacker_shares * rate_increase > direct_send_amount
- Minimum shares needed: direct_send / rate_impact_per_token
- Profitability depends on: TVL ratio, share distribution, withdrawal delay

### Conclusion:
- [Profitable / Unprofitable / Conditional]
- If profitable, expected return per attack: [amount]
- Required capital: [amount]
- Risk of detection: [High/Medium/Low]
```

### 8.4 Proving Cross-Module Invariant Breakage

```go
// TestExploit_CrossModuleInvariantBreak demonstrates that a valid
// sequence of transactions violates a system-wide invariant
func TestExploit_CrossModuleInvariantBreak(t *testing.T) {
    app := simapp.Setup(t, false)
    ctx := app.BaseApp.NewContext(false, tmproto.Header{})

    // Record initial invariant state
    initTotalSupply := app.BankKeeper.GetSupply(ctx, "uatom")
    initModuleBalances := getAllModuleBalances(app, ctx)
    initUserBalances := getAllUserBalances(app, ctx)

    // Execute attack sequence
    executeAttackSequence(app, ctx)

    // Record final state
    finalTotalSupply := app.BankKeeper.GetSupply(ctx, "uatom")
    finalModuleBalances := getAllModuleBalances(app, ctx)
    finalUserBalances := getAllUserBalances(app, ctx)

    // Verify invariant violation
    // Invariant: totalSupply should not change (no mint/burn in attack)
    require.Equal(t, initTotalSupply, finalTotalSupply,
        "INVARIANT BROKEN: Total supply changed from %s to %s",
        initTotalSupply, finalTotalSupply)

    // Invariant: sum of all balances == totalSupply
    sumAll := sumBalances(finalModuleBalances, finalUserBalances)
    require.Equal(t, finalTotalSupply.Amount, sumAll,
        "INVARIANT BROKEN: Sum of all balances (%s) != total supply (%s)",
        sumAll, finalTotalSupply.Amount)
}
```

---

## Section 9: Finding Template (Triage-Proof)

### 9.1 Cosmos-SDK Vulnerability Report Template

```markdown
## [SEVERITY] [Root Cause] in [Module/Location] [enables/allows/causes] [Consequence]

### Root Cause

**Technical Root Cause:**
[One paragraph. What specific code behavior creates the vulnerability.
Include: file path, function name, line numbers.
Identify the semantic phase (VALIDATION/SNAPSHOT/ACCOUNTING/MUTATION/COMMIT/ERROR).]

**Cosmos-SDK Root Cause Category:**
- [ ] State Desynchronization (Section 3.1)
- [ ] Incorrect Keeper Permissions (Section 3.2)
- [ ] Improper Module Isolation (Section 3.3)
- [ ] Unsafe Governance Hook (Section 3.4)
- [ ] Slashing/Reward Manipulation (Section 3.5)
- [ ] Gas/DoS Vector (Section 3.6)
- [ ] Consensus Logic Error (Section 3.7)
- [ ] IBC Attack (Section 3.8)

**Historical Pattern Match:**
[Reference known Cosmos exploit if applicable: Dragonberry, Jackfruit, Huckleberry, etc.
Or Trail of Bits pattern: C1-C6.]

---

### Exploit Narrative

**Preconditions:**
1. [State condition that must exist]
2. [Actor privilege level required]
3. [External condition (e.g., IBC channel open, governance params)]

**Attack Steps:**
1. Attacker [action] by submitting [MsgType] with [parameters]
2. This causes [state change] in [module/keeper]
3. [Consequence of state change] leads to [impact]
4. Attacker extracts [value/advantage] by [final action]

**Transaction Sequence:**
```
Block N:   Tx1=[MsgType1{attacker, params}] → state effect
Block N:   Tx2=[MsgType2{attacker, params}] → exploit
Block N+1: BeginBlocker processes [effect] → damage realized
```

**PoC Code:**
```go
func TestExploit(t *testing.T) {
    // [Full reproducible test]
}
```

---

### On-Chain Consequences

| Dimension | Impact |
|-----------|--------|
| **Funds at Risk** | [Exact amount or formula based on TVL] |
| **Affected Users** | [Specific set: all delegators, LP providers, etc.] |
| **Chain Liveness** | [No impact / Degraded / Halted] |
| **State Integrity** | [No impact / Corrupted / Requires migration] |
| **Detection Latency** | [Immediate / Hours / Days] |
| **Reversibility** | [Self-healing / Governance fix / Requires hard fork] |

---

### Why Consensus / Governance Does Not Prevent It

**Consensus Defense:**
[Explain why the attack works within normal consensus rules.
E.g., "The attack requires only valid transactions signed by the attacker.
No validator collusion or > 1/3 Byzantine power is needed."]

**Governance Defense:**
[Explain why governance cannot prevent or mitigate in time.
E.g., "The attack executes in a single block. Governance proposals require
[VotingPeriod] to pass. By the time governance reacts, funds are already transferred
cross-chain via IBC."]

**Monitoring Defense:**
[Explain why standard monitoring may not catch this.
E.g., "The transactions appear as normal [MsgType] operations.
No failed transactions or unusual gas usage to alert operators."]

---

### Recommended Fix

```go
// Before (vulnerable)
[exact vulnerable code]

// After (fixed)
[exact fixed code with explanation of each change]
```

**Fix Verification:**
- [ ] The fix addresses the root cause, not a symptom
- [ ] The fix does not introduce new attack surfaces
- [ ] The fix handles edge cases (zero values, max values, error paths)
- [ ] The fix is deterministic (no new non-determinism)
- [ ] The fix maintains backward compatibility (or migration handler provided)

---

### Severity Justification

| Criterion | Assessment |
|-----------|------------|
| **Likelihood** | [High: any user can trigger / Medium: requires specific state / Low: requires unlikely conditions] |
| **Impact** | [Critical: chain halt or unbounded fund loss / High: bounded fund loss / Medium: limited loss or DoS / Low: informational] |
| **Complexity** | [Low: single transaction / Medium: multi-step / High: requires significant capital or coordination] |

**Final Severity:** [CRITICAL / HIGH / MEDIUM / LOW]
```

### 9.2 Severity Classification Matrix

| Severity | Criteria | Examples |
|----------|----------|---------|
| **CRITICAL** | Chain halt, unbounded fund loss, consensus failure, validator set takeover | Panic in BeginBlocker, non-determinism causing fork, IBC token inflation |
| **HIGH** | Bounded fund loss, privilege escalation, state corruption requiring upgrade | Broken bookkeeping exploited for profit, missing access control on admin functions |
| **MEDIUM** | Temporary DoS (>1hr), governance manipulation, yield theft, degraded security | Unbounded iteration causing slow blocks, reward calculation rounding exploitation |
| **LOW** | Gas inefficiency, missing events, minor rounding (<0.01%), cosmetic issues | Suboptimal gas usage, missing event attributes, parameter validation gaps |
| **INFORMATIONAL** | Best practices, code quality, defense-in-depth suggestions | Using `sdk.Dec` where `sdk.Int` suffices, missing test coverage, deprecation warnings |

---

## Appendix A: Cosmos-SDK-Specific Detection Commands

```bash
# === VULNERABILITY SCANNING ===

# C1: Incorrect GetSigners — find mismatches between signer and logical sender
grep -rn "GetSigners" --include="*.go" | grep -v "_test.go"
grep -rn "msg\.Sender\|msg\.Creator\|msg\.Authority" --include="*.go" | grep -v "_test.go"

# C2: Non-determinism — find all non-deterministic sources
grep -rn "range.*map\[" --include="*.go" | grep -v "_test.go"          # Map iteration
grep -rn "time\.Now()" --include="*.go" | grep -v "_test.go"            # System time
grep -rn "float64\|float32" --include="*.go" | grep -v "_test.go"       # Floats
grep -rn "go func\|go " --include="*.go" | grep -v "_test.go"           # Goroutines
grep -rn "math/rand" --include="*.go" | grep -v "_test.go"              # Non-deterministic rand
grep -rn "unsafe\.\|runtime\.\|reflect\." --include="*.go" | grep -v "_test.go"

# C3: Message priority — check for custom CheckTx
grep -rn "CheckTx\|PrepareProposal\|ProcessProposal" --include="*.go" | grep -v "_test.go"

# C4: Slow ABCI — find unbounded iterations in Begin/EndBlock
grep -rn "BeginBlocker\|EndBlocker\|BeginBlock\|EndBlock" --include="*.go" | grep -v "_test.go"
grep -rn "Iterator(nil\|Iterator(prefix" --include="*.go" | grep -v "_test.go"

# C5: ABCI panic — find panic-prone constructors
grep -rn "sdk\.NewCoins\|sdk\.MustNewDecFromStr\|sdk\.NewDec(" --include="*.go" | grep -v "_test.go"
grep -rn "panic(\|Must\|must" --include="*.go" | grep -v "_test.go"

# C6: Broken bookkeeping — find custom balance tracking
grep -rn "GetBalance\|GetAllBalances\|SpendableCoins" --include="*.go" | grep -v "_test.go"
grep -rn "MintCoins\|BurnCoins\|SendCoinsFromModule" --include="*.go" | grep -v "_test.go"

# === ACCESS CONTROL ===
grep -rn "GetSigners\|msg\.GetSigners" --include="*.go" | grep -v "_test.go"
grep -rn "authority\|admin\|owner" --include="*.go" | grep -v "_test.go"

# === ERROR HANDLING ===
grep -rn "_, _ :=\|_ =" --include="*.go" | grep -v "_test.go"          # Ignored errors
grep -rn "panic(" --include="*.go" | grep -v "_test.go"                  # Explicit panics

# === IBC ===
grep -rn "OnRecvPacket\|OnAcknowledgementPacket\|OnTimeoutPacket" --include="*.go"
grep -rn "OnChanOpenInit\|OnChanOpenTry\|OnChanOpenAck\|OnChanOpenConfirm" --include="*.go"

# === STATE MANAGEMENT ===
grep -rn "store\.Set\|store\.Get\|store\.Delete\|store\.Iterator" --include="*.go"
grep -rn "func (k \*Keeper)\|func (k Keeper)" --include="*.go"         # Pointer vs value keepers

# === GOVERNANCE ===
grep -rn "ParamSetPairs\|ParamChangeProposal\|RegisterMigration" --include="*.go"

# === CODEBASE METRICS ===
find . -name "*.go" ! -name "*_test.go" -exec wc -l {} + | tail -1     # Total SLOC
find . -name "*.go" ! -name "*_test.go" | wc -l                         # File count
```

## Appendix B: Cosmos-SDK Version-Specific Concerns

| SDK Version | Notable Security Features/Changes | Audit Focus |
|-------------|----------------------------------|-------------|
| v0.45.x | Legacy `Handler` pattern, `ParamChangeProposal` direct | Check msg handler registration completeness |
| v0.46.x | `MsgServiceRouter`, `x/group` module added | AutoCLI, authz interactions with new modules |
| v0.47.x | ABCI++ (`PrepareProposal`/`ProcessProposal`), `x/consensus` module | MEV-related proposer power, consensus param governance |
| v0.50.x | `x/accounts` module, depinject, `collections` package | New state management patterns, automatic codec |

## Appendix C: CometBFT / Tendermint Consensus Security Notes

**Proposer Selection:** Weighted round-robin based on voting power. A validator with N% voting power proposes ~N% of blocks. The proposer has exclusive control over transaction ordering within their block.

**Evidence Handling:** CometBFT tracks equivocation evidence (duplicate votes). Evidence must be submitted within the `MaxAgeNumBlocks` or `MaxAgeDuration` window. If evidence handling panics or has unbounded computation, it creates a DoS vector.

**Light Client Security:** Light clients verify headers using validator signatures. If >1/3 of validators are Byzantine, they can sign conflicting headers, creating a light client attack. The `x/evidence` module handles this on the application layer.

**Block Time Manipulation:** The proposer chooses the block timestamp (within BFT time bounds — must be after previous block's time and within the proposer's local clock). Applications using `ctx.BlockTime()` for time-sensitive operations should account for ±1 block of manipulation.

---

**Framework Version:** 1.0
**Last Updated:** February 2026
**Target Ecosystems:** Cosmos SDK, CometBFT, IBC, Interchain Security
**Complementary to:** Go Smart Contract Framework v2.0
