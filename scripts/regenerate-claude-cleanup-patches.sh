#!/usr/bin/env bash
set -euo pipefail

# Regenerate patches for cleaning Claude references from ELF source code
# Creates GitHub-style patches for permanent fixes

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ELF_REPO="$ROOT_DIR/Emergent-Learning-Framework_ELF"
PATCHES_DIR="$ROOT_DIR/scripts/patches"
TEMP_DIR="$ROOT_DIR/.patch-temp"

echo "========================================"
echo " REGENERATING CLAUDE CLEANUP PATCHES"
echo "========================================"

# Cleanup temp dir if exists
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Files to patch (relative to ELF_REPO)
declare -a FILES_TO_PATCH=(
  "src/elf_paths.py"
  "src/query/repair_database.py"
  "src/query/checkout.py"
  "src/conductor/executor.py"
  "src/query/query.py"
  "src/observe/__main__.py"
  "src/query/session_integration.py"
  "src/query/meta_observer.py"
  "src/query/rag_query.py"
  "src/query/setup.py"
  "src/conductor/SECURITY.md"
  "src/watcher/README.md"
  "README.md"
)

echo "-- Creating backup of original files"
for file in "${FILES_TO_PATCH[@]}"; do
  src_path="$ELF_REPO/$file"
  if [ -f "$src_path" ]; then
    dir_path=$(dirname "$file")
    mkdir -p "$TEMP_DIR/original/$dir_path"
    cp "$src_path" "$TEMP_DIR/original/$file"
  fi
done

echo "-- Creating cleaned versions"
cd "$TEMP_DIR/original"
find . -type f -print0 2>/dev/null | \
  xargs -0 sed -i \
  -e 's|~/.claude/emergent-learning|~/.opencode/emergent-learning|g' \
  -e 's|\.claude|.opencode|g' \
  -e 's/CLAUDE_SESSION_ID/OPENCODE_SESSION_ID/g' \
  -e 's/CLAUDE_AGENT_ID/OPENCODE_AGENT_ID/g' \
  -e 's/CLAUDE_SWARM_NODE/OPENCODE_SWARM_NODE/g' \
  -e 's/\["claude",/["opencode",/g' \
  -e "s/\['claude',/['opencode',/g" \
  -e 's/Claude Code/OpenCode/g' \
  -e 's/Claude/OpenCode/g' 2>/dev/null || true

# Copy cleaned files to modified directory
cp -r . "$TEMP_DIR/modified/"

echo "-- Generating patches"

# Generate individual patches
for file in "${FILES_TO_PATCH[@]}"; do
  orig_file="$TEMP_DIR/original/$file"
  mod_file="$TEMP_DIR/modified/$file"
  
  if [ -f "$orig_file" ]; then
    # Get base filename for patch name
    base_name=$(basename "$file" .py)
    patch_name="${base_name}-claude-cleanup.patch"
    patch_path="$PATCHES_DIR/$patch_name"
    
    # Create patch if files differ
    if ! diff -q "$orig_file" "$mod_file" > /dev/null 2>&1; then
      echo "   Creating: $patch_name"
      diff -u "$orig_file" "$mod_file" > "$patch_path" || true
      
      if [ -s "$patch_path" ]; then
        echo "   ✅ $patch_path ($(wc -l < "$patch_path") lines)"
      fi
    fi
  fi
done

echo ""
echo "-- Master cleanup patch (all changes in one)"
diff -u -r "$TEMP_DIR/original" "$TEMP_DIR/modified" > "$PATCHES_DIR/elf-claude-cleanup-master.patch" || true

if [ -s "$PATCHES_DIR/elf-claude-cleanup-master.patch" ]; then
  echo "   ✅ elf-claude-cleanup-master.patch ($(wc -l < "$PATCHES_DIR/elf-claude-cleanup-master.patch") lines)"
fi

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "========================================"
echo " PATCHES REGENERATED"
echo " Location: $PATCHES_DIR/"
echo "========================================"
echo ""
echo "To apply patches:"
echo "  cd $ELF_REPO"
echo "  patch -p0 < $PATCHES_DIR/elf-claude-cleanup-master.patch"
