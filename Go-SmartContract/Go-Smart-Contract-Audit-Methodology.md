# Comprehensive Go Smart Contract Audit Methodology

> **Integration Note:** This file contains the Go-specific audit methodology.
> For LLM conversation structure, see `Audit_Assistant_Playbook_Go.md`.
> For the system prompt, see `CommandInstruction-Go.md`.
> For Solidity methodology, see `../InfoSec/audit-workflow1.md` and `audit-workflow2.md`.
> For Rust methodology, see `../RustBaseSmartContract/Rust-Smartcontract-workflow.md`.

---

## **Phase 1: Go-Specific Entry Point Identification**

### **Step 1.0: Time-Boxing Strategy (For Large Codebases)**
Prevent analysis paralysis with structured time allocation:

```markdown
**Round 1 (40% of time): Quick Triage ALL Entry Points**
- 5 minutes max per handler function
- Build execution spine, note red flags, move on
- Goal: Map the attack surface

**Round 2 (40% of time): Deep Dive TOP 5 Priority Functions**
- Full checklist, pointer analysis, gas simulation
- Document findings as you go
- Goal: Find critical vulnerabilities

**Round 3 (20% of time): Cross-Function & Error Paths**
- Interaction bugs between modules/keepers
- Error path testing, panic analysis
- Goal: Catch composition bugs and state corruption
```

**Time Tracking Template:**
```markdown
| Phase | Allocated | Actual | Functions Covered |
|-------|-----------|--------|-------------------|
| Triage | 4 hours | _ | HandleMsg*, BeginBlock, EndBlock... |
| Deep Dive | 4 hours | _ | transfer, withdraw, liquidate... |
| Cross-Function | 2 hours | _ | keeper interactions, error paths |
```

---

### **Step 1.1: Identify Go-Specific Audit Roots**
Look for functions that satisfy **≥2** of these Go-specific criteria:

- [ ] Public method on a `Keeper` or `Handler` struct
- [ ] Takes `sdk.Context` as first parameter (Cosmos SDK)
- [ ] Accepts a message/request struct (`Msg*`, `Request*`)
- [ ] Returns `(*sdk.Result, error)` or similar tuple
- [ ] Mutates KV store or module state
- [ ] Calls ≥2 internal methods
- [ ] Handles user authentication (`msg.GetSigners()`)
- [ ] Contains `BeginBlock`/`EndBlock` logic

**Commands to generate list:**
```bash
# Cosmos SDK: Find message handlers
grep -rn "func (k Keeper)" --include="*.go" | grep -E "(Msg|Handle)"

# Find functions that take sdk.Context
grep -rn "sdk.Context" --include="*.go" | grep "func.*("

# Find message types (proto-generated)
find . -name "*.pb.go" -exec grep -l "Msg.*struct" {} \;

# Find module entry points (BeginBlock, EndBlock)
grep -rn "BeginBlock\|EndBlock" --include="*.go" | grep "func"

# Find keeper methods that mutate state
grep -rn "func (k Keeper).*Set\|func (k Keeper).*Save\|func (k Keeper).*Delete" --include="*.go"

# Find error handling patterns
grep -rn "_, _ :=\|_ =" --include="*.go" | grep -v "_test.go"

# Find panic calls in production code
grep -rn "panic(" --include="*.go" | grep -v "_test.go"

# Find IBC callback handlers
grep -rn "OnRecvPacket\|OnAcknowledgementPacket\|OnTimeoutPacket" --include="*.go"
```

### **Step 1.2: Protocol-Specific Context**
```go
// Quick mental model for any Go blockchain project
type ProtocolContext struct {
    Framework      string  // "Cosmos SDK", "Tendermint ABCI", "Custom"
    StateStore     string  // "IAVL", "MemDB", "RocksDB", "LevelDB"
    MessageFlow    string  // "CheckTx -> DeliverTx", "Direct handler"
    ErrorHandling  string  // "panic/recover", "return error", "ABCI codes"
    Concurrency    string  // "Single-threaded", "Goroutines", "Async"
    GasModel       string  // "Metered", "Block gas", "Fixed"
}
```

### **Step 1.3: Prioritization Matrix (Go Edition)**
```markdown
## Priority 1 (Attack Immediately)
- [ ] Functions that move funds (Transfer, Send, Withdraw)
- [ ] Functions with admin powers (UpdateParams, Upgrade)
- [ ] Message handlers with external calls (IBC, cross-module)
- [ ] Functions that mint/burn tokens
- [ ] BeginBlock/EndBlock logic (affects all users)

## Priority 2 (Attack After)
- [ ] Query handlers that could leak sensitive data
- [ ] Internal keeper methods called by handlers
- [ ] Functions with time dependencies (ctx.BlockTime())
- [ ] Functions using pointer receivers with mutations

## Priority 3 (Check Later)
- [ ] Gas optimization opportunities
- [ ] Event emission issues
- [ ] Code style / go vet warnings
```

### **Step 1.4: Mandatory Validation Checks**
_Per methodology — ALL must pass before reporting a finding_

| Check | Question | Go-Specific Considerations |
|-------|----------|----------------------------|
| **Reachability** | Can this path execute on-chain? | Is handler registered? Is message routed? |
| **State Freshness** | Works with current state? | Are we testing with realistic KV store state? |
| **Execution Closure** | All external calls modeled? | IBC callbacks, cross-module calls, hooks |
| **Economic Realism** | Cost/timing feasible? | Gas costs, block time constraints, capital requirements |

---

## **Phase 2: Build Execution Spine with Go Patterns**

### **Step 2.1: Go-Specific Call Graph Extraction**
Go functions follow patterns that help with analysis:

```go
// Typical Cosmos SDK pattern
func (k Keeper) HandleMsgUpdatePosition(
    ctx sdk.Context,           // Context always first
    msg *types.MsgUpdatePosition, // Message second
) (*sdk.Result, error) {      // Returns (result, error)
    // Pattern 1: Early validation
    if err := msg.ValidateBasic(); err != nil {
        return nil, err
    }
    
    // Pattern 2: Load state with error handling
    pos, err := k.loadPosition(ctx, msg.Sender)
    if err != nil {
        return nil, err
    }
    
    // Pattern 3: Chain of operations with early returns
    if err := k.settlePosition(ctx, &pos); err != nil {
        return nil, sdkerrors.Wrap(err, "settle")
    }
    
    // Pattern 4: Final commit
    k.savePosition(ctx, msg.Sender, pos)
    
    // Pattern 5: Event emission
    ctx.EventManager().EmitEvent(sdk.NewEvent(...))
    
    return &sdk.Result{Events: ctx.EventManager().Events()}, nil
}
```

