#!/usr/bin/env bash
set -euo pipefail

# Comprehensive validation of OPC-ELF setup
# Run this before starting an update

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ELF_REPO="$ROOT_DIR/Emergent-Learning-Framework_ELF"
PATCHES_DIR="$ROOT_DIR/scripts/patches"

ERRORS=0
WARNINGS=0

echo "=========================================="
echo " OPC-ELF SETUP VALIDATION"
echo "=========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_file() {
    local file="$1"
    local description="$2"
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅${NC} $description"
        return 0
    else
        echo -e "${RED}❌${NC} $description (missing: $file)"
        ((ERRORS++))
        return 1
    fi
}

check_dir() {
    local dir="$1"
    local description="$2"
    
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✅${NC} $description"
        return 0
    else
        echo -e "${RED}❌${NC} $description (missing: $dir)"
        ((ERRORS++))
        return 1
    fi
}

check_executable() {
    local file="$1"
    local description="$2"
    
    if [ -x "$file" ]; then
        echo -e "${GREEN}✅${NC} $description"
        return 0
    else
        echo -e "${YELLOW}⚠️${NC} $description not executable (will be made executable during sync)"
        ((WARNINGS++))
        return 1
    fi
}

# === Core Structure ===
echo "Core Structure:"
check_dir "$ELF_REPO" "  ELF repository cloned"
check_dir "$PATCHES_DIR" "  Patches directory"
check_dir "$ROOT_DIR/backups" "  Backups directory"
check_dir "$ROOT_DIR/memory" "  Memory directory"
echo ""

# === Main Scripts ===
echo "Main Scripts:"
check_executable "$ROOT_DIR/scripts/opc-elf-sync.sh" "  opc-elf-sync.sh"
check_executable "$ROOT_DIR/scripts/preserve-customizations.sh" "  preserve-customizations.sh"
check_file "$ROOT_DIR/scripts/regenerate-patches.sh" "  regenerate-patches.sh"
echo ""

# === Patch Files ===
echo "Patch Files:"
check_file "$PATCHES_DIR/launcher-openai.patch" "  launcher-openai.patch"
check_file "$PATCHES_DIR/start-watcher-openai.patch" "  start-watcher-openai.patch"
check_file "$PATCHES_DIR/opencode-plugin.patch" "  opencode-plugin.patch"
echo ""

# === Configuration Files ===
echo "Configuration Files:"
check_file "$ROOT_DIR/AGENTS.md" "  AGENTS.md"
check_file "$ROOT_DIR/Spec.md" "  Spec.md"
echo ""

# === Plugin Files ===
echo "Plugin Files:"
check_file "$ROOT_DIR/scripts/ELF_superpowers_plug.js" "  ELF_superpowers_plug.js"
echo ""

# === Environment Variables ===
echo "Environment Variables (optional, defaults are fine):"
if [ -n "${OPENCODE_DIR:-}" ]; then
    echo -e "${GREEN}✅${NC}  OPENCODE_DIR set: $OPENCODE_DIR"
else
    echo -e "${YELLOW}⚠️${NC}  OPENCODE_DIR not set (will use ~/.opencode)"
    ((WARNINGS++))
fi

if [ -n "${ELF_BASE_PATH:-}" ]; then
    echo -e "${GREEN}✅${NC}  ELF_BASE_PATH set: $ELF_BASE_PATH"
else
    echo -e "${YELLOW}⚠️${NC}  ELF_BASE_PATH not set (will use \$OPENCODE_DIR/emergent-learning)"
    ((WARNINGS++))
fi
echo ""

# === Dependency Checks ===
echo "Dependencies:"
for cmd in git patch grep find sed; do
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✅${NC}  $cmd available"
    else
        echo -e "${RED}❌${NC}  $cmd not found"
        ((ERRORS++))
    fi
done
echo ""

# === Git Status ===
echo "Git Status:"
if [ -d "$ELF_REPO/.git" ]; then
    echo -e "${GREEN}✅${NC}  ELF repository is a git clone"
    
    # Check if dirty
    cd "$ELF_REPO"
    if git diff-index --quiet HEAD -- 2>/dev/null; then
        echo -e "${GREEN}✅${NC}  ELF repository working tree is clean"
    else
        echo -e "${YELLOW}⚠️${NC}  ELF repository has uncommitted changes"
        ((WARNINGS++))
    fi
    cd "$ROOT_DIR"
else
    echo -e "${RED}❌${NC}  ELF repository is not a git clone"
    ((ERRORS++))
fi
echo ""

# === Critical File Checks ===
echo "Critical File Content Checks:"

# Check for Claude references in our custom files
echo -n "  Checking opc-elf-sync.sh for Claude references... "
if grep -q "Claude Code" "$ROOT_DIR/scripts/opc-elf-sync.sh" 2>/dev/null; then
    echo -e "${YELLOW}⚠️ Found Claude references${NC}"
    ((WARNINGS++))
else
    echo -e "${GREEN}✅${NC}"
fi

echo -n "  Checking ELF_superpowers_plug.js for Claude references... "
if grep -q "Claude Code" "$ROOT_DIR/scripts/ELF_superpowers_plug.js" 2>/dev/null; then
    echo -e "${YELLOW}⚠️ Found Claude references${NC}"
    ((WARNINGS++))
else
    echo -e "${GREEN}✅${NC}"
fi

echo -n "  Checking Spec.md for Claude Code references... "
if grep -q "Claude Code" "$ROOT_DIR/Spec.md" 2>/dev/null; then
    echo -e "${YELLOW}⚠️ Found Claude Code references${NC}"
    ((WARNINGS++))
else
    echo -e "${GREEN}✅${NC}"
fi
echo ""

# === Backup Status ===
echo "Backup Status:"
if [ -d "$ROOT_DIR/backups/custom" ]; then
    backup_count=$(find "$ROOT_DIR/backups/custom" -type f 2>/dev/null | wc -l)
    if [ "$backup_count" -gt 0 ]; then
        echo -e "${GREEN}✅${NC}  Custom backups exist ($backup_count files)"
    else
        echo -e "${YELLOW}⚠️${NC}  Custom backup directory exists but is empty"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠️${NC}  Custom backup directory not created yet (will be created on first sync)"
    ((WARNINGS++))
fi
echo ""

# === Summary ===
echo "=========================================="
echo " VALIDATION SUMMARY"
echo "=========================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ System is READY for update${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Run: cd $ROOT_DIR"
    echo "  2. Run: ./scripts/opc-elf-sync.sh"
    exit 0
elif [ $ERRORS -eq 0 ] && [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️ System is operational with $WARNINGS warning(s)${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review warnings above"
    echo "  2. Run: cd $ROOT_DIR"
    echo "  3. Run: ./scripts/opc-elf-sync.sh"
    exit 0
else
    echo -e "${RED}❌ System has $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Please fix the errors above before running sync"
    exit 1
fi
