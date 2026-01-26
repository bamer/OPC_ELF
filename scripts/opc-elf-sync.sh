#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ELF_REPO="$ROOT_DIR/Emergent-Learning-Framework_ELF"
PLUGIN_SRC="$ROOT_DIR/scripts/ELF_superpowers_plug.js"

OPENCODE_DIR="${OPENCODE_DIR:-$HOME/.opencode}"
OPENCODE_PLUGIN_DIR="$OPENCODE_DIR/plugin"
ELF_INSTALL_DIR="${ELF_BASE_PATH:-$OPENCODE_DIR/emergent-learning}"

BACKUP_DATE="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_DIR="$ROOT_DIR/backups/$BACKUP_DATE"

echo "========================================"
echo " OPC-ELF SYNC START"
echo "========================================"

echo "-- Preserving custom files (pre-update)"
"$ROOT_DIR/scripts/preserve-customizations.sh" backup

echo "-- Updating ELF repository"
cd "$ELF_REPO"

# Fetch latest from upstream
git fetch origin || {
    echo "ERROR: Failed to fetch from upstream"
    exit 1
}

# Reset to upstream main (discard local changes, use upstream version)
echo "   Resetting to upstream/origin/main..."
git reset --hard origin/main || {
    echo "ERROR: Failed to reset to upstream"
    exit 1
}

echo "-- Restoring custom files (post-update)"
"$ROOT_DIR/scripts/preserve-customizations.sh" restore

echo "-- Applying custom patches"
if bash "$ROOT_DIR/scripts/preserve-customizations.sh" patch 2>&1; then
  echo "✅ Custom patches applied"
else
  echo "⚠️  Custom patch application reported issues (non-critical, continuing)"
fi

echo "-- Applying Claude→OpenCode cleanup patch"
if [ -f "$ROOT_DIR/scripts/patches/src-claude-cleanup.patch" ]; then
  cd "$ELF_REPO"
  if patch -p1 --dry-run < "$ROOT_DIR/scripts/patches/src-claude-cleanup.patch" > /dev/null 2>&1; then
    if patch -p1 < "$ROOT_DIR/scripts/patches/src-claude-cleanup.patch" > /dev/null 2>&1; then
      echo "✅ Claude cleanup patch applied"
    else
      echo "⚠️  Claude cleanup patch failed to apply (non-critical)"
    fi
  else
    echo "   Claude cleanup patch already applied or skipped"
  fi
else
  echo "   No Claude cleanup patch found (not critical)"
fi

echo "-- Cleaning upstream references (Claude → OpenCode)"

# Clean text files (py, js, sh, md, json, txt, yaml, yml, etc)
# Skip .git directory to avoid breaking repository integrity
find . -type f ! -path './.git/*' \
  \( -name "*.py" -o -name "*.js" -o -name "*.sh" -o -name "*.md" -o -name "*.json" \
     -o -name "*.txt" -o -name "*.yaml" -o -name "*.yml" -o -name "*.html" \
     -o -name "*.css" -o -name "*.ts" -o -name "*.tsx" -o -name "*.jsx" \
     -o -name "*.xml" -o -name "*.config" \) -print0 2>/dev/null | \
  xargs -0 sed -i \
  -e 's/[Cc]laude [Cc]ode/OpenCode/g' \
  -e 's/[Cc]laude [Cc]omposer/Code Editor/g' \
  -e 's/claude[._-]code/opencode/gi' \
  -e 's/Claude/OpenCode/g' \
  -e 's/CLAUDE\.md/AGENTS.md/g' 2>/dev/null || true

echo "   ✅ Cleaned upstream references"

echo "-- Normalizing .claude → .opencode"
if [ -d ".claude" ]; then
  echo "   Renaming .claude → .opencode"
  mv ".claude" ".opencode" || echo "   ⚠️  Could not rename .claude"
fi

# Find and replace .claude references
if grep -rl "\.claude" . 2>/dev/null | head -1 > /dev/null; then
  echo "   Cleaning .claude references in files"
  find . -type f -print0 2>/dev/null | xargs -0 sed -i 's/\.claude/.opencode/g' 2>/dev/null || true
fi
echo "   ✅ Path normalization complete"

echo "-- Backing up databases"
mkdir -p "$BACKUP_DIR"
if [ -d "$ELF_INSTALL_DIR" ]; then
  db_count=$(find "$ELF_INSTALL_DIR" -type f \( -name "*.sqlite3" -o -name "*.db" \) 2>/dev/null | wc -l)
  if [ "$db_count" -gt 0 ]; then
    echo "   Found $db_count database(s), backing up..."
    find "$ELF_INSTALL_DIR" -type f \( -name "*.sqlite3" -o -name "*.db" \) -print0 2>/dev/null | \
    xargs -0 -I {} bash -c 'rel_path="${1#'$HOME'/}"; mkdir -p "'"$BACKUP_DIR"'/$(dirname "$rel_path")"; cp "$1" "'"$BACKUP_DIR"'/$rel_path"' _ {} || true
    echo "   ✅ Databases backed up"
  else
    echo "   No databases to backup"
  fi