### **Step 2.2: Format Spine with Go Error Handling**
```text
HandleMsgUpdatePosition(ctx, msg)
├── [VALIDATION] msg.ValidateBasic() → error?
├── [SNAPSHOT] loadPosition(ctx, sender) → (Position, error)
├── [ACCOUNTING] settlePosition(ctx, &pos) → error
├── [MUTATION] applyUpdate(ctx, msg, &pos) → error
├── [COMMIT] savePosition(ctx, sender, pos)
└── [EVENTS] ctx.EventManager().EmitEvent(...)

Error Flow:
├── ValidateBasic fails → early return
├── loadPosition fails → early return
├── settlePosition fails → wrapped error return
├── applyUpdate fails → wrapped error return
└── savePosition panics? → caught by SDK
```

### **Step 2.3: Identify Go-Specific Control Flow**
```text
FUNCTION()
├── if err != nil { return nil, err } → Early error returns
├── defer cleanup() → Post-function cleanup
├── panic/recover → Unexpected error handling
├── goroutine go func() → Concurrency (rare in blockchains)
├── select/channels → Async patterns
├── for range loops → Iteration patterns
└── switch msg := msg.(type) → Type switching
```

---

## **Phase 3: Go-Specific Semantic Classification**

### **Classification Table with Go Patterns**
| Intent Tag | Go Indicators | Questions to Ask |
|------------|--------------|------------------|
| **VALIDATION** | `ValidateBasic()`, `Validate()`, `msg.Validate()`, early `if` checks, signature verification | • Are all message fields validated?<br>• Are signatures checked?<br>• Is gas checked early? |
| **SNAPSHOT** | `k.Get*()`, `store.Get()`, `Load*()`, `GetState()`, KV reads, cache lookups | • Is state fresh (not cached from old block)?<br>• Are nil returns handled?<br>• Are zero values dangerous? |
| **ACCOUNTING** | `ctx.BlockHeight()`, `ctx.BlockTime()`, oracle queries, interest calculations, fee computation | • Can time be manipulated?<br>• Are oracle responses validated?<br>• Are there rounding issues? |
| **MUTATION** | `store.Set()`, `k.Set*()`, pointer modification (`&pos.Field = value`), arithmetic operations | • Are pointers modified safely?<br>• Is arithmetic checked?<br>• Are invariants maintained? |
| **COMMIT** | `store.Set()`, `store.SetRaw()`, `Save*()`, `keeper.Set*()`, batch writes | • Are writes atomic?<br>• Is storage gas accounted for?<br>• Are all fields saved? |
| **EVENTS** | `ctx.EventManager().EmitEvent()`, `EmitTypedEvent()`, attribute building | • Are all state changes logged?<br>• Are events emitted before/after writes?<br>• Are attributes correct? |
| **ERROR** | `return nil, err`, `sdkerrors.Wrap()`, `panic()`, ABCI error codes, `types.Err*` | • Do errors leave state corrupted?<br>• Are errors informative?<br>• Are panics possible? |

### **Go-Specific Classification Rules**
```yaml
go_classification:
  validation:
    patterns:
      - "ValidateBasic"
      - "Validate()"
      - "verify"
      - "check"
      - "if.*!= nil"
    position: "early in function"
    
  snapshot:
    patterns:
      - "Get"
      - "Load"
      - "Query"
      - "store.Get"
      - "k.Get"
    returns: "(value, error) or value"
    
  accounting:
    patterns:
      - "BlockTime"
      - "BlockHeight"
      - "ctx.*Time"
      - "oracle"
      - "fee"
    dependencies: "context or external"
    
  mutation:
    patterns:
      - "Set"
      - "Update"
      - "Modify"
      - "store.Set"
      - "&field ="
    side_effects: "state change"
    
  commit:
    patterns:
      - "Save"
      - "Set"
      - "store.Set"
      - "Write"
    after_validation: true
    
  events:
    patterns:
      - "EmitEvent"
      - "EmitTypedEvent"
      - "EventManager"
    after_changes: true
```

---

## **Phase 4: Semantic Order Audit (Go Edition)**

### **Pass 1: Validation Phase - All VALIDATION functions**
```markdown
### Go-Specific Checklist - Validation Phase
- [ ] **Message Validation**: Are all message fields validated?
- [ ] **Signature Verification**: Are signatures checked properly?
- [ ] **Gas Checking**: Is gas checked early?
- [ ] **Permission Checks**: Are sender permissions verified?
- [ ] **State Preconditions**: Does validation check current state?

### Questions:
1. Can validation be bypassed via malformed messages?
2. Are signature verification gas costs accounted for?
3. Does validation happen before any state changes?
4. Are there any panics in validation code?
```

### **Pass 2: Snapshot Phase - All SNAPSHOT functions**
```markdown
### Go-Specific Checklist - Snapshot Phase
- [ ] **Zero Value Handling**: Are nil/zero returns handled safely?
- [ ] **State Freshness**: Is state read from current block?
- [ ] **Cache Safety**: Are caches properly invalidated?
- [ ] **Deserialization**: Is protobuf unmarshaling safe?
- [ ] **Gas Metering**: Are reads gas-metered correctly?

### Questions:
1. What happens when `store.Get()` returns nil?
2. Are zero structs (like `Position{}`) valid states?
3. Could stale cached state be used?
4. Are protobuf unmarshal errors handled?
```

### **Pass 3: Accounting Phase - All ACCOUNTING functions**
```markdown
### Go-Specific Checklist - Accounting Phase
- [ ] **Time Safety**: Can `ctx.BlockTime()` be manipulated?
- [ ] **Oracle Safety**: Are oracle responses validated?
- [ ] **Arithmetic Safety**: Using `sdk.Int`, `sdk.Dec` safely?
- [ ] **Rounding**: Are decimal calculations exact?
- [ ] **Fee Accuracy**: Are fees calculated correctly?

### Questions:
1. What if block time jumps forward/backward?
2. Are there any unchecked integer operations?
3. Can accounting be triggered multiple times in same block?
4. Are there any rounding errors that accumulate?
```

### **Pass 4: Mutation Phase - All MUTATION functions**
```markdown
### Go-Specific Checklist - Mutation Phase
- [ ] **Pointer Safety**: Are pointers modified safely?
- [ ] **Value Conservation**: Is total value preserved?
- [ ] **Invariant Preservation**: Are all invariants maintained?
- [ ] **Gas Limits**: Are mutations gas-bounded?
- [ ] **Atomicity**: Are multi-field updates atomic?

### Questions:
1. Can pointer modification race with other operations?
2. Are there any unchecked arithmetic (add/sub/mul/div)?
3. Does mutation respect all protocol invariants?
4. Are there any infinite loops or unbounded operations?
```

### **Pass 5: Commit Phase - All COMMIT functions**
```markdown
### Go-Specific Checklist - Commit Phase
- [ ] **Write Atomicity**: Are writes atomic where needed?
- [ ] **Gas Accounting**: Is storage gas accounted for?
- [ ] **Batch Writes**: Could writes be batched for efficiency?
- [ ] **State Consistency**: Are all related fields written?
- [ ] **Serialization**: Is protobuf marshaling safe?

### Questions:
1. Could a partial write leave state inconsistent?
2. Are writes gas-metered correctly?
3. Is protobuf marshaling failure handled?
4. Are there any storage size limits?
```

