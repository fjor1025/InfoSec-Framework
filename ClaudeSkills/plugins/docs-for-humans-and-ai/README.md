# Docs for Humans and AI

Write and maintain documentation that serves both human readers and AI agents equally well.

**Based on:** [Cyfrin claude-docs-prompts](https://github.com/Cyfrin/claude-docs-prompts)

## When to Use

Use this skill when you need to:
- Write or update documentation in a security audit framework
- Create a new ecosystem framework (SolidityEVM, Rust, Cairo, etc.)
- Ensure documentation is ingestible by LLMs as system prompts or context
- Organize content following the Diataxis framework
- Generate `llms.txt` / `llms-full.txt` for AI consumption
- Review documentation for dual-audience readability

## What It Does

This skill teaches Claude to write documentation that works for both audiences:

- **Humans** — scannable structure, clear navigation, quick-reference tables, copy-paste examples
- **AI agents** — structured headings for section extraction, tables for data parsing, explicit trigger phrases, numbered sequential steps, hard constraints via "Do NOT" lists

## Key Principles

1. **Dual-audience by default** — Every paragraph, table, and heading serves both readers
2. **Structure over prose** — Tables > paragraphs for checklists, comparisons, and references
3. **Explicit over implicit** — Label everything; AI agents can't infer section purpose from context
4. **Diataxis organization** — Quickstart, Tutorial, How-to, Reference, Explanation
5. **AI ingestibility** — Generate `llms.txt` index + `llms-full.txt` concatenation
6. **Preserving markers** — Maintain `<!-- LOCAL CUSTOMIZATIONS -->` boundaries for template updates

## Installation

```
/plugin install plugins/docs-for-humans-and-ai
```

## Skills

| Skill | Purpose |
|-------|---------|
| `docs-for-humans-and-ai` | Core documentation writing standard — formatting rules, Diataxis, AI-consumable patterns |

## Related Skills

- `audit-context-building` — Deep code analysis that benefits from well-structured docs
- `spec-to-code-compliance` — Comparing code against documentation (needs good docs to compare against)
- `fix-review` — Reviewing changes that include documentation updates

## Attribution

Adapted from [Cyfrin claude-docs-prompts](https://github.com/Cyfrin/claude-docs-prompts) (MIT Licensed).
Original concept: shared `CLAUDE.md` template for Next.js documentation sites.
This adaptation generalizes the approach for pure-Markdown security audit frameworks.
