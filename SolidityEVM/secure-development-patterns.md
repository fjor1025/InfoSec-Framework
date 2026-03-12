# Secure Development Patterns — OpenZeppelin Integration

> For auditing contracts claiming OpenZeppelin integration or when validating best practices

## Security Validation Reference

Use this during audits to validate that contracts correctly integrate OpenZeppelin patterns.

## Access Control Validation

### Pattern: Ownable

```solidity
// EXPECTED: Single owner transferable access
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// VALIDATE:
// ✓ onlyOwner modifier on sensitive functions
// ✓ owner() returns non-zero address initially
// ✓ transferOwnership not callable by non-owner
// ✓ renounceOwnership not called unintentionally

// AUDIT FLAGS:
// ⚠ onlyOwner missing on admin functions
// ⚠ Custom owner tracking duplicating Ownable storage
// ⚠ Ownable2Step not used for high-value protocols
```

### Pattern: AccessControl

```solidity
// EXPECTED: Role-based access with granular permissions
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

// VALIDATE:
// ✓ DEFAULT_ADMIN_ROLE granted to non-zero address
// ✓ Role hierarchy configured (admin of each role)
// ✓ hasRole checks before sensitive operations
// ✓ No role can be self-granted without admin of that role

// AUDIT FLAGS:
// ⚠ DEFAULT_ADMIN_ROLE granted to address(0)
// ⚠ Role checks missing on token mint/burn
// ⚠ Role admin misconfiguration allowing privilege escalation
```

## Reentrancy Protection Validation

### Pattern: ReentrancyGuard

```solidity
// EXPECTED: Mutex lock on external-call-containing functions
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// VALIDATE:
// ✓ nonReentrant modifier on all functions with external calls
// ✓ Guard inherited, not re-implemented
// ✓ No custom mutex competing with ReentrancyGuard

// AUDIT FLAGS:
// ⚠ External call without nonReentrant
// ⚠ Custom reentrancy variable instead of library
// ⚠ CEI pattern not followed even with guard
// ⚠ Cross-contract reentrancy not addressed
```

## Token Standards Validation

### Pattern: ERC20

```solidity
// EXPECTED: Standard ERC20 with extensions as needed
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// VALIDATE:
// ✓ totalSupply() matches sum of balances
// ✓ _mint and _burn protected by access control
// ✓ safeTransfer wrappers used for external token pulls

// AUDIT FLAGS:
// ⚠ Public/external mint without access control
// ⚠ _beforeTokenTransfer hook not calling super
// ⚠ Return value of transfer/approve not checked when calling external ERC20
// ⚠ Fee-on-transfer/rebasing tokens breaking assumptions
```

### Pattern: ERC721 / ERC1155

```solidity
// VALIDATE:
// ✓ safeTransferFrom callback after state update (CEI)
// ✓ onERC721Received/onERC1155Received returns correct magic value
// ✓ tokenURI not controllable by arbitrary callers

// AUDIT FLAGS:
// ⚠ safeMint/safeTransfer before state finalization → reentrancy vector
// ⚠ Missing supportsInterface for ERC165
// ⚠ Batch operations without gas limits
```

## Upgradeability Validation

### Pattern: UUPS / Transparent / Beacon

```solidity
// CRITICAL SURFACE for upgradeable contracts

// VALIDATE:
// ✓ Initializers used instead of constructors
// ✓ _disableInitializers() in constructor
// ✓ initializer modifier on init function (not onlyInitializing for entry point)
// ✓ Storage layout preserved between versions
// ✓ No variable reordering or type changes

// AUDIT FLAGS:
// ⚠ Constructor setting state variables (proxy won't inherit)
// ⚠ Missing _disableInitializers() → implementation can be hijacked
// ⚠ Field initializers (uint256 x = 42) instead of initializer assignment
// ⚠ Storage gaps removed or shortened
// ⚠ Inheritance order changed between versions
// ⚠ v4 → v5 upgrade attempted (storage layout incompatible)
```