### **Pass 6: Events Phase - All EVENT emissions**
```markdown
### Go-Specific Checklist - Events Phase
- [ ] **Event Completeness**: Are all state changes logged?
- [ ] **Event Ordering**: Are events emitted after state changes?
- [ ] **Attribute Safety**: Are event attributes correct/safe?
- [ ] **Gas Costs**: Are event emissions gas-accounted?
- [ ] **Indexing**: Do events support efficient indexing?

### Questions:
1. Could an event be emitted for a failed operation?
2. Do events contain any sensitive information?
3. Are event attributes correctly formatted?
4. Are there too many events causing gas issues?
```

### **Pass 7: Error Handling Phase - All ERROR paths**
```markdown
### Go-Specific Checklist - Error Handling
- [ ] **Error Propagation**: Are errors propagated correctly?
- [ ] **State Rollback**: Is state rolled back on error?
- [ ] **Panic Safety**: Are there any potential panics?
- [ ] **Error Messages**: Are errors informative but safe?
- [ ] **ABCI Codes**: Are appropriate ABCI codes used?

### Questions:
1. Do errors leave temporary state modifications?
2. Are there any `panic()` calls in production code?
3. Do errors leak internal state or secrets?
4. Are ABCI error codes used correctly?
```

---

## **Phase 5: State Mutation Tracking with Go Semantics**

### **Go-Specific State Mutation Table**
```markdown
| Variable | Type | Validation | Snapshot | Accounting | Mutation | Commit | Events |
|----------|------|------------|----------|------------|----------|--------|--------|
| Position | struct | msg.ValidateBasic() | store.Get() | settlePosition() | applyUpdate() | store.Set() | EmitEvent() |
| Balance | sdk.Coin | check signatures | k.GetBalance() | accrueInterest() | transfer() | k.SetBalance() | balance update |
| Config | Config | admin check | k.GetConfig() | - | updateConfig() | k.SetConfig() | config change |

Error Handling:
| Variable | Modified on Error? | Rollback? | Cleanup? |
|----------|-------------------|-----------|----------|
| Position | Yes (pointer) | ❌ | ❌ |
| Balance | No | ✅ | ✅ |
| Config | Yes (if panic) | ⚠️ | ⚠️ |
```

### **Go-Specific Pointer Mutation Analysis**
Track pointer modifications vs value copies:

```go
// Dangerous pattern: Modifying pointer before error check
func (k Keeper) process(pos *types.Position) error {
    pos.Collateral = pos.Collateral.Add(amount)  // Mutation happens
    if pos.Collateral.LT(minCollateral) {
        return types.ErrInsufficient  // Too late! Already mutated
    }
    return nil
}

// Safer pattern: Validate before mutation
func (k Keeper) process(pos *types.Position) error {
    newCollateral := pos.Collateral.Add(amount)
    if newCollateral.LT(minCollateral) {
        return types.ErrInsufficient  // No mutation yet
    }
    pos.Collateral = newCollateral  // Mutation after validation
    return nil
}
```

### **Gas Tracking for Go Operations**
```go
// Gas costs to track in Go blockchain code
type GasCosts struct {
    KVRead     uint64  // store.Get()
    KVWrite    uint64  // store.Set()
    CPU        uint64  // Complex computations
    Memory     uint64  // Allocations, slices, maps
    Crypto     uint64  // Signature verification
    Serialize  uint64  // protobuf marshal/unmarshal
}

// Look for unbounded operations
func auditGas(fn *Function) []string {
    var issues []string
    
    // Unbounded loops
    if strings.Contains(fn.Body, "for range collection") {
        issues = append(issues, "Unbounded loop - gas DoS risk")
    }
    
    // Large allocations
    if strings.Contains(fn.Body, "make([]byte, ") {
        issues = append(issues, "Large allocation - memory gas risk")
    }
    
    // Multiple KV operations
    if strings.Contains(fn.Body, "store.Set(") {
        count := strings.Count(fn.Body, "store.Set(")
        if count > 10 {
            issues = append(issues, "Many KV writes - high gas cost")
        }
    }
    
    return issues
}
```

---

## **Phase 6: Go-Specific Attack Simulation**

### **Step 6.1: Go-Specific Attack Vectors**
```markdown
## Memory & Concurrency Attacks
- [ ] **Pointer Aliasing**: Multiple references to same struct
- [ ] **Slice/Map Modification**: Unexpected side effects
- [ ] **Goroutine Leaks**: If async operations exist
- [ ] **Race Conditions**: In tests or if concurrent

## Blockchain-Specific Attacks
- [ ] **Frontrunning**: Transaction ordering
- [ ] **MEV Extraction**: Sandwich attacks in DEX
- [ ] **Gas Griefing**: High gas operations
- [ ] **Storage Bloat**: Filling state with junk

## Go-Specific Vulnerabilities
- [ ] **Zero Value Exploits**: Default struct values
- [ ] **Pointer vs Value**: Unexpected modifications
- [ ] **Error Handling Gaps**: Ignored errors
- [ ] **Panic Recovery**: Unhandled panics
- [ ] **Interface Casting**: Type assertion failures
```

### **Step 6.1b: Known Go/Cosmos Exploit Pattern Matching**
Before inventing new attacks, check if the code resembles past exploits:

```markdown
## Historical Exploit Database - Go Smart Contracts

**Cosmos SDK / IBC Exploits:**
- [ ] **Dragonberry (2022)**: ICS-23 proof verification bypass
- [ ] **Jackfruit (2022)**: Height offset in IBC client
- [ ] **Huckleberry (2022)**: Vesting account mishandling
- [ ] **Elderflower (2022)**: Bank module prefix bypass
- [ ] **Barberry (2022)**: ICS-20 token memo validation

**Cosmos DeFi Exploits:**
- [ ] **Osmosis (2022)**: LP share calculation rounding
- [ ] **Umee (2023)**: Collateral factor manipulation
- [ ] **Stride (2022)**: Liquid staking reward miscalculation
- [ ] **Mars Protocol (2023)**: Liquidation threshold bypass
- [ ] **Crescent (2022)**: AMM price manipulation via flash loan

**Tendermint/CometBFT:**
- [ ] **Evidence flooding**: Duplicate vote spam DoS
- [ ] **Light client attacks**: Header verification bypass
- [ ] **Consensus halting**: Block proposal manipulation

**General Go/Memory Exploits:**
- [ ] **Pointer aliasing**: Shared state corruption
- [ ] **Zero value attacks**: Uninitialized struct exploitation
- [ ] **Panic in handler**: Chain halt via unrecovered panic
- [ ] **Integer overflow**: sdk.Int/sdk.Dec edge cases
- [ ] **Slice/map races**: Concurrent modification

**Cross-Module Attacks:**
- [ ] **Bank→Staking**: Token movement during unbonding
- [ ] **Gov→Upgrade**: Malicious proposal execution
- [ ] **IBC→Bank**: Cross-chain token inflation
- [ ] **Auth→Bank**: Fee bypass via account type confusion

**ClaudeSkills Enhanced Patterns (CRITICAL):**
- [ ] **Incorrect GetSigners()** (CRITICAL): Signer impersonation via position mismatch
- [ ] **Non-Determinism** (CRITICAL - CHAIN HALT): Map iteration, goroutines, floats, time.Now()
- [ ] **Messages Priority** (HIGH): Oracle/emergency front-running
- [ ] **Slow ABCI Methods** (CRITICAL - CHAIN HALT): Unbounded loops in BeginBlocker/EndBlocker
- [ ] **ABCI Methods Panic** (CRITICAL - CHAIN HALT): sdk.NewCoins(), sdk.NewDec() panics
- [ ] **Broken Bookkeeping** (HIGH): Custom accounting vs x/bank desync
```

