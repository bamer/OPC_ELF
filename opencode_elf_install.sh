#!/usr/bin/env bash
set -euo pipefail

# OPC-ELF Interactive Installer
# One-command setup and update for OpenCode + ELF integration

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ELF_REPO="$ROOT_DIR/Emergent-Learning-Framework_ELF"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

ask_continue() {
    local prompt="$1"
    echo -e "${YELLOW}${prompt}${NC}"
    echo "(Press ENTER to continue, or Ctrl+C to cancel)"
    read -r
}

# ============ STEP 1: VALIDATE SETUP ============
step_validate_setup() {
    print_header "STEP 1: Validating Setup"
    
    local errors=0
    
    # Check required directories
    if [ ! -d "$ELF_REPO/.git" ]; then
        print_error "ELF repository not found at $ELF_REPO"
        ((errors++))
    else
        print_success "ELF repository found"
    fi
    
    # Check required scripts (existence only, we'll call with bash)
    local scripts=(
        "scripts/opc-elf-sync.sh"
        "scripts/preserve-customizations.sh"
        "scripts/validate-setup.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$ROOT_DIR/$script" ]; then
            print_success "Found: $script"
        else
            print_error "Missing: $script"
            ((errors++))
        fi
    done
    
    # Check required patches
    local patches=(
        "scripts/patches/launcher-openai.patch"
        "scripts/patches/start-watcher-openai.patch"
        "scripts/patches/opencode-plugin.patch"
    )
    
    for patch in "${patches[@]}"; do
        if [ -f "$ROOT_DIR/$patch" ]; then
            print_success "Found: $patch"
        else
            print_error "Missing: $patch"
            ((errors++))
        fi
    done
    
    # Check dependencies
    for cmd in git patch grep sed; do
        if command -v "$cmd" &> /dev/null; then
            print_success "Found: $cmd"
        else
            print_error "Missing dependency: $cmd"
            ((errors++))
        fi
    done
    
    if [ $errors -gt 0 ]; then
        echo ""
        print_error "Setup validation failed with $errors errors"
        echo "Please fix the issues above or run ./scripts/validate-setup.sh for details"
        return 1
    fi
    
    echo ""
    print_success "Setup validation passed"
    return 0
}

# ============ STEP 2: DIAGNOSE GIT STATE ============
step_diagnose_git() {
    print_header "STEP 2: Diagnosing Git State"
    
    cd "$ELF_REPO"
    
    # Fetch latest
    echo "Fetching latest from upstream..."
    if ! git fetch origin > /dev/null 2>&1; then
        print_error "Failed to fetch from upstream"
        return 1
    fi
    
    print_success "Fetched latest from upstream"
    echo ""
    
    # Check status
    LOCAL=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    REMOTE=$(git rev-parse origin/main 2>/dev/null || echo "unknown")
    
    echo "Local commit:  ${LOCAL:0:8}"
    echo "Remote commit: ${REMOTE:0:8}"
    echo ""
    
    # Check if dirty
    if git diff-index --quiet HEAD -- 2>/dev/null; then
        print_success "Working tree is clean"
    else
        print_warning "Working tree has uncommitted changes"
        git status --short | head -3
        echo ""
        return 2
    fi
    
    # Check if diverged
    if [ "$LOCAL" = "$REMOTE" ]; then
        print_success "Branch is up to date with upstream"
        echo ""
        return 0
    else
        AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
        BEHIND=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
        
        print_warning "Branch diverges from upstream"
        echo "  Commits ahead:  $AHEAD"
        echo "  Commits behind: $BEHIND"
        echo ""
        return 1
    fi
}

# ============ STEP 3: FIX GIT STATE IF NEEDED ============
step_fix_git() {
    print_header "STEP 3: Fixing Git State"
    
    cd "$ELF_REPO"
    
    echo "Cleaning up divergent branches..."
    echo ""
    
    # Reset to origin/main
    if ! git reset --hard origin/main > /dev/null 2>&1; then
        print_error "Failed to reset to origin/main"
        return 1
    fi
    
    print_success "Reset to origin/main"
    
    # Clean untracked files
    if ! git clean -fd > /dev/null 2>&1; then
        print_warning "Could not clean some files (non-critical)"
    else
        print_success "Cleaned untracked files"
    fi
    
    echo ""
    print_success "Git state fixed"
    echo ""
    return 0
}

# ============ STEP 4: RUN SYNC ============
step_run_sync() {
    print_header "STEP 4: Running Sync"
    
    cd "$ROOT_DIR"
    
    if ! bash "$ROOT_DIR/scripts/opc-elf-sync.sh"; then
        print_error "Sync failed"
        return 1
    fi
    
    echo ""
    print_success "Sync completed successfully"
    return 0
}

# ============ MAIN FLOW ============
main() {
    print_header "OpenCode-ELF Interactive Installer"
    
    echo "This script will:"
    echo "  1. Validate your setup"
    echo "  2. Check git state"
    echo "  3. Fix git issues if needed"
    echo "  4. Run the sync"
    echo ""
    
    ask_continue "Ready to start? Press ENTER to continue..."
    
    # Step 1: Validate
    if ! step_validate_setup; then
        print_error "Setup validation failed"
        echo ""
        echo "Try running manually to see details:"
        echo "  bash $ROOT_DIR/scripts/validate-setup.sh"
        exit 1
    fi
    
    # Step 2: Diagnose
    git_status=$?
    if [ $git_status -eq 0 ]; then
        # All good, proceed to sync
        echo ""
        ask_continue "Everything looks good. Press ENTER to run sync..."
        step_run_sync
    elif [ $git_status -eq 1 ]; then
        # Divergent branches
        echo ""
        print_warning "Git state needs fixing"
        ask_continue "Press ENTER to reset to upstream and continue..."
        if step_fix_git; then
            ask_continue "Ready to run sync? Press ENTER..."
            step_run_sync
        else
            print_error "Failed to fix git state"
            exit 1
        fi
    elif [ $git_status -eq 2 ]; then
        # Dirty working tree
        echo ""
        print_warning "Git state needs attention"
        echo "(Will discard local changes and reset to upstream)"
        echo ""
        ask_continue "Press ENTER to reset to upstream and continue..."
        if step_fix_git; then
            ask_continue "Ready to run sync? Press ENTER..."
            step_run_sync
        else
            print_error "Failed to fix git state"
            exit 1
        fi
    fi
    
    # Success
    echo ""
    print_header "Installation Complete"
    echo ""
    print_success "OpenCode-ELF is ready to use"
    echo ""
    echo "Next steps:"
    echo "  - Check: ~/.opencode/plugin/ELF_superpowers_plug.js"
    echo "  - Verify: $ELF_REPO exists with latest code"
    echo ""
    echo "For future updates, run:"
    echo "  $0"
    echo ""
}

# Run main
main
