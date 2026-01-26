#!/usr/bin/env bash
set -euo pipefail

# Diagnose git state of ELF repository
# Shows branches, divergence, and what needs to be done

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ELF_REPO="$ROOT_DIR/Emergent-Learning-Framework_ELF"

if [ ! -d "$ELF_REPO/.git" ]; then
    echo "ERROR: ELF repository not found at $ELF_REPO"
    exit 1
fi

cd "$ELF_REPO"

echo "========================================"
echo " GIT STATE DIAGNOSIS"
echo "========================================"
echo ""

# Fetch latest info
echo "Fetching latest from upstream..."
git fetch origin > /dev/null 2>&1 || {
    echo "ERROR: Failed to fetch from upstream"
    exit 1
}

echo "Current branch:"
git rev-parse --abbrev-ref HEAD
echo ""

echo "Local commit:"
LOCAL_COMMIT=$(git rev-parse HEAD)
echo "  $LOCAL_COMMIT"
echo ""

echo "Remote (origin/main) commit:"
REMOTE_COMMIT=$(git rev-parse origin/main)
echo "  $REMOTE_COMMIT"
echo ""

echo "Status:"
if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
    echo "  ✅ Up to date with upstream"
else
    # Count commits ahead/behind
    AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
    BEHIND=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
    
    echo "  ⚠️ Local branch diverges from upstream"
    echo "     - Commits ahead:  $AHEAD"
    echo "     - Commits behind: $BEHIND"
fi
echo ""

echo "Working tree status:"
if git diff-index --quiet HEAD --; then
    echo "  ✅ Clean (no uncommitted changes)"
else
    echo "  ⚠️ Dirty (has uncommitted changes)"
    git status --short | head -5
fi
echo ""

echo "Untracked files:"
UNTRACKED=$(git ls-files --others --exclude-standard | wc -l)
if [ "$UNTRACKED" -eq 0 ]; then
    echo "  ✅ None"
else
    echo "  ⚠️ $UNTRACKED untracked files"
    git ls-files --others --exclude-standard | head -5
fi
echo ""

echo "Recent commits:"
git log --oneline -3
echo ""

echo "Recommendations:"
if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ] || ! git diff-index --quiet HEAD --; then
    echo "  1. Run: ./scripts/reset-elf-repo.sh"
    echo "  2. Then: ./scripts/opc-elf-sync.sh"
else
    echo "  ✅ Repository is ready for sync"
    echo "  Run: ./scripts/opc-elf-sync.sh"
fi