**Mental Check:** "Have I seen this exact pattern get exploited before?"

### **Step 6.1c: Framework-Specific Attack Vectors**
Based on the target framework:

**Cosmos SDK:**
- [ ] Bank module denomination attacks
- [ ] IBC packet manipulation/replay
- [ ] Governance proposal injection
- [ ] Upgrade handler bypass
- [ ] Module account hijacking

**Tendermint/CometBFT:**
- [ ] Validator set manipulation
- [ ] Evidence submission timing
- [ ] Block timestamp manipulation
- [ ] Light client header forgery

**Custom ABCI Apps:**
- [ ] CheckTx vs DeliverTx divergence
- [ ] Commit phase state leakage
- [ ] Query handler information disclosure
- [ ] BeginBlock/EndBlock race conditions

---

### **Step 6.2: Go-Specific Edge Case Testing**
For EACH function, test with:

```go
// Edge cases for Go smart contracts
testCases := []struct{
    name string
    test func()
}{
    {
        name: "Zero values",
        test: func() {
            // Test with zero/empty values
            msg := types.MsgUpdatePosition{}
            pos := types.Position{}
        },
    },
    {
        name: "Max values",
        test: func() {
            // Test with max ints, large strings
            msg := types.MsgUpdatePosition{
                Amount: sdk.NewIntFromUint64(math.MaxUint64),
            }
        },
    },
    {
        name: "Nil pointers",
        test: func() {
            // Test with nil message, nil fields
            var msg *types.MsgUpdatePosition
        },
    },
    {
        name: "Malformed data",
        test: func() {
            // Test with invalid protobuf, wrong types
            data := []byte("not a protobuf")
        },
    },
    {
        name: "Repeated calls",
        test: func() {
            // Same operation multiple times in block
            for i := 0; i < 100; i++ {
                k.HandleMsgUpdatePosition(ctx, msg)
            }
        },
    },
}
```

### **Step 6.3: Error Path Testing for Go**
```markdown
## Test Every Error Path in Go
1. **Early Returns**: What happens after `if err != nil { return ... }`?
2. **Panic Recovery**: Are there `recover()` calls? What do they do?
3. **ABCI Errors**: Do functions return correct ABCI error codes?
4. **Wrapped Errors**: Are errors properly wrapped with context?
5. **Nil Returns**: What happens when functions return nil values?

## State Corruption Scenarios
- Error after pointer modification
- Panic during multi-step operation
- Out-of-gas during execution
- Invalid signature in middle of processing
```

### **Step 6.4: Gas Analysis for Go Smart Contracts**
```go
// Common gas issues in Go blockchain code
var gasIssues = []string{
    "Unbounded slices (append in loops)",
    "Large map allocations",
    "String concatenation in loops",
    "Multiple KV store reads/writes",
    "Complex protobuf unmarshaling",
    "Crypto operations (signature verification)",
    "Iterating over large collections",
    "Recursive function calls",
}

// Check for gas-intensive patterns
func checkGasPatterns(code string) []string {
    var issues []string
    
    // Look for patterns
    patterns := map[string]string{
        "for.*range.*append": "Appending in loop - O(n²) memory",
        "strings.Join.*loop": "String building in loop - inefficient",
        "store.Get().*store.Get()": "Multiple KV reads - batch if possible",
        "crypto.VerifySignature": "Expensive crypto operation",
    }
    
    for pattern, message := range patterns {
        if matched, _ := regexp.MatchString(pattern, code); matched {
            issues = append(issues, message)
        }
    }
    
    return issues
}
```

---

## **Phase 7: Finding Documentation (Go Edition)**

### **Step 7.1: Go-Specific Finding Template**
```markdown
## [HIGH/MEDIUM/LOW] Go-Specific Issue

### Description
[What is the bug? Include Go-specific context like pointer issues, zero values, etc.]

### Location
- **File**: `x/module/keeper/msg_server.go`
- **Function**: `HandleMsgUpdatePosition`
- **Lines**: L123-L145
- **Go Pattern**: [Pointer modification/Zero value/Error handling]

### Go-Specific Details
- **Memory Safety**: [Pointer vs value, slice/map safety]
- **Error Handling**: [Panic/Error return/ABCI code]
- **Gas Impact**: [High/Medium/Low gas consumption]
- **Concurrency**: [Single-threaded/Potential race]

### Proof of Concept
```go
func TestExploit(t *testing.T) {
    // Setup
    k, ctx := setupKeeper(t)
    msg := types.MsgUpdatePosition{
        Sender:    attacker,
        Protect:   true,  // Bypasses validation
        Collateral: sdk.NewInt(1),  // Minimal addition
    }
    
    // Attack
    _, err := k.HandleMsgUpdatePosition(ctx, &msg)
    require.NoError(t, err)
    
    // Verification
    pos := k.loadPosition(ctx, attacker)
    assert.True(t, pos.Collateral.LT(minCollateral),
        "Position should be undercollateralized but wasn't liquidated")
}
```

### Go-Specific Fix
```go
// Before (vulnerable)
func (k Keeper) applyUpdate(ctx sdk.Context, msg *types.Msg, pos *types.Position) error {
    if !msg.Protect {  // Conditional validation
        if pos.Collateral.LT(types.MinMargin) {
            return types.ErrUndercollateralized
        }
    }
    // Mutation happens regardless
    pos.Collateral = pos.Collateral.Add(msg.Collateral)
    return nil
}

// After (fixed)
func (k Keeper) applyUpdate(ctx sdk.Context, msg *types.Msg, pos *types.Position) error {
    // Always validate margin
    newCollateral := pos.Collateral.Add(msg.Collateral)
    if newCollateral.LT(types.MinMargin) {
        return types.ErrUndercollateralized
    }
    // Only mutate after validation
    pos.Collateral = newCollateral
    return nil
}
```

### Related Go Concepts
- [Go Error Handling](https://go.dev/blog/error-handling-and-go)
- [Go Memory Model](https://go.dev/ref/mem)
- [Cosmos SDK Gas](https://docs.cosmos.network/main/basics/gas-fees.html)
```

