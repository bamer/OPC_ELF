#!/usr/bin/env bash
# Quick fix: Make all scripts executable

chmod +x ./opencode_elf_install.sh
chmod +x ./scripts/opc-elf-sync.sh
chmod +x ./scripts/preserve-customizations.sh
chmod +x ./scripts/validate-setup.sh
chmod +x ./scripts/regenerate-patches.sh
chmod +x ./scripts/reset-elf-repo.sh
chmod +x ./scripts/diagnose-git-state.sh

echo "✅ All scripts are now executable"
echo ""
echo "You can now run:"
echo "  ./opencode_elf_install.sh"
