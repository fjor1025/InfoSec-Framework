# Smart Contract Audit Methodology - Semantic Phase Analysis

> **Version:** 2.1 — Enhanced with Semantic Guard Analysis and State Invariant Detection
> **Integration Note:** This file contains the semantic phase methodology (SNAPSHOT→COMMIT).
> For conversation structure, see `../Audit_Assistant_Playbook.md`.
> For the system prompt, see `CommandInstruction.md`.

---

## **Phase 1: Quick Triage & Entry Point Identification**

### **Step 1.1: Identify Audit Root Functions**
Use BOTH methods for comprehensive coverage:

```bash
function-summary | "(public|external)" | "view\|pure"

# Semantic phase criteria (≥2 of these)
# 1. external/public visibility
# 2. Mutates storage (non-view/pure)
# 3. Touches balances/positions/shares
# 4. Reads oracle or timestamp
# 5. Calls ≥2 internal functions
# 6. Handles user-provided parameters
```

### **Step 1.2: Build Mental Call Spine (5-Minute Version)**
For EACH high-priority function, quickly sketch:

```text
FUNCTION: transfer(address,uint256)
├── [READ] balanceOf[msg.sender] (implicit)
├── [CHECK] require(balance >= amount)
├── [CHECK] require(to != address(0))
├── [CHANGE] balanceOf[msg.sender] -= amount
├── [CHANGE] balanceOf[to] += amount
└── [EMIT] Transfer(msg.sender, to, amount)
```

### **Step 1.3: Prioritization with Semantic Weighting**
Score each function (1-3 points each):
- **+3**: Moves funds directly (transfer, withdraw)
- **+2**: Uses oracle/timestamp
- **+2**: Admin/privileged function
- **+1**: Calls multiple internal functions
- **+1**: User-provided parameters
- **+1**: Complex math/logic

**Start with highest scoring functions first**

---

## **Phase 2: Deep Dive with Semantic Phase Analysis**

### **Step 2.1: Build Detailed Call Spine**
Instead of jumping between functions, map ALL calls first:

#### **Step 2.1b: Inheritance & Modifier Spine (DO THIS FIRST)**
Before building the call spine, trace the execution context:

```text
CONTRACT INHERITANCE TREE:
Market.sol
├── inherits ReentrancyGuard
│   └── state: _status (uint256)
│   └── modifier: nonReentrant
├── inherits Pausable  
│   └── state: _paused (bool)
│   └── modifier: whenNotPaused
├── inherits Ownable
│   └── state: _owner (address)
│   └── modifier: onlyOwner
└── inherits ERC20
    └── state: _balances, _allowances, _totalSupply
```

```text
MODIFIER EXECUTION ORDER for update():
┌─────────────────────────────────────────┐
│ 1. nonReentrant                         │
│    └── require(_status != ENTERED)      │
│    └── _status = ENTERED                │
├─────────────────────────────────────────┤
│ 2. whenNotPaused                        │
│    └── require(!_paused)                │
├─────────────────────────────────────────┤
│ 3. [FUNCTION BODY EXECUTES]             │
├─────────────────────────────────────────┤
│ 4. nonReentrant (cleanup)               │
│    └── _status = NOT_ENTERED            │
└─────────────────────────────────────────┘
```

**Inheritance Checklist:**
- [ ] All parent contracts identified
- [ ] All inherited state variables mapped
- [ ] All modifiers traced in execution order
- [ ] Virtual functions checked for overrides
- [ ] Diamond inheritance conflicts checked (if multiple inheritance)

**Modifier Red Flags:**
- [ ] Missing `nonReentrant` on external call functions
- [ ] Missing `whenNotPaused` on critical functions
- [ ] Custom modifiers with side effects
- [ ] Modifier order matters (reentrancy guard should be FIRST)

---

```python
# Quick mental algorithm
def build_spine(function):
    visited = set()
    spine = []
    
    def add_to_spine(fn):
        if fn in visited: return
        visited.add(fn)
        
        # Classify immediately
        if "get" in fn.name or "load" in fn.name:
            category = "[SNAPSHOT] "
        elif "check" in fn.name or "require" in fn.name:
            category = "[VALIDATION] "
        elif "update" in fn.name or "set" in fn.name:
            category = "[MUTATION] "
        elif "save" in fn.name or "emit" in fn.name:
            category = "[COMMIT] "
        else:
            category = "[UNKNOWN] "
        
        spine.append(category + fn.name)
        
        # Add called functions
        for internal_call in fn.internal_calls:
            spine.append(f"  └── {internal_call.name}")
            add_to_spine(internal_call)
    
    add_to_spine(function)
    return spine
```