### **Step 7.2: Severity Classification for Go**
```markdown
## CRITICAL (High in Go Context)
- Pointer modification before error check
- Panic in production code paths
- Zero-value structs treated as valid
- Missing signature verification
- Unchecked arithmetic leading to overflow

## HIGH (Medium in Go Context)
- Conditional validation that can be bypassed
- Errors leaving state partially modified
- Gas denial of service via unbounded ops
- Missing event emission for state changes

## MEDIUM (Low in Go Context)
- Inefficient gas usage (multiple KV ops)
- Poor error messages (not security issue)
- Missing validation of optional fields
- Code style issues

## LOW (Info in Go Context)
- Unused variables/functions
- Documentation improvements
- Test coverage gaps
- Deprecated API usage
```
---

### **Step 9.2: Go-Specific Checklist Per Function**
```go
// Mental checklist for each Go handler function
func auditHandler(fn *goast.FuncDecl) []string {
    var findings []string
    
    // 1. Signature checks
    if !hasContextParam(fn) {
        findings = append(findings, "Missing sdk.Context parameter")
    }
    
    if !returnsError(fn) {
        findings = append(findings, "Function doesn't return error")
    }
    
    // 2. Error handling
    if hasUncheckedError(fn) {
        findings = append(findings, "Unchecked error return")
    }
    
    if hasPanic(fn) {
        findings = append(findings, "Panic in handler - unsafe")
    }
    
    // 3. Pointer safety
    if modifiesPointerBeforeValidation(fn) {
        findings = append(findings, "Pointer modification before validation")
    }
    
    // 4. Gas considerations
    if hasUnboundedLoop(fn) {
        findings = append(findings, "Unbounded loop - gas DoS risk")
    }
    
    // 5. Zero value handling
    if treatsZeroAsValid(fn) {
        findings = append(findings, "Zero value treated as valid - may be uninitialized")
    }
    
    return findings
}
```

---

## **Universal Red Flags (Go Edition)**

```go
// RED FLAG 1: Pointer modification before validation
func (k Keeper) process(pos *types.Position) error {
    pos.Amount = pos.Amount.Add(delta)  // Mutation happens first!
    if pos.Amount.IsNegative() {
        return ErrNegative  // Too late - already corrupted
    }
}
// FIX: Validate before mutation, or use value copy

// RED FLAG 2: Zero value treated as valid state
func (k Keeper) getPosition(ctx sdk.Context, addr string) types.Position {
    pos := k.store.Get(addr)
    if pos == nil {
        return types.Position{}  // Zero value - is this safe?
    }
}
// FIX: Return (Position, bool) or (Position, error)

// RED FLAG 3: Unchecked error return
result, _ := k.doSomething(ctx)  // Error ignored!
// FIX: Always check errors: result, err := ...; if err != nil { return err }

// RED FLAG 4: Panic in handler
func (k Keeper) HandleMsg(ctx sdk.Context, msg *types.Msg) (*sdk.Result, error) {
    data := k.mustGet(ctx, msg.ID)  // panic if not found!
}
// FIX: Return error instead of panic in production code

// RED FLAG 5: Unbounded iteration
func (k Keeper) processAll(ctx sdk.Context) error {
    iter := k.store.Iterator(nil, nil)  // Could be millions
    for ; iter.Valid(); iter.Next() {
        k.process(iter.Value())
    }
}
// FIX: Add pagination or limits

// RED FLAG 6: Missing access control
func (k Keeper) UpdateConfig(ctx sdk.Context, msg *types.MsgUpdateConfig) error {
    // No sender check!
    k.setConfig(ctx, msg.Config)
}
// FIX: if msg.Sender != k.admin { return ErrUnauthorized }

// RED FLAG 7: External call before state update
func (k Keeper) process(ctx sdk.Context, msg *types.Msg) error {
    k.bankKeeper.SendCoins(ctx, ...)  // External call first
    k.updateBalance(ctx, msg.Amount)  // State update after
}
// FIX: Update state BEFORE external calls (check-effects-interaction)

// RED FLAG 8: Slice modification in loop
func (k Keeper) cleanup(items []Item) {
    for i, item := range items {
        if item.Expired {
            items = append(items[:i], items[i+1:]...)  // Modifying while iterating!
        }
    }
}
// FIX: Build new slice or iterate backwards

// RED FLAG 9: Type assertion without check
func (k Keeper) process(msg sdk.Msg) {
    m := msg.(*types.MsgUpdate)  // Panic if wrong type!
}
// FIX: m, ok := msg.(*types.MsgUpdate); if !ok { return ErrInvalidType }

// RED FLAG 10: Integer overflow with sdk.Int
func calculate(a, b sdk.Int) sdk.Int {
    return a.Mul(b)  // Could overflow MaxInt256
}
// FIX: Check bounds or use sdk.Int.MulRaw with overflow detection
```

---

## **Common Bug Patterns Checklist (Go Edition)**

```markdown
## Always Check For:

### Memory & Pointers
- [ ] Pointer modification before error checks
- [ ] Zero-value structs treated as valid
- [ ] Slice/map modification during iteration
- [ ] Pointer aliasing (shared state)

### Error Handling
- [ ] Ignored error returns (`_, _ :=` or `_ =`)
- [ ] Panic in production code paths
- [ ] Errors not wrapped with context
- [ ] Missing error type checks

### State Management
- [ ] Partial state updates on error
- [ ] Missing rollback on failure
- [ ] Cross-keeper state inconsistency
- [ ] Cache invalidation issues

### Access Control
- [ ] Missing sender validation
- [ ] Admin functions callable by anyone
- [ ] Module account misuse
- [ ] IBC packet spoofing

### Arithmetic
- [ ] sdk.Int/sdk.Dec overflow
- [ ] Division by zero
- [ ] Rounding errors in financial calculations
- [ ] Integer truncation

### Gas & DoS
- [ ] Unbounded loops over store
- [ ] Large slice allocations
- [ ] Expensive crypto operations
- [ ] User-controlled iteration counts

### Serialization
- [ ] Protobuf unmarshal errors unhandled
- [ ] JSON marshal panic on invalid data
- [ ] Type mismatch in store reads
- [ ] Migration compatibility issues

### Events
- [ ] Events emitted before state changes
- [ ] Missing events for state mutations
- [ ] Sensitive data in event attributes
- [ ] Event spam DoS
```

---

## **Invariants Template (Go Edition)**

For ANY Go smart contract, these invariants MUST hold:

```go
// 1. No free money
assert(totalAssets.GTE(totalLiabilities))

// 2. No double spending
assert(userBalance.LTE(totalSupply))

// 3. Module account consistency
assert(moduleBalance == sumOfUserBalances)

// 4. Access controls work
assert(msg.GetSigners()[0] == expectedSigner)

// 5. Arithmetic safety
assert(!result.IsNegative())
assert(result.LTE(maxAllowed))

// 6. State consistency (multi-field)
assert(position.Collateral.GTE(position.Debt.Mul(minRatio)))

// 7. No stuck funds
assert(canWithdraw || hasValidReason)

// 8. Time monotonicity
assert(ctx.BlockTime().After(lastUpdate) || ctx.BlockTime().Equal(lastUpdate))
```

