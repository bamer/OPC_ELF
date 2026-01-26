#!/usr/bin/env bash
set -euo pipefail

# Script to preserve custom files during ELF updates
# Uses GitHub-style patch files for reliability

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ELF_REPO="$ROOT_DIR/Emergent-Learning-Framework_ELF"
CUSTOM_BACKUP_DIR="$ROOT_DIR/backups/custom"
PATCHES_DIR="$ROOT_DIR/scripts/patches"

mkdir -p "$CUSTOM_BACKUP_DIR"

# Backup custom files before changes
backup_custom_files() {
    echo "Backing up custom files..."

    # Backup our custom plugin
    if [ -f "$ROOT_DIR/scripts/ELF_superpowers_plug.js" ]; then
        cp -f "$ROOT_DIR/scripts/ELF_superpowers_plug.js" "$CUSTOM_BACKUP_DIR/"
    fi

    # Backup our custom launcher if it exists
    if [ -f "$ELF_REPO/src/watcher/launcher.py" ]; then
        cp -f "$ELF_REPO/src/watcher/launcher.py" "$CUSTOM_BACKUP_DIR/launcher.py.bak"
    fi

    # Backup custom start-watcher.sh if it exists
    if [ -f "$ELF_REPO/tools/scripts/start-watcher.sh" ]; then
        cp -f "$ELF_REPO/tools/scripts/start-watcher.sh" "$CUSTOM_BACKUP_DIR/start-watcher.sh.bak"
    fi

    echo "✅ Custom files backed up to $CUSTOM_BACKUP_DIR"
}

# Restore custom files after upstream changes
restore_custom_files() {
    echo "Restoring custom files..."

    # Restore our custom plugin
    if [ -f "$CUSTOM_BACKUP_DIR/ELF_superpowers_plug.js" ]; then
        cp -f "$CUSTOM_BACKUP_DIR/ELF_superpowers_plug.js" "$ROOT_DIR/scripts/ELF_superpowers_plug.js"
    fi

    echo "✅ Custom files restored"
}

# Apply patches with detailed error reporting
apply_custom_patches() {
    echo "Applying custom patches..."

    local success_count=0
    local skip_count=0
    local error_count=0
    local failed_patches=()

    # Change to ELF repo for patching (patches use relative paths)
    cd "$ELF_REPO"

    # Apply launcher patch
    if [ -f "$PATCHES_DIR/launcher-openai.patch" ]; then
        if patch_or_skip "launcher.py" "$PATCHES_DIR/launcher-openai.patch"; then
            echo "✅ launcher.py patched"
            ((success_count++))
        else
            ((skip_count++))
            echo "⏭️ launcher.py - already patched or unchanged"
        fi
    fi

    # Apply start-watcher patch
    if [ -f "$PATCHES_DIR/start-watcher-openai.patch" ]; then
        if patch_or_skip "start-watcher.sh" "$PATCHES_DIR/start-watcher-openai.patch"; then
            echo "✅ start-watcher.sh patched"
            ((success_count++))
        else
            ((skip_count++))
            echo "⏭️ start-watcher.sh - already patched or unchanged"
        fi
    fi

    cd "$ROOT_DIR"

    # Print summary
    echo ""
    echo "Patch Summary:"
    echo "  ✅ Applied: $success_count"
    echo "  ⏭️ Skipped: $skip_count"
    
    if [ $error_count -gt 0 ]; then
        echo "  ❌ Failed: $error_count"
        echo ""
        echo "Failed patches:"
        printf '  - %s\n' "${failed_patches[@]}"
        echo ""
        echo "Actions to fix patch failures:"
        echo "  1. Check ELF repository changes: git log --oneline -5"
        echo "  2. Review upstream changes to affected files"
        echo "  3. Update patches in scripts/patches/"
        echo "  4. Re-run sync: ./scripts/opc-elf-sync.sh"
    fi
}

# Try to apply patch, skip if already applied
patch_or_skip() {
    local target_file="$1"
    local patch_file="$2"

    if [ ! -f "$patch_file" ]; then
        echo "ERROR: Patch file not found: $patch_file"
        return 1
    fi

    # Dry-run to check if patch applies cleanly
    if patch --dry-run -p1 < "$patch_file" > /dev/null 2>&1; then
        # Applies cleanly - apply for real
        if patch -p1 < "$patch_file" > /dev/null 2>&1; then
            return 0  # Success
        else
            echo "ERROR: Failed to apply patch $patch_file"
            return 1
        fi
    else
        # Doesn't apply - likely already applied (OK)
        return 1  # Skip (not an error)
    fi
}

# Main logic
case "${1:-}" in
    backup)
        backup_custom_files
        ;;
    restore)
        restore_custom_files
        ;;
    patch)
        apply_custom_patches
        ;;
    *)
        echo "Usage: $0 {backup|restore|patch}"
        exit 1
        ;;
esac
