#!/usr/bin/env bash
# build-llms-txt.sh — Generate llms.txt and llms-full.txt for AI consumption
# Following the llms.txt spec: https://llmstxt.org/
#
# Usage: ./scripts/build-llms-txt.sh
# Run from the InfoSec-Framework root directory.
#
# Outputs:
#   llms.txt      — Index of all framework pages with descriptions
#   llms-full.txt — Full concatenated content with file boundaries

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

LLMS_TXT="llms.txt"
LLMS_FULL="llms-full.txt"

echo "Building llms.txt and llms-full.txt from $(pwd)..."

# --- llms.txt ---
cat > "$LLMS_TXT" << 'HEADER'
# InfoSec-Framework — Audit Assistant Playbook

> A structured audit framework for smart contract security across 8 blockchain ecosystems. Binding architecture that forces AI agents into structured audit behavior. ~42,000+ lines of methodology, attack vectors, and conversation prompts.

## Core

HEADER

# Function: extract first meaningful line after the H1 as description
get_description() {
    local file="$1"
    # Try to get the first line that starts with > (blockquote description)
    local desc
    desc=$(grep -m1 '^>' "$file" 2>/dev/null | sed 's/^> *//' | head -c 200 || true)
    if [ -n "$desc" ]; then
        echo "$desc"
        return
    fi
    # Fall back to first non-empty, non-heading, non-marker line
    desc=$(grep -m1 -v '^#\|^$\|^---\|^<!--\|^\*' "$file" 2>/dev/null | head -c 200 || true)
    if [ -n "$desc" ]; then
        echo "$desc"
        return
    fi
    echo "Documentation file"
}

# Root-level files
for f in README.md CLAUDE.md report-writing.md VULNERABILITY_PATTERNS_INTEGRATION.md; do
    if [ -f "$f" ]; then
        desc=$(get_description "$f")
        echo "- [$f]($f): $desc" >> "$LLMS_TXT"
    fi
done

# Ecosystem frameworks
echo "" >> "$LLMS_TXT"
echo "## SolidityEVM (Benchmark Framework)" >> "$LLMS_TXT"
echo "" >> "$LLMS_TXT"
for f in SolidityEVM/CLAUDE.md SolidityEVM/README.md SolidityEVM/CommandInstruction.md SolidityEVM/audit-workflow1.md SolidityEVM/audit-workflow2.md SolidityEVM/Audit_Assistant_Playbook.md SolidityEVM/vault_audit_guide.md; do
    if [ -f "$f" ]; then
        desc=$(get_description "$f")
        echo "- [$f]($f): $desc" >> "$LLMS_TXT"
    fi
done

# Pashov skills
if [ -d "SolidityEVM/pashov-skills" ]; then
    echo "" >> "$LLMS_TXT"
    echo "### Pashov Audit Group Integration" >> "$LLMS_TXT"
    echo "" >> "$LLMS_TXT"
    find SolidityEVM/pashov-skills -name '*.md' -type f | sort | while read -r f; do
        desc=$(get_description "$f")
        echo "- [$f]($f): $desc" >> "$LLMS_TXT"
    done
fi

# Other ecosystem frameworks
for ecosystem in RustBaseSmartContract Go-SmartContract Cosmos-SDK Cairo-StarkNet Algorand-PyTeal TON-FunC Move Nemesis; do
    if [ -d "$ecosystem" ]; then
        echo "" >> "$LLMS_TXT"
        echo "## $ecosystem" >> "$LLMS_TXT"
        echo "" >> "$LLMS_TXT"
        find "$ecosystem" -name '*.md' -type f | sort | while read -r f; do
            desc=$(get_description "$f")
            echo "- [$f]($f): $desc" >> "$LLMS_TXT"
        done
    fi
done

# ClaudeSkills plugins (top-level only)
if [ -d "ClaudeSkills/plugins" ]; then
    echo "" >> "$LLMS_TXT"
    echo "## ClaudeSkills Plugins" >> "$LLMS_TXT"
    echo "" >> "$LLMS_TXT"
    for plugin_dir in ClaudeSkills/plugins/*/; do
        plugin_name=$(basename "$plugin_dir")
        readme="${plugin_dir}README.md"
        if [ -f "$readme" ]; then
            desc=$(get_description "$readme")
            echo "- [$readme]($readme): $desc" >> "$LLMS_TXT"
        fi
    done
fi

echo "" >> "$LLMS_TXT"
echo "---" >> "$LLMS_TXT"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$LLMS_TXT"

echo "  Created $LLMS_TXT ($(wc -l < "$LLMS_TXT") lines)"

# --- llms-full.txt ---
: > "$LLMS_FULL"

echo "# InfoSec-Framework — Full Content" >> "$LLMS_FULL"
echo "" >> "$LLMS_FULL"
echo "> Auto-generated concatenation of all framework files for AI consumption." >> "$LLMS_FULL"
echo "> Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$LLMS_FULL"
echo "" >> "$LLMS_FULL"

# Concatenate all .md files in a sensible order
file_list=(
    # Root
    README.md
    CLAUDE.md
    report-writing.md
    VULNERABILITY_PATTERNS_INTEGRATION.md
    # SolidityEVM (benchmark, most important)
    SolidityEVM/README.md
    SolidityEVM/CommandInstruction.md
    SolidityEVM/audit-workflow1.md
    SolidityEVM/audit-workflow2.md
    SolidityEVM/Audit_Assistant_Playbook.md
    SolidityEVM/vault_audit_guide.md
)

# Add pashov-skills files
if [ -d "SolidityEVM/pashov-skills" ]; then
    while IFS= read -r f; do
        file_list+=("$f")
    done < <(find SolidityEVM/pashov-skills -name '*.md' -type f | sort)
fi

# Add other ecosystems
for ecosystem in RustBaseSmartContract Go-SmartContract Cosmos-SDK Cairo-StarkNet Algorand-PyTeal TON-FunC Move Nemesis; do
    if [ -d "$ecosystem" ]; then
        while IFS= read -r f; do
            file_list+=("$f")
        done < <(find "$ecosystem" -name '*.md' -type f | sort)
    fi
done

# Concatenate with clear file boundaries
for f in "${file_list[@]}"; do
    if [ -f "$f" ]; then
        echo "================================================================" >> "$LLMS_FULL"
        echo "FILE: $f" >> "$LLMS_FULL"
        echo "================================================================" >> "$LLMS_FULL"
        echo "" >> "$LLMS_FULL"
        cat "$f" >> "$LLMS_FULL"
        echo "" >> "$LLMS_FULL"
        echo "" >> "$LLMS_FULL"
    fi
done

line_count=$(wc -l < "$LLMS_FULL")
size_kb=$(( $(wc -c < "$LLMS_FULL") / 1024 ))
echo "  Created $LLMS_FULL ($line_count lines, ${size_kb}KB)"
echo ""
echo "Done. Commit both files to version control."