---

## **Severity Classification (Go Edition)**

```markdown
## HIGH (Critical)
- Direct loss of funds (theft, drain)
- Permanent fund lock
- Admin key compromise / privilege escalation
- Chain halt via panic in critical path
- IBC token inflation

## MEDIUM (Significant)
- Theft of yield/rewards
- Temporary DoS (>1 hour)
- Governance manipulation
- Partial fund lock
- State corruption requiring upgrade
- Gas griefing with significant impact

## LOW (Minor)
- Gas inefficiencies
- Missing events
- Non-critical panics (in optional paths)
- Minor rounding errors (<0.01%)
- Code style issues

## INFO (Suggestions)
- Code improvements
- Better documentation
- go vet / golangci-lint warnings
- Test coverage gaps
```

---

## **Enhanced One-Page Cheat Sheet for Go**

```text
┌─────────────────────────────────────────────────────────────────┐
│                  GO SMART CONTRACT AUDIT                         │
├─────────────────────────────────────────────────────────────────┤
│ 1. FIND ENTRY POINTS:                                           │
│    • Message handlers (func (k Keeper) HandleMsg* )             │
│    • ABCI methods (CheckTx, DeliverTx, BeginBlock, EndBlock)    │
│    • Functions with sdk.Context and message parameter           │
│                                                                 │
│ 2. BUILD EXECUTION SPINE:                                       │
│    • Track function calls in order                              │
│    • Include error flow (early returns)                         │
│    • Note pointer modifications vs value copies                 │
│                                                                 │
│ 3. AUDIT BY PHASE:                                              │
│    • VALIDATION: Message fields, signatures, gas                │
│    • SNAPSHOT: State loading, zero values, cache safety        │
│    • ACCOUNTING: Time, oracle, math safety                      │
│    • MUTATION: Pointer safety, invariants, gas bounds          │
│    • COMMIT: Persistence, atomicity, gas costs                  │
│    • EVENTS: Logging completeness, attribute safety             │
│    • ERRORS: Rollback, cleanup, panic safety                    │
│                                                                 │
│ 4. GO-SPECIFIC CHECKS:                                          │
│    • Pointer modification before error checks                   │
│    • Zero-value structs treated as valid                        │
│    • Unchecked errors (ignore err)                              │
│    • Panic in production code paths                             │
│    • Unbounded operations (loops, slices, maps)                 │
│                                                                 │
│ 5. ATTACK SIMULATION:                                           │
│    • Zero/max values for all inputs                             │
│    • Nil pointers and malformed data                            │
│    • Repeated calls in same block                               │
│    • Error path testing (what happens on failure?)              │
│    • Gas DoS via unbounded operations                           │
└─────────────────────────────────────────────────────────────────┘

KEY GO INSIGHTS:
• Pointer modification → State corruption risk
• Zero values → Uninitialized state risk  
• Error handling gaps → Inconsistent state
• Unbounded operations → Gas DoS
• Panic recovery → Protocol halt risk
```

---

## **Enhanced Detection Patterns (ClaudeSkills Integration)**

> These patterns are sourced from Trail of Bits' building-secure-contracts repository
> and provide specific, actionable code patterns for Cosmos SDK vulnerability detection.

### **Cosmos-Specific Detection Patterns**

#### Pattern C1: Incorrect GetSigners() ⚠️ CRITICAL
**Description**: Mismatch between `GetSigners()` first element and logical sender enables signer impersonation.

```go
// VULNERABLE: First signer != msg.Sender
func (msg MsgTransfer) GetSigners() []sdk.AccAddress {
    recipient := sdk.MustAccAddressFromBech32(msg.Recipient)
    return []sdk.AccAddress{recipient}  // WRONG! Recipient signs as if they're sender
}

// SECURE: First signer is the logical sender
func (msg MsgTransfer) GetSigners() []sdk.AccAddress {
    sender := sdk.MustAccAddressFromBech32(msg.Sender)
    return []sdk.AccAddress{sender}  // First signer must be msg.Sender
}
```
**Detection Command**: Compare `GetSigners()[0]` with message sender field in all Msg* types

#### Pattern C2: Non-Determinism ⚠️ CRITICAL - CHAIN HALT
**Description**: Non-deterministic operations cause validators to disagree, halting consensus.

```go
// VULNERABLE PATTERNS (cause chain halt):
for key := range map[string]int{}        // Map iteration order random!
go func() { doSomething() }               // Goroutines unpredictable
price := float64(amount)                  // Float precision varies
timestamp := time.Now()                   // Different on each validator
random := rand.Intn(100)                  // Non-deterministic
select { case <-ch1: case <-ch2: }        // Arbitrary selection

// SECURE ALTERNATIVES:
keys := make([]string, 0, len(m))
for k := range m { keys = append(keys, k) }
sort.Strings(keys)                        // Deterministic order
for _, k := range keys { ... }

price := sdk.NewDecFromInt(amount)        // Use sdk.Dec, not float
timestamp := ctx.BlockTime()              // Consensus time
random := DeterministicRandom(ctx.BlockHeader().Hash())  // Block-seeded
```
**Detection Commands**:
```bash
grep -r "range.*map\[" x/           # Map iteration
grep -r "go func" x/                 # Goroutines
grep -r "time.Now()" x/              # System time
grep -r "float64\|float32" x/        # Floating point
grep -r "rand\." x/                  # Random without seed
```

#### Pattern C3: Messages Priority ⚠️ HIGH
**Description**: Missing prioritization allows front-running of critical messages (oracle, emergency).

```go
// VULNERABLE: All messages same priority
func (app *App) CheckTx(req abci.RequestCheckTx) abci.ResponseCheckTx {
    return app.BaseApp.CheckTx(req)  // Oracle updates can be delayed!
}

// SECURE: Prioritize critical messages
func (app *App) CheckTx(req abci.RequestCheckTx) abci.ResponseCheckTx {
    tx, _ := app.txDecoder(req.Tx)
    for _, msg := range tx.GetMsgs() {
        switch msg.(type) {
        case *oracle.MsgUpdatePrice, *crisis.MsgPause:
            if isAuthorized(msg.GetSigners()[0]) {
                return abci.ResponseCheckTx{Priority: 1000000}
            }
        }
    }
    return app.BaseApp.CheckTx(req)
}
```

#### Pattern C4: Slow ABCI Methods ⚠️ CRITICAL - CHAIN HALT
**Description**: Unbounded loops in BeginBlocker/EndBlocker exceed block time, halting chain.

