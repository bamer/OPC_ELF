#!/usr/bin/env bash
set -euo pipefail

# Clean Claude references from the INSTALLED ELF directory (~/.opencode/emergent-learning)
# This complements opc-elf-sync.sh which only cleans the ELF repo source

OPENCODE_DIR="${OPENCODE_DIR:-$HOME/.opencode}"
ELF_INSTALL_DIR="${ELF_BASE_PATH:-$OPENCODE_DIR/emergent-learning}"

echo "========================================"
echo " CLEANING INSTALLED CLAUDE REFERENCES"
echo "========================================"
echo "Target directory: $ELF_INSTALL_DIR"

if [ ! -d "$ELF_INSTALL_DIR" ]; then
  echo "ERROR: $ELF_INSTALL_DIR not found"
  exit 1
fi

cd "$ELF_INSTALL_DIR"

echo "-- Phase 1: Replace string references (Claude → OpenCode)"

# Python files: Path references like ~/.claude/emergent-learning
find . -type f -name "*.py" -print0 2>/dev/null | \
  xargs -0 sed -i \
  -e 's|~/.claude/emergent-learning|~/.opencode/emergent-learning|g' \
  -e 's|\.claude|.opencode|g' \
  -e 's/\[Cc\]laude [Cc\]ode/OpenCode/g' \
  -e 's/\[Cc\]laude [Cc\]omposer/Code Editor/g' \
  -e 's/claude[._-]code/opencode/gi' \
  -e 's/Claude/OpenCode/g' \
  -e 's/CLAUDE\.md/AGENTS.md/g' 2>/dev/null || true

# Markdown files
find . -type f -name "*.md" -print0 2>/dev/null | \
  xargs -0 sed -i \
  -e 's|~/.claude/emergent-learning|~/.opencode/emergent-learning|g' \
  -e 's|\.claude|.opencode|g' \
  -e 's/\[Cc\]laude [Cc\]ode/OpenCode/g' \
  -e 's/\[Cc\]laude [Cc\]omposer/Code Editor/g' \
  -e 's/claude[._-]code/opencode/gi' \
  -e 's/Claude/OpenCode/g' \
  -e 's/CLAUDE\.md/AGENTS.md/g' 2>/dev/null || true

# Config files (yaml, json, txt, sql, sh)
find . -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" \
                  -o -name "*.txt" -o -name "*.sql" -o -name "*.sh" \
                  -o -name "*.js" -o -name "*.ts" -o -name "*.html" \) \
  -print0 2>/dev/null | \
  xargs -0 sed -i \
  -e 's|~/.claude/emergent-learning|~/.opencode/emergent-learning|g' \
  -e 's|\.claude|.opencode|g' \
  -e 's/\[Cc\]laude [Cc\]ode/OpenCode/g' \
  -e 's/\[Cc\]laude [Cc\]omposer/Code Editor/g' \
  -e 's/claude[._-]code/opencode/gi' \
  -e 's/Claude/OpenCode/g' \
  -e 's/CLAUDE\.md/AGENTS.md/g' 2>/dev/null || true

echo "   ✅ String references updated"

echo "-- Phase 2: Handle environment variables"

# Replace env var references
find . -type f \( -name "*.py" -o -name "*.js" -o -name "*.sh" \) -print0 2>/dev/null | \
  xargs -0 sed -i \
  -e "s/CLAUDE_SESSION_ID/OPENCODE_SESSION_ID/g" \
  -e "s/CLAUDE_AGENT_ID/OPENCODE_AGENT_ID/g" \
  -e "s/CLAUDE_SWARM_NODE/OPENCODE_SWARM_NODE/g" 2>/dev/null || true

echo "   ✅ Environment variables updated"

echo "-- Phase 3: Handle CLI references"

# Replace claude CLI calls with opencode (where applicable)
# Note: Some 'claude' references in strings/comments are legitimate (e.g., "claude-3-opus")
# Only replace CLI command calls
find . -type f \( -name "*.py" -o -name "*.js" -o -name "*.sh" \) -print0 2>/dev/null | \
  xargs -0 sed -i \
  -e 's/\["claude",/["opencode",/g' \
  -e "s/\['claude',/['opencode',/g" \
  -e 's/cmd = \["claude"/cmd = ["opencode"/g' \
  -e "s/cmd = \['claude'/cmd = ['opencode'/g" 2>/dev/null || true

echo "   ✅ CLI references updated"

echo "-- Phase 4: Verification"

# Count remaining references
remaining_claude_refs=$(find . -type f \( -name "*.py" -o -name "*.js" -o -name "*.sh" -o -name "*.md" \) \
  2>/dev/null | wc -l)

if [ "$remaining_claude_refs" -gt 0 ]; then
  echo "   ✅ Scanned $remaining_claude_refs text files"
  
  # Show top problematic references
  sample_refs=$(find . -type f \( -name "*.py" -o -name "*.js" -o -name "*.sh" -o -name "*.md" \) \
    -exec grep -l "\.claude" {} \; 2>/dev/null | head -5)
  
  if [ -n "$sample_refs" ]; then
    echo "   ⚠️  Found .claude path references in:"
    echo "$sample_refs" | while read f; do echo "      $f"; done
  fi
else
  echo "   ✅ Scan complete"
fi

# Check for .claude directories
dotclaude_dirs=$(find . -type d -name ".claude" 2>/dev/null | wc -l)
if [ "$dotclaude_dirs" -gt 0 ]; then
  echo "   ⚠️  Found $dotclaude_dirs .claude directories, removing..."
  find . -type d -name ".claude" -exec rm -rf {} + 2>/dev/null || true
fi

echo ""
echo "========================================"
echo " CLEANUP COMPLETE"
echo " Target: $ELF_INSTALL_DIR"
echo "========================================"
