#!/usr/bin/env bash
set -euo pipefail

# OPC-ELF Sync Script
# Clean, minimal sync for always-fresh repo
# 
# Workflow:
# 1. Reset to upstream (repo always fresh)
# 2. Backup existing data
# 3. Install ELF with ELF_BASE_PATH env var
# 4. Install plugin + symlink
# 5. Verify setup

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ELF_REPO="$ROOT_DIR/Emergent-Learning-Framework_ELF"
PLUGIN_SRC="$ROOT_DIR/scripts/ELF_superpowers.js"

OPENCODE_DIR="${OPENCODE_DIR:-$HOME/.opencode}"
OPENCODE_PLUGIN_DIR="$OPENCODE_DIR/plugins"
ELF_INSTALL_DIR="${ELF_BASE_PATH:-$OPENCODE_DIR/emergent-learning}"

BACKUP_DATE="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_DIR="$ROOT_DIR/backups/$BACKUP_DATE"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_ok() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_header "OPC-ELF SYNC"

# ============ STEP 1: Reset to Upstream ============
print_header "STEP 1: Reset Repository"

cd "$ELF_REPO"

echo "Resetting to origin/main..."
git fetch origin || {
    echo "ERROR: Failed to fetch from upstream"
    exit 1
}

git reset --hard origin/main || {
    echo "ERROR: Failed to reset to upstream"
    exit 1
}

print_ok "Repository reset to upstream"

# Apply custom patches
if [ -d "$ROOT_DIR/scripts/patches" ]; then
    for patch_file in "$ROOT_DIR/scripts/patches"/*.patch; do
        if [ -f "$patch_file" ]; then
            patch_name="$(basename "$patch_file")"
            echo "Applying patch: $patch_name"
            if patch -p1 --dry-run < "$patch_file" > /dev/null 2>&1; then
                patch -p1 < "$patch_file" || echo "Warning: Patch $patch_name failed"
            else
                echo "Warning: Patch $patch_name would fail, skipping"
            fi
        fi
    done
fi

# ============ STEP 2: Backup Data ============
print_header "STEP 2: Backup Existing Data"

if [ -d "$ELF_INSTALL_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    
    db_count=$(find "$ELF_INSTALL_DIR" -type f \( -name "*.sqlite3" -o -name "*.db" \) 2>/dev/null | wc -l)
    if [ "$db_count" -gt 0 ]; then
        echo "Found $db_count database(s), backing up..."
        find "$ELF_INSTALL_DIR" -type f \( -name "*.sqlite3" -o -name "*.db" \) -print0 2>/dev/null | \
        xargs -0 -I {} bash -c 'rel_path="${1#'$HOME'/}"; mkdir -p "'"$BACKUP_DIR"'/$(dirname "$rel_path")"; cp "$1" "'"$BACKUP_DIR"'/$rel_path"' _ {} || true
        print_ok "Databases backed up to: $BACKUP_DIR"
    else
        echo "No databases to backup"
    fi
else
    echo "ELF not yet installed, skipping backup"
fi

# ============ STEP 3: Install ELF ============
print_header "STEP 3: Install ELF Framework"

chmod 755 "$ELF_REPO/install.sh" "$ELF_REPO/tools/setup/install.sh" 2>/dev/null || true

echo "Installing ELF to: $ELF_INSTALL_DIR"
OPENCODE_DIR="$OPENCODE_DIR" ELF_BASE_PATH="$ELF_INSTALL_DIR" "$ELF_REPO/install.sh" || {
    installer_exit=$?
    print_warn "ELF installer exited with code: $installer_exit"
    echo "Check above for details, but continuing anyway..."
}

if [ -d "$ELF_INSTALL_DIR" ]; then
    print_ok "ELF installed to: $ELF_INSTALL_DIR"
else
    echo "ERROR: ELF installation failed"
    exit 1
fi

# ============ STEP 4: Install Plugin ============
print_header "STEP 4: Install OpenCode Plugin"

if [ ! -f "$PLUGIN_SRC" ]; then
    print_warn "Plugin source not found at: $PLUGIN_SRC"
else
    PLUGIN_ELF_DST="$ELF_INSTALL_DIR/ELF_superpowers.js"
    
    # Copy plugin to ELF root
    cp -f "$PLUGIN_SRC" "$PLUGIN_ELF_DST"
    print_ok "Plugin copied to: $PLUGIN_ELF_DST"
    
    # Create symlink in .opencode/plugins
    mkdir -p "$OPENCODE_PLUGIN_DIR"
    rm -f "$OPENCODE_PLUGIN_DIR/ELF_superpowers.js" "$OPENCODE_PLUGIN_DIR/ELF_superpowers_plug.js"
    ln -sf "$PLUGIN_ELF_DST" "$OPENCODE_PLUGIN_DIR/ELF_superpowers.js"
    print_ok "Plugin symlinked to: $OPENCODE_PLUGIN_DIR/ELF_superpowers.js"
fi

# ============ STEP 5: Verify Setup ============
print_header "STEP 5: Verify Setup"

verification_ok=true

if [ -d "$ELF_INSTALL_DIR" ]; then
    print_ok "ELF installed at: $ELF_INSTALL_DIR"
else
    print_warn "ELF directory not found"
    verification_ok=false
fi

if [ -f "$PLUGIN_ELF_DST" ]; then
    print_ok "Plugin installed at: $PLUGIN_ELF_DST"
else
    print_warn "Plugin not found at: $PLUGIN_ELF_DST"
fi

if [ -L "$OPENCODE_PLUGIN_DIR/ELF_superpowers.js" ] || [ -f "$OPENCODE_PLUGIN_DIR/ELF_superpowers.js" ]; then
    print_ok "Plugin symlink OK at: $OPENCODE_PLUGIN_DIR/ELF_superpowers.js"
else
    print_warn "Plugin symlink not found"
fi

if [ "$verification_ok" = true ]; then
    print_header "✅ SYNC COMPLETED SUCCESSFULLY"
    echo ""
    echo "Backup: $BACKUP_DIR"
    echo "ELF:    $ELF_INSTALL_DIR"
    echo ""
    echo "Next: Start OpenCode and call /elf_activate in any session to enable ELF"
    echo ""
else
    print_header "⚠️  SYNC COMPLETED WITH WARNINGS"
    echo "Check above for details"
    exit 1
fi