```go
// VULNERABLE: Iterates ALL users - could be millions!
func EndBlocker(ctx sdk.Context, k keeper.Keeper) {
    k.IterateAllUsers(ctx, func(user User) bool {
        k.DistributeReward(ctx, user)  // O(n) unbounded
        return false
    })
}

// SECURE: Process limited batch per block
func EndBlocker(ctx sdk.Context, k keeper.Keeper) {
    maxProcessed := 100
    count := 0
    k.IterateUnprocessedUsers(ctx, func(user User) bool {
        if count >= maxProcessed {
            return true  // Stop iteration
        }
        k.DistributeReward(ctx, user)
        k.MarkProcessed(ctx, user)
        count++
        return false
    })
    // Remaining users processed in subsequent blocks
}
```

#### Pattern C5: ABCI Methods Panic ⚠️ CRITICAL - CHAIN HALT
**Description**: Panic-prone SDK operations in BeginBlocker/EndBlocker halt the chain.

```go
// VULNERABLE: These SDK methods can panic!
func EndBlocker(ctx sdk.Context, k keeper.Keeper) {
    // Panics if amount negative or denom invalid:
    coins := sdk.NewCoins(sdk.NewCoin(userDenom, userAmount))
    
    // Panics if string is invalid:
    price := sdk.NewDec(priceString)
    
    // Panics on division by zero:
    ratio := amount.Quo(sdk.ZeroInt())
    
    // Panics if params invalid:
    k.paramSpace.SetParamSet(ctx, &params)
    
    // Panics on empty slice:
    top := validators[0]
}

// SECURE: Validate before panic-prone operations
func EndBlocker(ctx sdk.Context, k keeper.Keeper) {
    // Validate denom
    if err := sdk.ValidateDenom(userDenom); err != nil {
        ctx.Logger().Error("invalid denom", "err", err)
        return
    }
    
    // Validate amount
    if userAmount.IsNegative() {
        ctx.Logger().Error("negative amount")
        return
    }
    
    // Check for zero divisor
    if divisor.IsZero() {
        ctx.Logger().Error("division by zero")
        return
    }
    
    // Check slice bounds
    if len(validators) == 0 {
        return
    }
    top := validators[0]  // Safe now
}
```
**Detection Commands**:
```bash
grep -r "sdk.NewDec\|sdk.NewInt\|sdk.NewCoins" x/
grep -r "\.Quo\|\.Div" x/
grep -r "SetParamSet" x/
```

#### Pattern C6: Broken Bookkeeping ⚠️ HIGH
**Description**: Custom internal accounting becomes inconsistent with x/bank when tokens arrive via IBC/direct transfer.

```go
// VULNERABLE: Custom tracking separate from x/bank
type Keeper struct {
    userBalances map[string]sdk.Coins  // Internal tracking
}

func (k Keeper) Deposit(ctx sdk.Context, user string, amount sdk.Coins) {
    k.userBalances[user] = k.userBalances[user].Add(amount...)
    k.bankKeeper.SendCoins(ctx, sender, moduleAccount, amount)
}
// PROBLEM: IBC transfers bypass Deposit() → userBalances desyncs!

// SECURE: Use x/bank as single source of truth
func (k Keeper) GetUserBalance(ctx sdk.Context, user string) sdk.Coins {
    return k.bankKeeper.GetAllBalances(ctx, sdk.AccAddress(user))
}

// OR: Use SendEnabled blocklist to prevent direct transfers
```

---

## 📚 **Learning Resources for Go Auditing**

### **Essential Reading:**
1. **Effective Go** - Official Go style guide
2. **Cosmos SDK Documentation** - https://docs.cosmos.network/
3. **Go Security Pitfalls** - https://github.com/golang/go/wiki/CommonMistakes
4. **Go Proverbs** - https://go-proverbs.github.io/
5. **Trail of Bits Cosmos Patterns** - building-secure-contracts/not-so-smart-contracts/cosmos/

### **Practice Targets:**
1. **Cosmos SDK Tutorials** - https://tutorials.cosmos.network/
2. **Ignite CLI Scaffolding** - Create and audit scaffolded chains
3. **CosmWasm Go Examples** - https://github.com/CosmWasm/cosmwasm-go
4. **Tendermint ABCI Examples** - https://github.com/tendermint/tendermint/tree/master/abci/example

### **Tools to Master:**
1. **gosec** - Security scanner for Go
2. **govulncheck** - Vulnerability checker for dependencies
3. **golangci-lint** - Fast Go linters runner
4. **go test -race** - Race detector
5. **go mod graph** - Dependency graph visualization

---

## **Phase 8: Protocol-Specific Attack Patterns (Cosmos DeFi)**

### **8.1 DeFi Lending Protocols (Cosmos)**
```markdown
### Lending-Specific Attack Surface
- [ ] **Collateral Factor Manipulation**: Can governance be used to change factors and liquidate?
- [ ] **Oracle Staleness**: What happens if price feed stops? Are TWAP windows safe?
- [ ] **Liquidation Cascades**: Can rapid liquidations cause bad debt?
- [ ] **Interest Rate Model**: Can rates be manipulated via large deposits/withdrawals?
- [ ] **Cross-Module Reentrancy**: Can bank hooks or IBC callbacks re-enter lending logic?
- [ ] **Flash Loan Equivalent**: Can same-block borrow-exploit-repay work on Cosmos?

### Cosmos-Specific Lending Concerns
- Module account vs user account balance tracking
- IBC-denominated collateral (ibc/HASH tokens)
- BeginBlock interest accrual — off-by-one? Skipped block handling?
- Governance parameter changes — immediate vs delayed effect?
```

### **8.2 DEX / AMM Protocols (Cosmos)**
```markdown
### DEX-Specific Attack Surface
- [ ] **Price Manipulation**: Can a single large swap move the price enough to exploit other paths?
- [ ] **LP Share Calculation**: Rounding in mint/burn — extractable value?
- [ ] **Concentrated Liquidity**: Tick boundary behavior, position NFT manipulation?
- [ ] **Swap Fee Accuracy**: sdk.Dec rounding in fee calculations?
- [ ] **Pool Creation**: Can anyone create pools? Token pair validation?
- [ ] **TWAP Oracle**: Can the observation buffer be manipulated?

### Cosmos DEX Concerns
- Osmosis LP share rounding (historical exploit)
- IBC token denomination in pool creation
- BeginBlock/EndBlock pool operations (epoch-based)
- Concentrated liquidity tick math with sdk.Dec precision
```

### **8.3 Staking / Liquid Staking (Cosmos)**
```markdown
### Staking-Specific Attack Surface
- [ ] **Reward Dilution**: Can staking rewards be claimed by non-stakers?
- [ ] **Unbonding Period Bypass**: Can tokens be freed before unbonding completes?
- [ ] **Validator Selection Manipulation**: Can voting power be gamed?
- [ ] **Liquid Staking Token Peg**: Can the exchange rate be manipulated?
- [ ] **Slash Handling**: Does slashing correctly reduce liquid staking token value?
- [ ] **Reward Distribution**: EndBlocker distribution — gas bounded? Fair?

### Cosmos Staking Concerns
- x/staking delegation hooks — do custom modules handle them?
- Liquid staking redemption rate calculation (Stride pattern)
- Validator set updates in BeginBlock
- IBC liquid staking tokens — bridge trust assumptions?
```

