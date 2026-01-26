# OpenCode-ELF Integration

Automated synchronization and patching for the **Emergent-Learning-Framework_ELF** with **OpenCode** compatibility.

## 🚀 Quick Start

```bash
bash opencode_elf_install.sh
```

That's it. One interactive command that:
- ✅ Validates your setup
- ✅ Checks git state
- ✅ Fixes divergent branches if needed
- ✅ Syncs with upstream
- ✅ Removes Claude references
- ✅ Applies OpenCode patches
- ✅ Installs the OpenCode plugin

## What It Does

Each run:

1. **Backs up** custom files (pre-update)
2. **Fetches** latest from upstream ELF repository
3. **Restores** your customizations (post-update)
4. **Applies** OpenCode-specific patches
5. **Cleans** all Claude references (text, files, paths)
6. **Backs up** databases with timestamp
7. **Installs** ELF with merged customizations
8. **Installs** OpenCode plugin
9. **Validates** everything is correct

## Files

| What | Where | Purpose |
|------|-------|---------|
| **Installer** | `opencode_elf_install.sh` | One-command interactive setup |
| **Validation** | `scripts/validate-setup.sh` | Pre-flight system checks |
| **Diagnosis** | `scripts/diagnose-git-state.sh` | Check git health |
| **Reset** | `scripts/reset-elf-repo.sh` | Fix divergent branches |
| **Main sync** | `scripts/opc-elf-sync.sh` | Core synchronization |
| **Guides** | `QUICK_START.md` | Getting started |
| | `SETUP_CHECKLIST.md` | Manual verification |
| | `AGENTS.md` | Commands & troubleshooting |

## Environment

Optional (defaults work fine):

```bash
export OPENCODE_DIR=/custom/path/.opencode
export ELF_BASE_PATH=/custom/path/elf
./opencode_elf_install.sh
```

## Safe to Use

- ✅ Multiple runs safe (already-applied patches skipped)
- ✅ Dry-run for patches (never breaks files)
- ✅ Timestamped backups for recovery
- ✅ Git-based rollback possible
- ✅ Non-blocking errors (continues on patch issues)

## System State

Current setup: **100% Operational**

- ✅ All scripts working
- ✅ All patches verified
- ✅ All documentation complete
- ✅ Ready for production use

## Troubleshooting

```bash
# Check system status
./scripts/validate-setup.sh

# Check git health
./scripts/diagnose-git-state.sh

# Fix divergent branches
./scripts/reset-elf-repo.sh

# View detailed guides
cat QUICK_START.md
cat AGENTS.md
cat SETUP_CHECKLIST.md
```

## Architecture

```
OpenCode-ELF
├── Sync Strategy: git fetch + reset --hard (reliable)
├── Patch System: GNU patch with --dry-run (safe)
├── Cleanup: sed for text refs + rename for files (fast)
├── Backup: Timestamped per-run + custom files (recoverable)
├── Installation: ELF ./install.sh --mode merge (integrated)
└── Plugin: OpenCode-compatible (no Claude refs)
```

## For Developers

See:
- `IMPLEMENTATION_SUMMARY.md` - Full architecture
- `Spec.md` - Technical details
- `AGENTS.md` - Commands and style
- `VERIFICATION_REPORT.md` - What's been tested

## Next Steps

```bash
# First time
./opencode_elf_install.sh

# Regular updates
./opencode_elf_install.sh

# Check git health anytime
./scripts/diagnose-git-state.sh

# Manual intervention if needed
./scripts/reset-elf-repo.sh
```

## License & Attribution

This wrapper integrates:
- **Emergent-Learning-Framework_ELF** - [Spacehunterz/ELF](https://github.com/Spacehunterz/Emergent-Learning-Framework_ELF)
- **OpenCode** - Local AI code editor integration

## Status

🟢 **Ready for Production**

All features implemented, tested, and documented.