### **Step 2.2: Semantic Classification Cheat Sheet**
When you see a function, tag it instantly:

| What it DOES | Category | Questions to Ask |
|--------------|----------|------------------|
| Reads storage | SNAPSHOT | "Is this state fresh?" |
| Checks conditions | VALIDATION | "Can this be bypassed?" |
| Uses time/oracle | ACCOUNTING | "Can this be manipulated?" |
| Changes balances | MUTATION | "Is value conserved?" |
| Writes storage | COMMIT | "Is everything saved?" |
| Calls externals | RISK | "Can this be reentered?" |

### **Step 2.3: Audit in SEMANTIC Order (Not Call Order)**
**This is the key innovation:**
1. **First pass**: Audit ALL SNAPSHOT functions in the spine
2. **Second pass**: Audit ALL ACCOUNTING functions
3. **Third pass**: Audit ALL VALIDATION functions
4. **Fourth pass**: Audit ALL MUTATION functions
5. **Fifth pass**: Audit ALL COMMIT functions

**Why this works:** Functions in the same phase have similar vulnerabilities.

---

## **Phase 3: State Mutation Tracking (Enhanced)**

### **Step 3.1: Create Phase-Based Mutation Table**
```markdown
| Variable | Type | Snapshot Reads | Accounting Updates | User Changes | Commits To | Validated? |
|----------|------|----------------|-------------------|--------------|------------|------------|
| balances | map | storage | +fees (line 45) | +deposit (89) | storage | ❌ |
| totalSupply | uint | storage | +interest (67) | +mint (123) | storage | ✅ |
| lastUpdated | uint | - | =timestamp (34) | - | storage | ❌ |
```

### **Step 3.2: Invariant Tracking by Phase**
For EACH key invariant, check EACH phase:

```markdown
Invariant: totalSupply == Σ(balances)

Snapshot Phase:
- totalSupply read from storage ✓
- balances read from storage ✓
- Are they read atomically? ❌ (bug!)

Accounting Phase:
- totalSupply updated (+interest) at L67
- balances updated (+fees) at L45
- Are updates consistent? ? (check)

Mutation Phase:
- totalSupply changed (+mint) at L123
- balances changed (+deposit) at L89
- Are changes proportional? ✓

Commit Phase:
- Both written to storage ✓
- In same transaction? ✓
```

### **Step 3.3: Validation Gap Detection**
```python
# Mental check for each variable
def check_variable(var_name):
    gaps = []
    
    # Check: if changed in accounting phase, is it validated?
    if changed_in_accounting(var_name) and not validated(var_name):
        gaps.append(f"{var_name}: Accounting changes without validation")
    
    # Check: if changed by user input, is it bounded?
    if changed_by_user(var_name) and not bounded(var_name):
        gaps.append(f"{var_name}: User changes without bounds")
    
    # Check: if committed, is it consistent?
    if committed(var_name) and not consistent_with_other_vars(var_name):
        gaps.append(f"{var_name}: Inconsistent commit")
    
    return gaps
```

### **Step 3.4: Semantic Guard Analysis**
Build a usage graph of security guards across ALL functions:

```markdown
## Guard Usage Graph
For each `require`, `modifier`, or access check:
1. List ALL functions that enforce it
2. List ALL functions that touch the same state but SKIP it
3. Flag inconsistencies (Consistency Principle)

| Guard | Functions WITH Guard | Functions WITHOUT Guard | Same State? | Risk |
|-------|---------------------|------------------------|-------------|------|
| `onlyOwner` | setFee(), pause() | emergencyWithdraw() | ✅ config | ⚠️ |
| `nonReentrant` | withdraw(), deposit() | claim() | ✅ balances | 🚨 |
| `whenNotPaused` | deposit(), swap() | withdraw() | ✅ core ops | ⚠️ |

### Consistency Principle
If guard G protects function A, and function B touches the same state variables
as A, then B should also have guard G (or an equivalent protection).

Violations of this principle indicate:
- Missing access controls
- Forgotten pause checks
- Reentrancy surface gaps
- Inconsistent privilege boundaries
```

### **Step 3.5: State Invariant Inference**
Automatically infer mathematical relationships from code:

```markdown
## Invariant Categories to Detect

### 1. Sum Invariants
totalSupply == Σ(balanceOf[i]) for all i
totalDeposits == Σ(userDeposit[i]) for all i

### 2. Conservation Rules
protocol.balance >= Σ(claims) + Σ(pending_withdrawals)
fees_collected + distributed + remaining == original_amount

### 3. Ratio Invariants
shares[user] / totalShares == user_proportion (monotonic or bounded)
collateral[user] / debt[user] >= minCollateralRatio

### 4. Monotonic Properties
nonce[user] only increases
accumulatedRewardsPerShare only increases
totalSupply only changes via mint/burn (not arbitrary assignment)

### 5. Synchronized State
If A and B must be updated together, verify:
- No code path updates A without B
- No code path updates B without A
- No external call between updating A and B

## Audit Method
For EACH inferred invariant:
- [ ] List all functions that could violate it
- [ ] Trace through each function to verify invariant holds
- [ ] Test edge cases: zero values, max values, first/last user
- [ ] Check: does invariant hold across reentrancy?
- [ ] Check: does invariant hold across flash loan?
```

---

## **Phase 4: Attack Simulation with Phase Analysis**

### **Step 4.1: Phase-Specific Attack Vectors**
For EACH phase, test specific attacks:

**Snapshot Phase Attacks:**
- [ ] **Frontrunning**: State read → tx in mempool → state changes
- [ ] **Reentrancy**: Snapshot → external call → reenter → snapshot different
- [ ] **Stale Data**: Using old oracle prices/storage

**Accounting Phase Attacks:**
- [ ] **Time manipulation**: `block.timestamp` jumps
- [ ] **Oracle manipulation**: Price feed attacks
- [ ] **Rounding errors**: Accumulator precision loss

**Validation Phase Attacks:**
- [ ] **Bypass**: Missing checks, wrong order
- [ ] **DoS**: Gas griefing on validation
- [ ] **Logic flaws**: Wrong condition checks

**Mutation Phase Attacks:**
- [ ] **Value theft**: Incorrect balance updates
- [ ] **Overflow/underflow**: Math errors
- [ ] **Slippage**: Missing limits

**Commit Phase Attacks:**
- [ ] **Inconsistent state**: Partial writes
- [ ] **Missing events**: No logs for state changes
- [ ] **Storage collisions**: Proxy/upgrade issues

### **Step 4.2: Cross-Phase Attack Scenarios**
Test interactions BETWEEN phases:

1. **Snapshot → Mutation Race**:
   ```solidity
   // Bug: snapshot at time T, mutation at T+1 with different state
   balance = balances[user];  // Snapshot
   // <-- Attacker changes state here
   balances[user] = balance - amount;  // Mutation
   ```

2. **Accounting → Validation Order**:
   ```solidity
   // Bug: accounting changes, then validation checks OLD state
   _accrueInterest();  // Accounting changes state
   require(balance >= amount);  // Validation uses OLD balance??
   ```

3. **Mutation → Commit Gap**:
   ```solidity
   // Bug: mutation successful, commit fails
   balances[to] += amount;  // Mutation
   // <-- Revert here
   emit Transfer(from, to, amount);  // Never reached
   ```

### **Step 4.3: Semantic Edge Case Testing**
For EACH phase, test these values:

**Snapshot Phase:**
- Zero/non-existent keys
- Uninitialized storage
- Proxy storage slots

**Accounting Phase:**
- Timestamp = 0, max, overflow
- Oracle price = 0, very large, stale
- Rates = 0%, 100%, >100%

**Validation Phase:**
- Inputs = 0, 1, max, max-1
- Addresses = zero, contract, self
- Arrays = empty, very large

**Mutation Phase:**
- Amounts that cause overflow/underflow
- Self-transfers (from == to)
- Partial vs full amounts

**Commit Phase:**
- Revert after partial writes
- Event parameter mismatches
- Gas limits on storage writes

---

## **Phase 5: Finding Documentation with Phase Context**

### **Step 5.1: Enhanced Finding Template**
```markdown
## [SEVERITY] Phase-Specific Bug Title

### Location
- **Contract**: `ContractName.sol`
- **Function**: `functionName()`
- **Phase**: [SNAPSHOT/ACCOUNTING/VALIDATION/MUTATION/COMMIT]
- **Lines**: L123-L145

### Phase Analysis
**Snapshot Issue**: [State freshness/staleness]
**Accounting Issue**: [Time/oracle manipulation]
**Validation Issue**: [Missing/broken checks]
**Mutation Issue**: [Value conservation]
**Commit Issue**: [Storage consistency]

### Proof of Concept by Phase
```solidity
// Phase-by-phase exploitation
function exploit() public {
    // 1. Snapshot Phase Setup
    // 2. Accounting Phase Manipulation
    // 3. Validation Phase Bypass
    // 4. Mutation Phase Theft
    // 5. Commit Phase Cover-up
}
```

### Phase-Specific Fix
```solidity
// Fix depends on phase:
// Snapshot: Add freshness check
// Accounting: Add bounds/oracle validation
// Validation: Add missing require
// Mutation: Fix math/ordering
// Commit: Ensure atomic writes
```

### Cross-Phase Impact
- **Snapshot → Mutation**: [Race condition?]
- **Accounting → Validation**: [Order dependency?]
- **Mutation → Commit**: [Atomicity?]
```

