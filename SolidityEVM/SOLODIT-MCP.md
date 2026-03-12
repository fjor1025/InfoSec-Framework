# Solodit MCP Integration — Prior Art & Finding Validation

> **Prerequisites:** claudit MCP server installed and configured

## Purpose

Search Solodit's database of **20,000+ real smart contract security findings** to:
- Validate findings against known vulnerability patterns
- Find prior art before reporting
- Research historical exploits by protocol type, tag, or auditor
- Enhance finding quality with real-world references

## Available MCP Tools

| Tool | Purpose |
|------|---------|
| `mcp__solodit__search_findings` | Keyword/filter search across all findings |
| `mcp__solodit__get_finding` | Fetch full details for a specific finding |
| `mcp__solodit__get_filter_options` | Discover valid filter values (firms, tags, categories) |

## Integration Points

### 1. Protocol Analysis Phase

After identifying protocol type (DEX, lending, bridge, etc.), search Solodit for historical findings:

```
search_findings(
  tags=["<protocol_type>"],
  severity=["HIGH", "CRITICAL"],
  sort_by="Quality"
)
```

### 2. Finding Validation Phase

Before finalizing any finding, cross-reference with Solodit:

```
search_findings(
  keywords="<vulnerability_description>",
  severity=["HIGH", "MEDIUM"],
  sort_by="Quality",
  page_size=5
)
```

### 3. Attack Vector Research

Research specific vulnerability classes with tag combinations:

| Attack Class | Solodit Search |
|--------------|----------------|
| Reentrancy | `tags=["Reentrancy"], severity=["HIGH"]` |
| Oracle Manipulation | `tags=["Oracle"], severity=["HIGH", "CRITICAL"]` |
| Access Control | `tags=["Access Control"], severity=["HIGH"]` |
| Flash Loan | `tags=["Flash Loan"], severity=["HIGH"]` |
| Precision Loss | `tags=["Math", "Rounding"], severity=["MEDIUM", "HIGH"]` |

### 4. Auditor Pattern Research

Study top auditor methodology by filtering their findings:

```
search_findings(
  advanced_filters={ "user": "0x52" },
  severity=["HIGH"],
  sort_by="Quality"
)
```

## Mandatory Usage Rules

### When to Search Solodit

1. **Before reporting High/Critical findings** — validate it's not a known false positive pattern
2. **When finding matches fv-sol-X patterns** — check real-world impact references
3. **For protocol-specific audits** — load historical findings for that protocol type
4. **When triager challenges a finding** — provide prior art evidence

### Output Format (MANDATORY)

When presenting Solodit results in findings, use this format:

```markdown
### Prior Art References
1. **[HIGH] <Title>**
   <Firm> (<Protocol>) · Quality: X/5 · Finders: N
   → https://solodit.cyfrin.io/issues/...

2. **[MEDIUM] <Title>**
   <Firm> (<Protocol>) · Quality: X/5 · Finders: N
   → https://solodit.cyfrin.io/issues/...
```

**NEVER use tables for Solodit output. Always include the → URL line.**

## Workflow Integration

### In MULTI-EXPERT.md (Expert 1 & 2)

Experts should search Solodit during analysis to:
- Reference similar known issues
- Validate attack feasibility with real exploits
- Cite prior art in finding writeups

### In TRIAGER.md (Validation Expert)

Triager should:
- Challenge findings lacking Solodit references
- Use Solodit to find contradicting evidence (FP patterns)
- Verify economic feasibility against real exploit outcomes

### In FINDING-FORMAT.md

Add to **References** section:

```markdown
**Prior Art (Solodit):**
- [Finding Title](https://solodit.cyfrin.io/issues/...) — <brief relevance>
```

## Search Tips

| Goal | Strategy |
|------|----------|
| Find novel issues | `sort_by="Rarity", advanced_filters={ "max_finders": 1 }` |
| High-quality writeups | `sort_by="Quality"` |
| Recent findings | `reported="90"` (last 90 days) |
| Specific firm methodology | `firms=["Sherlock", "Code4rena"]` |
| Language-specific | `language="Solidity"` |

## Cross-Reference with fv-sol-X

When a Solodit finding matches an fv-sol-X pattern:

1. Note the Solodit URL in the fv-sol-X case study
2. Use the Solodit finding's severity/impact as calibration
3. Reference both in the final finding writeup

## Installation

```bash
# From claudit directory
npm install
npx claudit install

# Or global MCP server configuration
```

See [claudit README](../../claudit/README.md) for full setup instructions.
