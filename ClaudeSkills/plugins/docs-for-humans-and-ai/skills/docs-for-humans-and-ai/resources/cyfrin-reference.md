# Cyfrin claude-docs-prompts — Reference

> Source: [github.com/Cyfrin/claude-docs-prompts](https://github.com/Cyfrin/claude-docs-prompts)
> License: Assumed open-source (cloned from public repo)
> Purpose: Original patterns that this skill adapts for security audit frameworks

## What claude-docs-prompts Does

A shared `CLAUDE.md` template for Cyfrin documentation sites. Gives AI agents consistent instructions across all docs repos.

## Key Concepts Extracted

### 1. Template + Local Customizations Pattern

Documents split into two zones:
- **Template zone** (above marker) — auto-updated from upstream
- **Local zone** (below marker) — preserved across updates

Marker: `<!-- LOCAL CUSTOMIZATIONS — everything below this line is preserved on update -->`

### 2. Required Features for AI-Consumable Docs

| Feature | Cyfrin Implementation | InfoSec Adaptation |
|---------|----------------------|-------------------|
| **llms.txt** | `scripts/build-llms-txt.ts` generates page index | `scripts/build-llms-txt.sh` generates markdown index |
| **llms-full.txt** | Full concatenated content | Full concatenated framework content |
| **Copy page as Markdown** | PageActions dropdown in UI | Already markdown-native — no adaptation needed |
| **Open in ChatGPT/Claude** | URL encoding page content | CommandInstruction files ARE the system prompt |
| **Edit This Page** | GitHub edit URL construction | Standard GitHub markdown editing |
| **Broken Link Checker** | `scripts/check-links.ts` | Could add as future enhancement |
| **Search Index** | `scripts/build-search-index.ts` | `llms.txt` serves as the search index |

### 3. Diataxis Framework

Content organization by purpose:
- **Quickstart** → zero to aha moment
- **Tutorials** → learn by doing
- **How-tos** → accomplish a specific task
- **Reference** → look up during work
- **Explanation** → deepen understanding

### 4. Technical Conventions (Adapted)

| Cyfrin Convention | InfoSec Adaptation |
|-------------------|-------------------|
| MDX content format | Pure Markdown (no JSX) |
| Tailwind CSS styling | No styling — plain markdown |
| `lucide-react` icons | No icons |
| Pin actions to SHA | N/A (no CI/CD currently) |
| Pin exact versions in package.json | N/A (no npm dependencies) |
| TypeScript scripts in `scripts/` | Bash scripts in `scripts/` |

### 5. `.docs-config.json` Pattern

Repo-specific configuration separated from template:

```json
{
  "github_repo": "owner/repo",
  "github_branch": "main",
  "production_url": "https://example.com",
  "site_title": "Site Name",
  "site_description": "Description"
}
```

InfoSec equivalent: The root `README.md` serves this purpose (no JSON config needed for a pure-markdown repo).

## Install Script Pattern

The original install pattern (`curl | bash`) with:
1. Download latest template
2. Preserve local customizations
3. Create config if missing
4. Interactive prompts for required values

For InfoSec-Framework, this pattern could be adapted if the framework is ever published as a template that other teams install and customize.
