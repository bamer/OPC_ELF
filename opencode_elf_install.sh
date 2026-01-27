#!/usr/bin/env bash
set -euo pipefail

# OPC-ELF Interactive Installer
# Simple setup: just run the sync

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_DIR="$ROOT_DIR/scripts"

echo ""
echo "========================================"
echo "  OpenCode-ELF Interactive Installer"
echo "========================================"
echo ""
echo "This will:"
echo "  1. Reset ELF repo to upstream"
echo "  2. Backup existing data"
echo "  3. Install ELF framework"
echo "  4. Install OpenCode plugin"
echo ""

read -p "Ready to install? (press ENTER to continue or Ctrl+C to cancel) " -r

echo ""
bash "$SCRIPT_DIR/opc-elf-sync.sh"

exit_code=$?

echo ""
if [ $exit_code -eq 0 ]; then
    echo "========================================"
    echo "✅ Installation Complete"
    echo "========================================"
    echo ""
    echo "Next steps:"
    echo "  1. Start OpenCode"
    echo "  2. In any session, type: /elf_activate"
    echo "  3. ELF hooks will be enabled"
    echo ""
else
    echo "========================================"
    echo "⚠️  Installation had issues"
    echo "========================================"
    echo ""
    echo "Check output above for details"
    exit $exit_code
fi
