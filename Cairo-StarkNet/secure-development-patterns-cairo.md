# Cairo/StarkNet Secure Development Patterns — OpenZeppelin Integration

> For auditing contracts claiming OpenZeppelin for Cairo integration

## Component Pattern Validation

### Standard Component Integration

```cairo
// EXPECTED: Component macro declaration
component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

// VALIDATE:
// ✓ component! macro used, not manual implementation
// ✓ #[substorage(v0)] on component storage
// ✓ #[flat] on component events
// ✓ Internal impl imported for internal methods

// AUDIT FLAGS:
// ⚠ Manual reimplementation of component logic
// ⚠ Missing #[substorage(v0)] causing storage collision
// ⚠ Missing #[abi(embed_v0)] on external impl
```

### Ownable Pattern

```cairo
// VALIDATE:
// ✓ OwnableComponent imported from openzeppelin_access
// ✓ assert_only_owner() used before critical operations
// ✓ Owner initialization in constructor

// AUDIT FLAGS:
// ⚠ Custom owner tracking duplicating OwnableComponent storage
// ⚠ Missing owner initialization (zero address default = locked)
// ⚠ Two-step ownership not used for high-value protocols
```

### Access Control / RBAC Pattern

```cairo
// VALIDATE:
// ✓ AccessControlComponent with proper role definitions
// ✓ DEFAULT_ADMIN_ROLE granted during initialization
// ✓ has_role checks before privileged operations

// AUDIT FLAGS:
// ⚠ Role admin misconfiguration
// ⚠ DEFAULT_ADMIN_ROLE granted to zero address
// ⚠ Overlapping role permissions without proper hierarchy
```

## Token Standards Validation

### ERC20 Pattern

```cairo
// EXPECTED: ERC20Component with hooks
use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};

// VALIDATE:
// ✓ ERC20Component properly integrated via component! macro
// ✓ Mixin impl embedded for full interface
// ✓ Hooks connected (even if empty)

// AUDIT FLAGS:
// ⚠ Manual balance tracking instead of component
// ⚠ Missing ERC20HooksEmptyImpl or custom hooks
// ⚠ Direct storage manipulation bypassing component
```

### ERC721 / ERC1155 Patterns

```cairo
// VALIDATE:
// ✓ Component macro integration
// ✓ SRC5Component for interface introspection
// ✓ Proper receiver validation for safe transfers

// AUDIT FLAGS:
// ⚠ Missing SRC5 introspection registration
// ⚠ Transfer hooks not checking receiver compatibility
// ⚠ Batch operations without proper gas consideration
```

## Upgradeability Validation — CRITICAL SURFACE

### UpgradeableComponent Pattern

```cairo
// EXPECTED: Guarded upgrade function
#[abi(embed_v0)]
fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
    self.ownable.assert_only_owner();
    self.upgradeable.upgrade(new_class_hash);
}

// VALIDATE:
// ✓ Access control check BEFORE upgrade call
// ✓ UpgradeableComponent from openzeppelin_upgrades
// ✓ Upgraded event emitted (component handles this)
// ✓ Zero class hash rejection (component handles this)

// AUDIT FLAGS:
// ⚠ CRITICAL: upgrade() callable without access check → contract takeover
// ⚠ Direct replace_class_syscall without component (missing events/validation)
// ⚠ Missing OwnableComponent or AccessControl integration
```

### Storage Compatibility

```cairo
// Cairo storage slots derived from variable NAME (sn_keccak), not position

// VALIDATE:
// ✓ No renamed storage variables between versions
// ✓ No removed storage variables
// ✓ No changed types on existing variables
// ✓ #[substorage(v0)] prefix convention for component isolation

// AUDIT FLAGS:
// ⚠ Storage variable renamed (old data inaccessible, slot collision)
// ⚠ Type change on existing storage (data corruption)
// ⚠ Component collision from missing prefix convention
```

### Version Upgrade Safety

| Version Jump | Storage Safety | Audit Action |
|-------------|----------------|--------------|
| Patch | ✅ Always safe | Minimal review |
| Minor (≥1.0.0) | ✅ Layout preserved | Check changelog for behavior |
| Major | ⚠ May break layout | Full storage audit, block upgrade path |

## Cairo-Specific Security Patterns

### Panic vs Assert vs Revert

```cairo
// Cairo uses panic! and assert!, NOT Solidity require/revert

// VALIDATE:
// ✓ panic!('error message') for error conditions
// ✓ assert() generates panic on failure
// ✓ Custom errors via felt252 or enums

// AUDIT FLAGS:
// ⚠ Silent failure (no panic on error condition)
// ⚠ Inconsistent error handling patterns
```

### Reentrancy Considerations

```cairo
// Cairo uses messaging, not synchronous calls like EVM

// VALIDATE:
// ✓ State updated before any call_contract_syscall
// ✓ ReentrancyGuardComponent if handling external callbacks

// AUDIT FLAGS:
// ⚠ State update after syscall
// ⚠ View function reading uncommitted state (cross-component)
```

### Storage Mapping Patterns

```cairo
// Cairo LegacyMap patterns
#[storage]
struct Storage {
    balances: LegacyMap<ContractAddress, u256>,
}

// VALIDATE:
// ✓ Key type matches expected access patterns
// ✓ Zero address handling for default values
// ✓ ContractAddress vs felt252 key consistency

// AUDIT FLAGS:
// ⚠ Key type mismatch allowing collision
// ⚠ Zero address as valid key without special handling
```

## Integration with Audit Workflow

### During Protocol Analysis

1. Check imports for `openzeppelin` or `openzeppelin_*` packages
2. Verify component! macro usage matches imported components
3. For upgradeable contracts, validate access control on upgrade()

### During Finding Validation

Cross-reference with cairo-specific patterns:
- **VALID**: Misuse of Cairo OZ component pattern
- **DISMISSED**: OZ component correctly integrated
- **QUESTIONABLE**: Edge case in Cairo execution model

### fv-mov Cross-References (Move patterns applicable to Cairo)

| Cairo Pattern | Similar Move fv-mov |
|---------------|---------------------|
| Object abilities | fv-mov-1 (object model has parallel concepts) |
| AccessControl | fv-mov-2 (capability-based access) |
| UpgradeableComponent | fv-mov-3 (upgrade safety) |
| Storage compatibility | fv-mov-3 (storage layout) |

## Resources

- [OpenZeppelin Contracts for Cairo Docs](https://docs.openzeppelin.com/contracts-cairo)
- [Cairo Book](https://book.cairo-lang.org/)
- [StarkNet Documentation](https://docs.starknet.io/)
- [openzeppelin-skills/setup-cairo-contracts](../../openzeppelin-skills/skills/setup-cairo-contracts/SKILL.md)
- [openzeppelin-skills/upgrade-cairo-contracts](../../openzeppelin-skills/skills/upgrade-cairo-contracts/SKILL.md)