### **8.4 Bridge / IBC Protocols (Cosmos)**
```markdown
### Bridge-Specific Attack Surface
- [ ] **Packet Validation**: Are received packets fully validated?
- [ ] **Acknowledgement Handling**: What happens on failed ack? Timeout?
- [ ] **Token Inflation**: Can tokens be minted without corresponding lock?
- [ ] **Channel Ordering**: ORDERED vs UNORDERED — implications for each?
- [ ] **Relayer Trust**: Can a malicious relayer affect protocol state?
- [ ] **Client Update Attacks**: ICS-23 proof verification (Dragonberry pattern)

### IBC-Specific Concerns
- Packet memo parsing (Barberry pattern)
- Height offset in client updates (Jackfruit pattern)
- Token denomination tracking across hops (ibc/HASH)
- Channel capability claims in InitChannel/TryChannel
```

### **8.5 Governance / DAO (Cosmos)**
```markdown
### Governance-Specific Attack Surface
- [ ] **Proposal Execution**: Can proposals bypass normal access control?
- [ ] **Voting Power Flash**: Can tokens be acquired, voted, then sold?
- [ ] **Parameter Changes**: Do param changes take effect immediately?
- [ ] **Upgrade Proposals**: Can upgrade proposals brick the chain?
- [ ] **Community Pool Drain**: Can proposals drain the community pool?
- [ ] **Governance Guard Bypass**: Can admin operations bypass governance?

### Cosmos Governance Concerns
- x/gov proposal handlers — custom proposal types safe?
- Param change proposals — validation of new values?
- Software upgrade proposals — module migration handlers?
- Governance threshold manipulation via delegation
```

---

## **Phase 9: Validation & Verification**

### **9.1 Go False Positive Elimination Checklist**
Before finalizing any finding, verify:

```markdown
### Common False Positives in Go/Cosmos Audits
- [ ] **"Ignored error" that is intentionally ignored**: Check if `_` is used where error cannot occur
- [ ] **"Missing access control" on query handler**: Queries are read-only — is access control needed?
- [ ] **"Panic in handler"**: Is it inside BeginBlock/EndBlock (critical) or a message handler (SDK recovers)?
- [ ] **"Unbounded iteration"**: Is iteration bounded by governance parameter or max supply?
- [ ] **"Pointer mutation"**: Does the SDK commit system roll back on error? (Yes for DeliverTx)
- [ ] **"Zero value dangerous"**: Does the code's ValidateBasic() prevent zero values from reaching this point?
- [ ] **"IBC vulnerability"**: Is the affected channel actually used? Is the relayer trusted?
- [ ] **"Cross-module call"**: Are both modules deployed? Is the keeper interface correctly wired?
```

### **9.2 Impact Assessment Template**
```markdown
| Factor | Assessment |
|--------|------------|
| **Funds at Risk** | $0 / $0-$10K / $10K-$1M / $1M+ |
| **Affected Users** | None / Few / All stakers / Entire chain |
| **Attack Cost** | Transaction fee / Moderate capital / Significant capital |
| **Detection** | Immediate / Within hours / After damage |
| **Reversibility** | Governance proposal / Chain halt + upgrade / Irreversible |
| **Likelihood** | Theoretical / Feasible with skill / Easy |
| **Chain Impact** | None / Degraded / Halted |
```

### **9.3 Submission Checklist**
```markdown
### Before Submitting Any Finding
- [ ] Root cause identified with exact code location (file:function:line)
- [ ] Affected semantic phase(s) identified
- [ ] All 4 validation checks passed (Reachability, State Freshness, Execution Closure, Economic Realism)
- [ ] Go-specific claims verified (pointers, errors, panics, zero values)
- [ ] PoC includes Go test code or transaction construction
- [ ] Impact quantified with realistic numbers
- [ ] Recommendation is actionable (not just "add a check")
- [ ] Severity justified by impact, not by code pattern
- [ ] Cross-referred with known patterns (C1–C6, historical exploits)
- [ ] Adversarial review completed (would a triager accept this?)
```

---

## **Final Pro Tips for Go Smart Contract Auditing**

1. **`go test -race`**: Always run the race detector on the full test suite — blockchain code shouldn't use goroutines in handlers, but if it does, find the races first.

2. **Read `go.mod` Before Code**: The SDK version tells you which known vulnerabilities are patched. Check cosmos/cosmos-sdk and ibc-go release notes.

3. **BeginBlock/EndBlock Are More Critical Than Handlers**: A bug in a handler affects one user's transaction. A bug in BeginBlock/EndBlock affects every block and can halt the chain.

4. **Pointer Receivers Are The Go Version of Reentrancy**: In Go, `func (k *Keeper)` means the keeper is shared state. Track every mutation path through pointer receivers.

5. **`sdk.Dec` Is Not Arbitrary Precision**: It has 18 decimal places. Operations that need more precision (e.g., accumulated interest over months) can lose value. Check `sdk.Dec` math carefully.

6. **The `x/bank` Module Is The Source of Truth**: Any custom balance tracking that doesn't use `x/bank` will desync when IBC transfers arrive. Always verify the canonical balance source.

7. **Module Accounts Are Special**: They can't be rekeyed, but their balances can be drained if the module logic is flawed. Check `MintCoins`, `BurnCoins`, `SendCoinsFromModuleToAccount` carefully.

8. **IBC Is A Trust Boundary**: Never assume IBC packets are well-formed. The counterparty chain could be malicious. Validate every field in `OnRecvPacket`.

9. **Protobuf Defaults Are Zero Values**: When a field is missing from a protobuf message, it defaults to zero/empty. This is a common source of uninitialized-state bugs in Cosmos.

10. **Check the Migration Handlers**: When auditing an upgrade, the migration handler in `RegisterMigration` is often where state corruption happens. Read every line.

---

## **Audit Completion Checklist**

### Coverage Verification
- [ ] All message handlers analyzed (MsgServer methods)
- [ ] All BeginBlock/EndBlock logic reviewed
- [ ] All keeper methods traced for state mutations
- [ ] All IBC callbacks reviewed (if applicable)
- [ ] Module parameter validation checked
- [ ] Genesis state initialization reviewed

### Go-Specific Verification
- [ ] All pointer receivers checked for mutation safety
- [ ] All error returns verified (no silent drops)
- [ ] All panic paths identified (BeginBlock/EndBlock critical)
- [ ] Zero value handling verified throughout
- [ ] Unbounded iterations identified and assessed
- [ ] Type assertions checked for safety

### Finding Quality
- [ ] Each finding passes all 4 validation checks
- [ ] Severities consistently applied
- [ ] PoCs are reproducible Go test cases
- [ ] Recommendations are specific and actionable
- [ ] No duplicate findings

### Deliverables
- [ ] All findings documented with standard template
- [ ] Scope coverage tracked with scope index
- [ ] Informational observations documented
- [ ] Final report formatted for client review

---