#!/usr/bin/env bash
# Simple test script to debug the sync

set -u  # Exit on undefined variables, but not -e for better error capture

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ELF_REPO="$ROOT_DIR/Emergent-Learning-Framework_ELF"

echo "=================================================="
echo "Testing OPC-ELF Sync"
echo "=================================================="
echo ""
echo "Test environment:"
echo "  ROOT_DIR: $ROOT_DIR"
echo "  ELF_REPO: $ELF_REPO"
echo "  Bash version: $BASH_VERSION"
echo ""

# Check if ELF repo exists
if [ ! -d "$ELF_REPO/.git" ]; then
    echo "ERROR: ELF repository not found"
    exit 1
fi

echo "✅ ELF repo found"
echo ""

# Test 1: Find Python/JS/SH/MD files
echo "Test 1: Counting files..."
cd "$ELF_REPO"
py_count=$(find . -name "*.py" -type f 2>/dev/null | wc -l)
js_count=$(find . -name "*.js" -type f 2>/dev/null | wc -l)
sh_count=$(find . -name "*.sh" -type f 2>/dev/null | wc -l)
md_count=$(find . -name "*.md" -type f 2>/dev/null | wc -l)
total=$((py_count + js_count + sh_count + md_count))

echo "  Python files: $py_count"
echo "  JavaScript files: $js_count"
echo "  Shell scripts: $sh_count"
echo "  Markdown files: $md_count"
echo "  Total: $total files"
echo "✅ File counting works"
echo ""

# Test 2: Test sed with xargs
echo "Test 2: Testing sed with xargs..."
test_file="/tmp/test_opc_elf.txt"
echo "This is Claude Code test" > "$test_file"
echo "Testing .claude path" >> "$test_file"

if find "$test_file" -type f -print0 | xargs -0 sed -i 's/Claude/OpenCode/g; s/\.claude/.opencode/g'; then
    result=$(cat "$test_file")
    if echo "$result" | grep -q "OpenCode"; then
        echo "✅ sed with xargs works"
    else
        echo "ERROR: sed didn't replace text properly"
        cat "$test_file"
    fi
else
    echo "ERROR: sed with xargs failed"
fi
rm -f "$test_file"
echo ""

# Test 3: Test grep for Claude references
echo "Test 3: Testing grep for Claude references..."
cd "$ELF_REPO"
ref_count=$(grep -r "Claude" . --include="*.py" --include="*.js" --include="*.sh" --include="*.md" 2>/dev/null | wc -l)
echo "  Found $ref_count Claude references"
if [ "$ref_count" -gt 0 ]; then
    echo "  Sample references:"
    grep -r "Claude" . --include="*.py" --include="*.js" --include="*.sh" --include="*.md" 2>/dev/null | head -3
fi
echo "✅ Grep works"
echo ""

# Test 4: Run actual sync
echo "Test 4: Running actual sync..."
cd "$ROOT_DIR"
if bash ./scripts/opc-elf-sync.sh 2>&1 | tee /tmp/sync_output.log; then
    echo ""
    echo "✅ SYNC COMPLETED SUCCESSFULLY"
else
    exit_code=$?
    echo ""
    echo "⚠️  Sync exited with code: $exit_code"
    echo ""
    echo "Last 20 lines of output:"
    tail -20 /tmp/sync_output.log
fi

echo ""
echo "=================================================="
echo "Test complete"
echo "=================================================="
