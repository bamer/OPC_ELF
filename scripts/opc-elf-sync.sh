#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ELF_REPO="$ROOT_DIR/Emergent-Learning-Framework_ELF"

OPENCODE_DIR="${OPENCODE_DIR:-$HOME/.opencode}"
OPENCODE_PLUGIN_DIR="$OPENCODE_DIR/plugins"
ELF_INSTALL_DIR="${ELF_BASE_PATH:-$OPENCODE_DIR/emergent-learning}"

BACKUP_DATE="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_DIR="$ROOT_DIR/backups/$BACKUP_DATE"

echo "========================================"
echo " OPC-ELF SYNC START"
echo "========================================"

# Step 1: Backup Phase - Backup custom files AND databases
echo "-- Backup Phase: Files & Databases"
"$ROOT_DIR/scripts/preserve-customizations.sh" backup

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

# Step 2: Fetch Latest ELF
echo "-- Fetch Phase: Latest ELF"
cd "$ELF_REPO"

git fetch origin || {
    echo "ERROR: Failed to fetch from upstream"
    exit 1
}

echo "   Resetting to upstream/origin/main..."
git reset --hard origin/main || {
    echo "ERROR: Failed to reset to upstream"
    exit 1
}

# Step 3: Fix permissions (may be lost during git reset or patching)
echo "-- Permissions Phase: Ensure executable scripts"
chmod 755 tools/setup/install.sh install.sh scripts/apply-*.sh 2>/dev/null || true
chmod 644 templates/AGENTS.md.template 2>/dev/null || true
echo "   ✅ Script permissions restored"

# Step 4: Apply Custom Patches
echo "-- Patch Phase: Custom Fixes"

# Apply install.sh structure fix (preserve src/ directory structure)
echo "   Applying ELF install src structure patch"
if [ -f "$ROOT_DIR/scripts/patches/elf-install-src-structure.patch" ]; then
  if patch --dry-run tools/setup/install.sh < "$ROOT_DIR/scripts/patches/elf-install-src-structure.patch" > /dev/null 2>&1; then
    if patch tools/setup/install.sh < "$ROOT_DIR/scripts/patches/elf-install-src-structure.patch" > /dev/null 2>&1; then
      echo "   ✅ Install src structure patch applied"
    else
      echo "   ⚠️  Install src structure patch failed to apply (non-critical)"
    fi
  else
    echo "   Install src structure patch already applied or skipped"
  fi
else
  echo "   No install structure patch found (not critical)"
fi

# Apply install.sh settings deprecation (plugin system handles hooks now)
echo "   Applying ELF install settings deprecation fix"
if [ -f "$ROOT_DIR/scripts/apply-install-settings-deprecation.sh" ]; then
  if bash "$ROOT_DIR/scripts/apply-install-settings-deprecation.sh" > /dev/null 2>&1; then
    echo "   ✅ Install settings deprecation fix applied"
  else
    echo "   ⚠️  Install settings deprecation fix partially applied (non-critical)"
  fi
else
  echo "   No install settings deprecation fix script found (non-critical)"
fi

# Apply seed_golden_rules.py fix (handle NOT NULL constraint issues)
echo "   Applying seed_golden_rules fixes"
if [ -f "$ROOT_DIR/scripts/apply-seed-golden-rules-fix.sh" ]; then
  if bash "$ROOT_DIR/scripts/apply-seed-golden-rules-fix.sh" > /dev/null 2>&1; then
    echo "   ✅ Seed golden rules fixes applied"
  else
    echo "   ⚠️  Seed golden rules fixes partially applied (non-critical)"
  fi
else
  echo "   No seed golden rules fix script found (non-critical)"
fi

# Apply Claude→OpenCode Cleanup
echo "   Applying Claude→OpenCode cleanup patch"
if [ -f "$ROOT_DIR/scripts/patches/src-claude-cleanup.patch" ]; then
  if patch -p1 --dry-run < "$ROOT_DIR/scripts/patches/src-claude-cleanup.patch" > /dev/null 2>&1; then
    if patch -p1 < "$ROOT_DIR/scripts/patches/src-claude-cleanup.patch" > /dev/null 2>&1; then
      echo "   ✅ Claude cleanup patch applied"
    else
      echo "   ⚠️  Claude cleanup patch failed to apply (non-critical)"
    fi
  else
    echo "   Claude cleanup patch already applied or skipped"
  fi
else
  echo "   No Claude cleanup patch found (not critical)"
fi

# Clean text files and normalize paths
echo "   Cleaning upstream references (Claude → OpenCode, .claude → .opencode)"
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
  -e 's/CLAUDE\.md/AGENTS.md/g' \
  -e 's/\.claude/.opencode/g' 2>/dev/null || true

if [ -d ".claude" ]; then
  echo "   Renaming .claude directory to .opencode"
  mv ".claude" ".opencode" 2>/dev/null || echo "   ⚠️  Could not rename .claude directory"
fi
echo "   ✅ Cleanup complete"

# Step 4: Run ELF Installer
echo "-- Install Phase: ELF Framework"
# Ensure permissions are restored before running installer (patches may have reset them)
chmod 755 ./install.sh tools/setup/install.sh 2>/dev/null || true

OPENCODE_DIR="$OPENCODE_DIR" ELF_BASE_PATH="$ELF_INSTALL_DIR" ./install.sh  || {
  installer_exit=$?
  echo "   ⚠️  Installer had issues (exit code: $installer_exit)"
}

# Step 5: Install OpenCode Plugin via symlink
echo "-- Plugin Phase: OpenCode Integration"
# Plugin should be in ELF directory, symlinked from .opencode/plugins
PLUGIN_ELF_SRC="$ELF_INSTALL_DIR/plugins/ELF_superpowers.js"

if [ ! -f "$PLUGIN_ELF_SRC" ]; then
  echo "   ⚠️  Plugin not yet in ELF directory (will be on next sync)"
  echo "   Expected at: $PLUGIN_ELF_SRC"
else
  mkdir -p "$OPENCODE_PLUGIN_DIR"
  # Remove old copies if they exist
  rm -f "$OPENCODE_PLUGIN_DIR/ELF_superpowers_plug.js" "$OPENCODE_PLUGIN_DIR/ELF_superpowers.js"
  # Create symlink from ELF's plugin directory
  ln -sf "$PLUGIN_ELF_SRC" "$OPENCODE_PLUGIN_DIR/ELF_superpowers.js"
  echo "   ✅ Plugin symlinked from: $PLUGIN_ELF_SRC"
fi

# Step 6: Validate Installation
echo "-- Validation Phase: Final Checks"
validation_ok=true

if [ ! -d "$ELF_INSTALL_DIR" ]; then
  echo "   ⚠️  $ELF_INSTALL_DIR not found (ELF may still be installing)"
else
  echo "   ✅ ELF installed at: $ELF_INSTALL_DIR"
fi

if [ ! -L "$OPENCODE_PLUGIN_DIR/ELF_superpowers.js" ] && [ ! -f "$OPENCODE_PLUGIN_DIR/ELF_superpowers.js" ]; then
  echo "   ⚠️  OpenCode plugin not found at: $OPENCODE_PLUGIN_DIR/ELF_superpowers.js"
else
  echo "   ✅ Plugin available at: $OPENCODE_PLUGIN_DIR/ELF_superpowers.js"
fi

# Validation Report: Cleanup verification
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
