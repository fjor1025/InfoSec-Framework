---
name: docs-for-humans-and-ai
description: Guides Claude to write documentation that serves both human readers and AI agents equally well. Applies Diataxis organization, dual-audience formatting, and AI-ingestibility patterns.
---

# Docs for Humans and AI

## 1. Purpose

This skill governs **how Claude writes and reviews documentation** in security audit frameworks and technical knowledge graphs.

When active, Claude will:
- Apply **dual-audience formatting** to every document (human-scannable + AI-parseable)
- Organize content following the **Diataxis framework** (Quickstart, Tutorial, How-to, Reference, Explanation)
- Ensure documents are **AI-ingestible** as system prompts, context windows, or llms.txt feeds
- Maintain **template markers** (`<!-- LOCAL CUSTOMIZATIONS -->`) for safe updates
- Enforce **structural consistency** across ecosystem frameworks

---

## 2. When to Use This Skill

Use when:
- Writing or updating any `.md` file in a security audit framework
- Creating a new ecosystem framework (new blockchain, new protocol type)
- Reviewing documentation for completeness and AI-readability
- Generating or updating `llms.txt` / `llms-full.txt`
- Converting prose-heavy documentation into structured format

Do **not** use for:
- Writing audit findings (use report-writing.md instead)
- Code analysis or vulnerability hunting
- System prompt design (that's the CommandInstruction pattern)

---

## 3. Core Principle: Every Element Serves Two Audiences

| Element | Human Purpose | AI Purpose |
|---------|--------------|------------|
| `##` Headings | Scannable structure | Section extraction boundaries |
| `###` Subheadings | Detail navigation | Hierarchical context |
| Tables | Quick reference lookup | Structured data parsing |
| Numbered lists | Sequential workflow | Ordered instruction following |
| `**Bold**` terms | Visual emphasis on key terms | Term identification |
| `>` Blockquotes | Critical warnings stand out | Hard constraints / principles |
| Code fences | Copy-paste examples | Output format templates |
| `[LABEL: Name]` | Role identification | Trigger phrase matching |
| Cross-references | Navigation aid | Context linking across files |
| "Do NOT" lists | Guardrails | Hard negative constraints |
| Version headers | Change tracking | Document freshness assessment |

---

## 4. Diataxis Content Classification

Every piece of documentation serves one of five purposes. When writing, classify content explicitly:

### Quickstart (Get to "aha" fastest)
- **Length**: 5–10 steps maximum
- **Format**: Numbered list with one action per step
- **Audience**: Someone who wants to use the framework NOW
- **Example**: README "Quick Start" sections
- **AI note**: These become the default answer to "how do I use this?"

### Tutorial (Learn by doing)
- **Length**: Full walkthrough with expected output at each step
- **Format**: Steps with code examples and explanations
- **Audience**: First-time user building understanding
- **Example**: Playbook Section 1 "Build Layer"
- **AI note**: Sequential — AI must not skip or reorder steps

### How-to (Accomplish a task)
- **Length**: Focused on one specific task
- **Format**: Prerequisites → Steps → Expected Result
- **Audience**: Practitioner who knows the framework
- **Example**: SCAN prompts, agent role descriptions
- **AI note**: Can be used independently — must be self-contained

### Reference (Look up during work)
- **Length**: Comprehensive, no omissions
- **Format**: Tables, alphabetical/categorical ordering
- **Audience**: Auditor mid-review looking up a specific item
- **Example**: Attack vector tables, exploit databases, severity matrices
- **AI note**: Should be table-structured for maximum parseability

### Explanation (Understand concepts)
- **Length**: As long as needed for clarity
- **Format**: Prose with diagrams, comparisons, examples
- **Audience**: Someone asking "why does it work this way?"
- **Example**: Semantic phase analysis rationale, binding architecture explanation
- **AI note**: Provides reasoning context that prevents AI from misinterpreting rules

---

## 5. Formatting Rules

### Document Structure

```markdown
# Document Title (H1 — exactly one per file)

* Version: X.Y — description of what changed
* Status: Experimental / Stable / Deprecated
* Audience: Who this is for

---

## Major Section (H2 — main organizational unit)

### Subsection (H3 — detail level)

#### Deep detail (H4 — use sparingly)
```

### Tables vs. Prose Decision Rule

| Condition | Use Table | Use Prose |
|-----------|-----------|-----------|
| 3+ items with multiple attributes | ✓ | |
| Comparison between options | ✓ | |
| Checklist or matrix | ✓ | |
| Sequential narrative | | ✓ |
| Conceptual explanation requiring nuance | | ✓ |
| Single item with rich description | | ✓ |

### Heading Hierarchy

- `#` — Document title only (1 per file)
- `##` — Top-level sections (these are the primary navigation anchors)
- `###` — Subsections within a section
- `####` — Rarely used; consider if content belongs in a table instead
- Never skip levels (no `##` → `####`)

### Cross-Referencing

- Within same file: `see [Section Name](#section-name)` or `see Section X above`
- To another file: `see [filename.md](filename.md)` or `[filename.md, Section Name]`
- To a specific line/section: `[filename.md](filename.md#section-anchor)`
- AI citation format: `[filename, section]` — this is the binding format for findings

### Code Fences

Always specify the language:
- ` ```markdown ` for document templates
- ` ```solidity ` for Solidity examples
- ` ```bash ` for shell commands
- ` ```json ` for configuration
- ` ```text ` for plain output

---

## 6. AI-Ingestibility Patterns

### System Prompt Design (CommandInstruction files)

When writing files designed to be used as LLM system prompts:

1. **Start with role/identity** — "You are a senior smart contract security researcher"
2. **Declare authority** — AUTHORITATIVE SOURCES table with precedence
3. **State binding rules** — Numbered, non-negotiable constraints
4. **Provide checklist** — Items the AI must verify silently before output
5. **Define output format** — Explicit templates with field descriptions
6. **End with anti-patterns** — "Do NOT" list of common failure modes

### llms.txt Generation

Every framework should support generating:

- **`llms.txt`** — Title, description, and list of all pages with one-line descriptions
- **`llms-full.txt`** — Full concatenated content with clear file boundaries

Format follows the [llms.txt spec](https://llmstxt.org/):

```markdown
# Framework Name

> One-line description

## Docs

- [File title](path/to/file.md): One-line description of what this file contains
```

### Bundle File Pattern (merged.txt)

For AI agents analyzing codebases:
- Concatenate all in-scope files into a single `merged.txt`
- Add clear file boundary markers: `// === FILE: path/to/file.sol ===`
- Strip import-only files and interfaces that add noise
- This is the primary artifact AI agents analyze

---

## 7. Template Management

### The LOCAL CUSTOMIZATIONS Marker

When creating template-managed files (like CLAUDE.md), include:

```markdown
<!-- LOCAL CUSTOMIZATIONS — everything below this line is preserved on update -->
```

**Rules**:
- Template content ABOVE the marker can be auto-updated
- Content BELOW the marker is never overwritten
- Repo-specific additions go below the marker
- The marker must be preserved exactly as written

---

## 8. Security Audit Framework Specifics

### Version Bumping Checklist

When a docs change requires a version bump:

1. Update the file's own header (`* Version: X.Y`)
2. Update the ecosystem README.md
3. Update root README.md (version table, line counts)
4. Update root README.md structure diagram if files were added/removed
5. Regenerate `llms.txt` and `llms-full.txt`

### New Integration Checklist

When integrating a new external source (like Pashov, QuillAudits, etc.):

1. Create a dedicated subdirectory (e.g., `pashov-skills/`)
2. Add README.md with integration overview and comparison table
3. Adapt content (don't blindly copy) — map to existing framework concepts
4. Add cross-references to existing workflow steps
5. Update CommandInstruction (authoritative sources, role table, checklist)
6. Update Playbook (new agent section, new SCAN prompts)
7. Update methodology file (new attack vector steps)
8. Update README at ecosystem and root levels
9. Add attribution with links to source repos

### SCAN Prompt Template

Every SCAN prompt should follow this dual-audience structure:

```markdown
### SCAN [Category Name]

**Purpose**: One sentence describing what this scan detects.
**When to use**: Specific trigger conditions.
**Prerequisite**: What context must exist before running.

**Prompt**:
> [Full prompt text that works as a standalone instruction to an AI agent]

**Expected Output**:
| Field | Format |
|-------|--------|
| Finding title | `[CATEGORY-N] Brief description` |
| Severity | Critical / High / Medium / Low / Informational |
| Evidence | Code reference with line numbers |
| Impact | Quantified where possible |
```

---

## 9. Rationalizations (Do Not Skip)

| Rationalization | Why It's Wrong | Required Action |
|-----------------|----------------|-----------------|
| "AI can figure out the structure" | AI hallucinates structure when it's ambiguous | Use explicit headings and tables |
| "This is obvious to any auditor" | What's obvious to human experts is opaque to AI | Write it down explicitly |
| "Tables are too rigid" | Prose is harder to parse and more error-prone for AI | Default to tables; add prose for nuance |
| "Version bumps are busywork" | Stale versions cause AI to cite wrong capabilities | Always bump on integration |
| "I'll update the README later" | "Later" means "never" and AI agents will have stale context | Update all cross-references in the same PR |
| "The llms.txt can wait" | Stale llms.txt means AI gets incomplete framework view | Regenerate after every file change |

---

## 10. Quality Checklist

Before finalizing any documentation change, verify:

- [ ] Every `##` section has a clear one-sentence purpose
- [ ] Checklists and comparisons use tables, not bullet lists
- [ ] Code examples use language-specific fences
- [ ] Cross-references use relative markdown links
- [ ] Version is bumped in the file header, ecosystem README, and root README
- [ ] New files are added to the project structure diagram (CLAUDE.md + README)
- [ ] `llms.txt` and `llms-full.txt` are regenerated
- [ ] No orphan references (links to files that don't exist)
- [ ] Document works as both a human reference AND an AI system prompt component
