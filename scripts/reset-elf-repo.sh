#!/usr/bin/env bash
set -euo pipefail

# Reset ELF repository to clean upstream state
# Run this if you have divergent branches or local changes you want to discard

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ELF_REPO="$ROOT_DIR/Emergent-Learning-Framework_ELF"

if [ ! -d "$ELF_REPO/.git" ]; then
    echo "ERROR: ELF repository not found at $ELF_REPO"
    exit 1
fi

echo "========================================"
echo " RESET ELF REPOSITORY TO UPSTREAM"
echo "========================================"
echo ""
echo "This will:"
echo "  1. Discard ALL local changes to ELF files"
echo "  2. Fetch latest from upstream"
echo "  3. Reset to upstream/origin/main"
echo ""
echo "Your custom files are NOT affected (in backups/custom/)"
echo ""
read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted"
    exit 0
fi

cd "$ELF_REPO"

echo ""
echo "-- Fetching from upstream..."
git fetch origin || {
    echo "ERROR: Failed to fetch"
    exit 1
}

echo "-- Resetting to origin/main..."
git reset --hard origin/main || {
    echo "ERROR: Failed to reset"
    exit 1
}

echo "-- Cleaning untracked files..."
git clean -fd || true

echo ""
echo "✅ ELF repository reset to clean upstream state"
echo ""
echo "Next steps:"
echo "  1. Run: cd $ROOT_DIR"
echo "  2. Run: ./scripts/opc-elf-sync.sh"