### UUPS-Specific Checks

```solidity
// VALIDATE:
// ✓ _authorizeUpgrade implemented with access control
// ✓ UUPSUpgradeable inherited

// AUDIT FLAGS:
// ⚠ _authorizeUpgrade is empty or returns without checking caller
// ⚠ upgradeTo/upgradeToAndCall not protected by proper authorization
```

### Transparent Proxy Checks

```solidity
// VALIDATE:
// ✓ Admin cannot call implementation functions directly
// ✓ ProxyAdmin ownership secured

// AUDIT FLAGS:
// ⚠ Admin address can be frontend user address
// ⚠ ProxyAdmin without proper access control on ownership
```

## Cryptographic Operations Validation

### Pattern: ECDSA / SignatureChecker

```solidity
// VALIDATE:
// ✓ Deadline/expiry for signed messages
// ✓ Nonce tracking to prevent replay
// ✓ Domain separator includes chainId and contract address
// ✓ EIP-712 typed data structure

// AUDIT FLAGS:
// ⚠ Missing nonce → replay attack
// ⚠ Signature malleable (ECDSA.recover returns different signer for s/v variants)
// ⚠ No chainId in domain → cross-chain replay
// ⚠ ecrecover used instead of ECDSA.recover → zero address on invalid sig
```

### Pattern: MerkleProof

```solidity
// VALIDATE:
// ✓ multiProofVerify with proofFlags correctly ordered
// ✓ Leaf encoding prevents second preimage attack

// AUDIT FLAGS:
// ⚠ Leaf is just the address without domain separation
// ⚠ Internal nodes indistinguishable from leaves
```

## Pausability Validation

### Pattern: Pausable

```solidity
// VALIDATE:
// ✓ whenNotPaused on user-facing functions
// ✓ _pause() and _unpause() access controlled
// ✓ Emergency withdrawal still works when paused (if intended)

// AUDIT FLAGS:
// ⚠ Pause missing on critical functions
// ⚠ Pause can lock funds permanently without emergency hatch
// ⚠ Anyone can call pause (no access control)
```

## Integration with Audit Workflow

### During Protocol Analysis (Step 1)

1. Identify all OpenZeppelin imports in scope
2. For each import, validate correct integration using patterns above
3. Flag any custom implementations duplicating library functionality

### During Finding Validation (TRIAGER Phase)

Cross-reference findings against OpenZeppelin's expected patterns:
- **VALID**: Misuse of library pattern confirmed
- **DISMISSED**: Library correctly used, finding based on misunderstanding
- **QUESTIONABLE**: Edge case not covered by standard patterns

### fv-sol-X Cross-References

| OpenZeppelin Pattern | Related fv-sol-X |
|---------------------|------------------|
| ReentrancyGuard | fv-sol-1-reentrancy |
| ERC20/ERC721 transfers | fv-sol-2-precision-errors, fv-sol-6-unchecked-returns |
| AccessControl | fv-sol-4-bad-access-control |
| Upgradeable | fv-sol-7-proxy-insecurities |
| Pausable | fv-sol-5-logic-errors |
| MerkleProof | fv-sol-4-bad-access-control (whitelist bypass) |

## Resources

- [OpenZeppelin Contracts Docs](https://docs.openzeppelin.com/contracts)
- [OpenZeppelin Upgrades Plugins](https://docs.openzeppelin.com/upgrades-plugins)
- [ERC-7201 Namespaced Storage](https://eips.ethereum.org/EIPS/eip-7201)
- [openzeppelin-skills/develop-secure-contracts](../../openzeppelin-skills/skills/develop-secure-contracts/SKILL.md)
- [openzeppelin-skills/upgrade-solidity-contracts](../../openzeppelin-skills/skills/upgrade-solidity-contracts/SKILL.md)
