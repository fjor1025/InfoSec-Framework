<!-- Managed by docs-for-humans-and-ai skill — do not edit the template section manually -->
<!-- Version: 1.0.0 -->
<!-- Adapted from https://github.com/Cyfrin/claude-docs-prompts for security audit frameworks -->

# InfoSec-Framework

A structured audit framework for smart contract security across 6 blockchain ecosystems. Pure Markdown knowledge graph — no build step, no web framework.

**Before making any changes**, read this file fully to understand the repo structure, conventions, and contribution rules.

## Project Structure

```
InfoSec-Framework/
├── CLAUDE.md                              ← You are here — AI agent context
├── README.md                              ← Human-facing overview + quick start
├── report-writing.md                      ← Universal report writing guide
├── VULNERABILITY_PATTERNS_INTEGRATION.md  ← ClaudeSkills integration status
├── llms.txt                               ← AI index (page list with descriptions)
├── llms-full.txt                          ← AI ingest (full concatenated content)
│
├── SolidityEVM/                           ← Benchmark framework (v3.1)
│   ├── CommandInstruction.md              ← System prompt (binding rules)
│   ├── audit-workflow1.md                 ← Manual methodology + 170-vector Pashov
│   ├── audit-workflow2.md                 ← Semantic phase analysis (SNAPSHOT→COMMIT)
│   ├── Audit_Assistant_Playbook.md        ← Conversation structure (19 SCAN prompts)
│   └── pashov-skills/                     ← Pashov Audit Group integration
│       ├── finding-validation.md          ← FP gate + confidence scoring
│       ├── report-formatting.md           ← Output template
│       ├── agents/                        ← Vector-scan + adversarial agent instructions
│       └── attack-vectors/                ← 170 atomic attack vectors (4 files)
│
├── RustBaseSmartContract/                 ← CosmWasm / Solana / Substrate (v3.2)
├── Go-SmartContract/                      ← Cosmos SDK / IBC / CometBFT
├── Cosmos-SDK/                            ← Chain-level governance / consensus
├── Cairo-StarkNet/                        ← StarkNet L2
├── Algorand-PyTeal/                       ← PyTeal / TEAL
│   (each contains CLAUDE.md + README.md + CommandInstruction + Methodology + Playbook)
│
├── ClaudeSkills/                          ← Trail of Bits vulnerability patterns + plugins
│   └── plugins/
│       ├── solidity-auditor/              ← /solidity-auditor slash command (Pashov)
│       ├── docs-for-humans-and-ai/        ← Documentation standard (this integration)
│       ├── audit-context-building/        ← Deep context before hunting
│       ├── building-secure-contracts/     ← Ecosystem vulnerability scanners
│       └── ...                            ← 20+ additional plugins
│
└── scripts/
    └── build-llms-txt.sh                  ← Generates llms.txt + llms-full.txt
```

## Architecture — 3-File Pattern

Every ecosystem framework follows the same architecture:

| File | Role | AI Behavior |
|------|------|-------------|
| **CommandInstruction** | System prompt | Load first. Binding rules — overrides base knowledge. |
| **Methodology/Workflow** | Audit phases + checklists | Reference during analysis. Cite as `[filename, section]`. |
| **Playbook** | Conversation structure + SCAN prompts | Defines agent roles, turn structure, and signal generators. |

**Critical rule**: These are binding documents, not suggestions. When editing them, preserve:
- The 5 Core Rules of Engagement
- The 4 Mandatory Validation Checks (Reachability, State Freshness, Execution Closure, Economic Realism)
- The Auditor's Mindset lenses (ecosystem-specific)
- The AUTHORITATIVE SOURCES hierarchy

## Content Conventions

### Writing for Humans AND AI

Every document in this framework must serve two audiences simultaneously:

1. **Human auditors** — who read, skim, and reference during manual reviews
2. **AI agents** — who ingest documents as system prompts or context