### **Step 5.2: Phase-Based Severity Assessment**
```markdown
## HIGH Severity (Critical)
- **Accounting Phase**: Oracle manipulation leading to fund theft
- **Mutation Phase**: Direct value creation/destruction
- **Cross-Phase**: Snapshot→Mutation race for >$100k

## MEDIUM Severity
- **Validation Phase**: Missing bounds allowing griefing
- **Commit Phase**: Inconsistent state requiring admin fix
- **Snapshot Phase**: Stale data causing unfairness

## LOW Severity
- **Any Phase**: Gas inefficiencies
- **Commit Phase**: Missing events
- **Validation Phase**: Redundant checks
```

---

### **Step 6.1: Enhanced Audit Script**
```bash
#!/bin/bash
# enhanced-audit.sh

# 1. Find entry points with semantic criteria
echo "=== Finding Entry Points ==="
grep -n "function.*external\|function.*public" *.sol | grep -v "view\|pure" > entry_points.txt

# 2. For each, build spine with phase classification
while read -r func; do
    contract=$(echo $func | cut -d: -f1)
    line=$(echo $func | cut -d: -f2)
    echo "=== Spine for $contract @ $line ==="
    
    # Extract function and its calls
    # This is pseudo-code - implement with solc or slither
    build_semantic_spine "$contract" "$line"
done < entry_points.txt

# 3. Generate phase-based mutation table
echo "=== Mutation Tables ==="
python3 generate_mutation_tables.py --phases

# 4. Run phase-specific tests
echo "=== Phase Testing ==="
forge test --match-test "testSnapshot*"
forge test --match-test "testAccounting*"
forge test --match-test "testMutation*"
```

### **Step 6.2: Mental Classification Shortcuts**
When reading code, use these patterns:

```text
IF function name contains:       THEN classify as:
- "get", "load", "read"          → SNAPSHOT
- "check", "validate", "require" → VALIDATION  
- "accrue", "interest", "fee"    → ACCOUNTING
- "update", "transfer", "mint"   → MUTATION
- "save", "emit", "write"        → COMMIT
```

---

## **Phase 7: Behavioral State Analysis**

### **Step 7.1: Behavioral Decomposition**
Treat the contract’s code as its own specification. Extract behavioral intent:

```markdown
## For each public/external function, answer:
1. **Core Intent**: What is this function trying to achieve? (e.g., "transfer tokens", "update oracle")
2. **Security Guards**: What `require`/modifier checks protect it?
3. **State Invariants**: What mathematical relationships must hold before and after?
4. **Side Effects**: What other state changes or external calls occur?
5. **Trust Boundaries**: What does it assume about callers, parameters, and external contracts?
```

### **Step 7.2: Multi-Dimensional Threat Modeling**
For each function’s behavioral intent, evaluate threats across three dimensions:

```markdown
| Dimension | Question | Vulnerability Class |
|-----------|----------|--------------------|
| **Economic** | Can the function be exploited for profit? | Flash loan, sandwich, oracle manipulation |
| **Permission** | Can unauthorized actors trigger this behavior? | Access control, missing guards, privilege escalation |
| **State Integrity** | Can state invariants be broken? | Accounting drift, reentrancy, race conditions |
```

### **Step 7.3: Adversarial Simulation**
For promising threat vectors, construct concrete attack scenarios:

```markdown
## Attack Scenario Template
1. **Initial State**: What conditions must exist?
2. **Trigger**: What transaction(s) does the attacker send?
3. **Mechanism**: How does it exploit the identified weakness?
4. **Impact**: What is the concrete result (funds stolen, state corrupted, DoS)?
5. **Confidence**: How certain are you this works? (Low / Medium / High)
   - Based on: code evidence, historical precedent, invariant violation
```

### **Step 7.4: Confidence Scoring**
Assign probabilistic risk levels to each hypothesis:

```markdown
| Evidence Factor | Weight | Score |
|----------------|--------|-------|
| Guard analysis: missing guard on state-touching function | High | +3 |
| Invariant analysis: provable invariant violation | High | +3 |
| Historical pattern match (known exploit) | Medium | +2 |
| Edge case / unusual input triggers issue | Medium | +2 |
| Theoretical / requires very specific conditions | Low | +1 |

Total ≥7: HIGH confidence (likely valid finding)
Total 4-6: MEDIUM confidence (needs deeper analysis)
Total ≤3: LOW confidence (theoretical / unlikely)
```
---