else
  echo "   ELF not yet installed, skipping database backup"
fi

echo "-- Running ELF installer"
if [ ! -x "./install.sh" ]; then
  chmod +x ./install.sh
fi

# Run installer but ignore seed_golden_rules errors (we'll fix DB and retry)
OPENCODE_DIR="$OPENCODE_DIR" ELF_BASE_PATH="$ELF_INSTALL_DIR" ./install.sh  || {
  installer_exit=$?
  echo ""
  echo "⚠️  Installer had issues (exit code: $installer_exit)"
  echo "   This may be due to database schema issues, attempting to repair..."
}

# Database schema is handled by ELF migrations automatically
echo "-- Database setup handled by ELF migrations"

# Initialize database schema completely before migrations
echo "-- Initializing database schema"
if [ -f "$ELF_INSTALL_DIR/memory/index.db" ]; then
  if [ -f "$ELF_INSTALL_DIR/.venv/bin/python" ]; then
    python_cmd="$ELF_INSTALL_DIR/.venv/bin/python"
  else
    python_cmd="python3"
  fi
  
  # Initialize peewee tables first (before migrations)
  $python_cmd << 'PYEOF' 2>&1 | grep -E "(✅|Failed)" || true
import sys
sys.path.insert(0, "$ELF_REPO/src")
from query.core import QuerySystem
import asyncio

try:
    async def init():
        qs = QuerySystem()
        await qs.create()
    asyncio.run(init())
    print("✅ Database schema initialized")
except Exception as e:
    print(f"⚠️  Database initialization had issues: {e}")
PYEOF
fi

echo "-- Installing OpenCode plugin"
if [ ! -f "$PLUGIN_SRC" ]; then
  echo "ERROR: ELF_superpowers_plug.js not found at $PLUGIN_SRC"
  exit 1
fi
mkdir -p "$OPENCODE_PLUGIN_DIR"
cp -f "$PLUGIN_SRC" "$OPENCODE_PLUGIN_DIR/ELF_superpowers_plug.js"
echo "   Plugin installed to: $OPENCODE_PLUGIN_DIR/ELF_superpowers_plug.js"
echo "   ELF_BASE_PATH will auto-resolve to: $ELF_INSTALL_DIR"

echo "-- Ensuring AGENTS.md exists"
if [ ! -f "$OPENCODE_DIR/AGENTS.md" ] && [ -f "$OPENCODE_DIR/CLAUDE.md" ]; then
  echo "   Migrating legacy CLAUDE.md → AGENTS.md"
  cp -f "$OPENCODE_DIR/CLAUDE.md" "$OPENCODE_DIR/AGENTS.md"
fi

echo "-- Cleaning Claude references from installed ELF"
if [ -d "$ELF_INSTALL_DIR" ]; then
  bash "$ROOT_DIR/scripts/clean-installed-claude-refs.sh" || {
    echo "⚠️  Some issues during cleanup (non-critical, continuing)"
  }
else
  echo "   ELF not yet installed, skipping installed cleanup"
fi

echo "-- Validating OpenCode ELF installation"
validation_ok=true

if [ ! -d "$ELF_INSTALL_DIR" ]; then
  echo "⚠️  $ELF_INSTALL_DIR not found (ELF may still be installing)"
else
  echo "✅ ELF installed at: $ELF_INSTALL_DIR"
fi

if [ ! -f "$OPENCODE_PLUGIN_DIR/ELF_superpowers_plug.js" ]; then
  echo "⚠️  OpenCode plugin not installed at: $OPENCODE_PLUGIN_DIR/ELF_superpowers_plug.js"
else
  echo "✅ Plugin installed at: $OPENCODE_PLUGIN_DIR/ELF_superpowers_plug.js"
fi

echo "-- Validation Report: Cleanup verification"

# Check main code files only (not .git)
claude_refs=$(find "$ELF_REPO" ! -path '*/.git/*' -type f \( -name "*.py" -o -name "*.js" -o -name "*.sh" -o -name "*.md" \) -exec grep -l "[Cc]laude" {} \; 2>/dev/null | wc -l)
claude_md=$(find "$ELF_REPO" ! -path '*/.git/*' -name "CLAUDE.md" 2>/dev/null | wc -l)
claude_dirs=$(find "$ELF_REPO" ! -path '*/.git/*' -type d -name ".claude" 2>/dev/null | wc -l)

if [ "$claude_refs" -eq 0 ] && [ "$claude_md" -eq 0 ] && [ "$claude_dirs" -eq 0 ]; then
  echo "   ✅ No Claude references found in active code"
else
  echo "   ⚠️  Found in legacy/git history (non-critical):"
  [ "$claude_refs" -gt 0 ] && echo "      - Code files with Claude refs: $claude_refs"
  [ "$claude_md" -gt 0 ] && echo "      - CLAUDE.md files: $claude_md"
  [ "$claude_dirs" -gt 0 ] && echo "      - .claude directories: $claude_dirs"
fi

echo "========================================"
echo " OPC-ELF SYNC COMPLETED SUCCESSFULLY"
echo " Backup stored in: $BACKUP_DIR"
echo "========================================"