| Principle | Human Benefit | AI Benefit |
|-----------|--------------|------------|
| **Structured headings** (##, ###) | Scannable, navigable | Reliable section extraction |
| **Tables over prose** for checklists | Quick lookup | Structured data parsing |
| **Explicit labels** (`[AUDIT AGENT: X]`) | Clear role switching | Unambiguous trigger phrases |
| **Numbered steps** within phases | Sequential workflow | Ordered instruction following |
| **Cross-references** (`see Section X`) | Navigation | Context linking |
| **Severity/confidence markers** | Decision support | Triage automation |
| **"Do NOT" lists** | Guardrails | Hard constraints |
| **Code-fenced examples** | Copy-paste ready | Output format templates |

### Markdown Rules

- Use `#` only for the document title. Start sections at `##`.
- Use tables for any list of 3+ items with multiple attributes.
- Use code fences (```) for templates, output formats, and command examples.
- Use bold for key terms on first introduction, then plain text.
- Use `>` blockquotes only for critical warnings or philosophical principles.
- No HTML. No embedded images. No external CSS.
- File links use relative paths: `[audit-workflow1.md](audit-workflow1.md)` not absolute URLs.

### Naming Conventions

- **Files**: `kebab-case.md` for new files, preserve existing names for established files
- **Sections**: Title Case for `##` headings, Sentence case for `###` and below
- **Agent names**: `[AUDIT AGENT: Name]` — PascalCase with spaces
- **SCAN prompts**: `SCAN [Category Name]` — Title Case
- **Attack vectors**: Numbered within categories (e.g., "3.1 Reentrancy — Classic")

### Version Convention

- Major version (3.0 → 4.0): Architectural change to the 3-file pattern
- Minor version (3.0 → 3.1): New integration, new attack vectors, new SCAN prompts
- ALWAYS update version in: the file's header, README.md, and root README.md

## Diataxis Content Organization

When adding new content, follow the [Diataxis](https://diataxis.fr/) framework:

| Type | Purpose | Where in Framework | Example |
|------|---------|-------------------|---------|
| **Quickstart** | Zero to first audit ASAP | README.md "Quick Start" | "Set system prompt → Map → Generate → Validate → Draft" |
| **Tutorial** | Learn by doing | Playbook Section 1 (Build Layer) | Step-by-step merged.txt creation |
| **How-to** | Accomplish a specific task | SCAN prompts, agent roles | "SCAN Pashov 170-Vector Triage" |
| **Reference** | Look up during work | Methodology files, attack vector tables | Exploit database, severity matrix |
| **Explanation** | Understand concepts | Playbook key concepts, audit-workflow2.md | Semantic phases, binding architecture |

## AI Ingestibility

### llms.txt

The repo generates two files for AI consumption (run `scripts/build-llms-txt.sh`):

- **`llms.txt`** — Index of all pages with titles, paths, and one-line descriptions
- **`llms-full.txt`** — Full concatenated content of all framework files

These follow the [llms.txt spec](https://llmstxt.org/). Regenerate after any file addition/removal.

### System Prompt Usage

The CommandInstruction files are designed to be used as LLM system prompts. When an auditor loads `CommandInstruction.md` + methodology files + playbook, the AI operates under binding rules — not general chat behavior.

### Bundle File (merged.txt)

The Playbook Section 1 "Build Layer" generates a `merged.txt` containing all in-scope Solidity files. This is the primary artifact that AI agents analyze. The pattern extends to all ecosystems.

## How to Add a New Ecosystem Framework

1. Create a new directory: `NewEcosystem/`
2. Create 3 files following the established architecture:
   - `CommandInstruction-NewEcosystem.md` — adapt from SolidityEVM, add ecosystem-specific lenses
   - `NewEcosystem-Audit-Methodology.md` — phases, checklists, protocol-specific attacks
   - `Audit_Assistant_Playbook_NewEcosystem.md` — 10 sections, SCAN prompts
3. Create `README.md` with framework overview
4. If ClaudeSkills patterns exist for the ecosystem, integrate them
5. Update root `README.md` (structure diagram, comparison table, quick start)
6. Update `VULNERABILITY_PATTERNS_INTEGRATION.md`
7. Regenerate `llms.txt` and `llms-full.txt`
8. Update this file's Project Structure diagram

## How to Add a New ClaudeSkills Plugin

Follow the structure documented in [ClaudeSkills/CLAUDE.md](ClaudeSkills/CLAUDE.md):

```
plugins/plugin-name/
  .claude-plugin/plugin.json
  README.md
  skills/skill-name/SKILL.md
  skills/skill-name/resources/    (optional)
```

## Contribution Rules

1. **Preserve binding architecture** — Never weaken the 5 Core Rules or 4 Validation Checks
2. **Additive integration** — New content supplements, never replaces, existing methodology
3. **Cross-reference** — New attack vectors must map to existing workflow steps
4. **Version bump** — Every integration requires a version update
5. **Attribution** — Credit source repos/authors in README and integration files
6. **Regenerate AI artifacts** — Run `scripts/build-llms-txt.sh` after changes

## Key External Integrations

| Source | What It Provides | Where Integrated |
|--------|-----------------|-----------------|
| [evmresearch.io](https://evmresearch.io) | 300+ notes, 6 knowledge areas | SolidityEVM v3.0 |
| [QuillAudits Claude Skills V1](https://github.com/quillai-network/qs_skills) | 10 audit skills | SolidityEVM v2.1+ |
| [Pashov Audit Group](https://github.com/pashov/skills) | 170 attack vectors, parallelized agents | SolidityEVM v3.1 |
| [Trail of Bits](https://github.com/trailofbits/publications) | ClaudeSkills vulnerability scanners | All ecosystems |
| [Cyfrin claude-docs-prompts](https://github.com/Cyfrin/claude-docs-prompts) | Docs-for-humans-and-AI standard | This CLAUDE.md + docs-for-humans-and-ai skill |

<!-- LOCAL CUSTOMIZATIONS — everything below this line is preserved on update -->
