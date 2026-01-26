#!/usr/bin/env bash
set -euo pipefail

# Helper script to regenerate patches when upstream changes
# Usage: ./scripts/regenerate-patches.sh <filename>
# Example: ./scripts/regenerate-patches.sh launcher.py

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ELF_REPO="$ROOT_DIR/Emergent-Learning-Framework_ELF"
PATCHES_DIR="$ROOT_DIR/scripts/patches"
BACKUPS_DIR="$ROOT_DIR/backups/custom"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <filename>"
    echo ""
    echo "Examples:"
    echo "  $0 launcher.py          # Generate launcher-openai.patch"
    echo "  $0 start-watcher.sh     # Generate start-watcher-openai.patch"
    echo ""
    echo "This compares the backup (original custom version) with the current"
    echo "upstream file and creates a GitHub-style patch."
    exit 1
fi

FILENAME="$1"

# Determine backup file and patch file
case "$FILENAME" in
    launcher.py)
        BACKUP_FILE="$BACKUPS_DIR/launcher.py.bak"
        PATCH_FILE="$PATCHES_DIR/launcher-openai.patch"
        UPSTREAM_FILE="$ELF_REPO/src/watcher/launcher.py"
        ;;
    start-watcher.sh)
        BACKUP_FILE="$BACKUPS_DIR/start-watcher.sh.bak"
        PATCH_FILE="$PATCHES_DIR/start-watcher-openai.patch"
        UPSTREAM_FILE="$ELF_REPO/tools/scripts/start-watcher.sh"
        ;;
    *)
        echo "ERROR: Unknown file: $FILENAME"
        echo "Supported: launcher.py, start-watcher.sh"
        exit 1
        ;;
esac

# Validate files exist
if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file not found: $BACKUP_FILE"
    exit 1
fi

if [ ! -f "$UPSTREAM_FILE" ]; then
    echo "ERROR: Upstream file not found: $UPSTREAM_FILE"
    exit 1
fi

# Generate patch
echo "Generating patch for $FILENAME..."
echo "  Backup: $BACKUP_FILE"
echo "  Current: $UPSTREAM_FILE"
echo "  Patch output: $PATCH_FILE"
echo ""

# Use diff to create the patch
if diff -u "$BACKUP_FILE" "$UPSTREAM_FILE" > "$PATCH_FILE" || true; then
    lines=$(wc -l < "$PATCH_FILE")
    echo "✅ Patch generated: $lines lines"
    echo ""
    echo "Next steps:"
    echo "  1. Review the patch: cat $PATCH_FILE"
    echo "  2. If it looks good, re-run sync: ./scripts/opc-elf-sync.sh"
else
    echo "ERROR: Failed to generate patch"
    exit 1
fi
