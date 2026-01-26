# Scripts Guide

## Entry Points

### 🎯 Main Entry Point (Use This First)

```bash
./opencode_elf_install.sh
```

**Interactive installer** - Handles everything:
- Validates setup
- Diagnoses git state
- Fixes issues if needed
- Runs sync
- Reports status

Use this for regular updates.

---

## Advanced Scripts (If Needed)

### Validation

```bash
./scripts/validate-setup.sh
```

**Pre-flight checker** - Verifies:
- All required files exist
- Scripts are executable
- Dependencies available (git, patch, grep, etc)
- ELF repo is clean
- No Claude references in critical files

Use before troubleshooting.

### Git Diagnosis

```bash
./scripts/diagnose-git-state.sh
```

**Git health check** - Shows:
- Local vs remote commits
- Divergence status
- Uncommitted changes
- Untracked files
- Recommendations

Use if sync fails with git errors.

### Git Reset

```bash
./scripts/reset-elf-repo.sh
```

**Fix divergent branches** - Does:
- Fetches latest from upstream
- Resets to origin/main
- Cleans untracked files

Use when `diagnose-git-state.sh` shows divergence.

### Manual Sync

```bash
./scripts/opc-elf-sync.sh
```

**Core synchronization** - Performs:
- Backup custom files
- Git fetch + reset
- Restore customizations
- Apply patches
- Clean Claude references
- Install ELF
- Install plugin
- Validate

Use if installer fails or you prefer manual control.

### Patch Regeneration

```bash
./scripts/regenerate-patches.sh launcher.py
./scripts/regenerate-patches.sh start-watcher.sh
```

**Regenerate patches** - Creates new patch files when upstream changes.

Use when patches fail after upstream update.

### File Preservation

```bash
./scripts/preserve-customizations.sh {backup|restore|patch}
```

**Manual backup/restore** - Low-level control:
- `backup` - Backup custom files before update
- `restore` - Restore custom files after update
- `patch` - Apply patches manually

Use for manual intervention.

---

## Decision Tree

```
START
  ↓
[Run opencode_elf_install.sh]
  ↓
Installation succeeds?
  ├─ YES → ✅ Done
  └─ NO → Proceed below
      ↓
Issue type?
  ├─ Setup/files missing
  │   └─ ./scripts/validate-setup.sh
  │
  ├─ Git divergence
  │   └─ ./scripts/diagnose-git-state.sh
  │       └─ Issues? → ./scripts/reset-elf-repo.sh
  │
  ├─ Patch failure
  │   └─ ./scripts/regenerate-patches.sh <file>
  │       └─ ./opencode_elf_install.sh (retry)
  │
  └─ Unknown
      └─ Manual:
          1. Check logs from opencode_elf_install.sh
          2. Run ./scripts/validate-setup.sh
          3. See AGENTS.md → troubleshooting
```

---

## Typical Workflows

### First-Time Setup

```bash
./opencode_elf_install.sh
```

That's it.

### Regular Updates

```bash
./opencode_elf_install.sh
```

Same as first-time.

### After Upstream Breaks Patches

```bash
# See what changed
cd Emergent-Learning-Framework_ELF
git log --oneline -3

# Regenerate patches
cd ..
./scripts/regenerate-patches.sh launcher.py
./scripts/regenerate-patches.sh start-watcher.sh

# Retry sync
./opencode_elf_install.sh
```

### Emergency Rollback

```bash
# Revert all ELF changes
cd Emergent-Learning-Framework_ELF
git reset --hard HEAD~1

# Or use our helper
cd ..
./scripts/reset-elf-repo.sh
```

### Manual Verification

```bash
./scripts/validate-setup.sh
./scripts/diagnose-git-state.sh
```

Then read the output carefully.

---

## Script Dependencies

```
opencode_elf_install.sh
  ├─ scripts/validate-setup.sh
  ├─ scripts/diagnose-git-state.sh
  ├─ scripts/reset-elf-repo.sh
  └─ scripts/opc-elf-sync.sh
      ├─ scripts/preserve-customizations.sh
      │   └─ scripts/patches/*.patch
      └─ Emergent-Learning-Framework_ELF/install.sh
```

All scripts use only standard tools:
- `bash`
- `git`
- `patch`
- `sed`
- `grep`
- `find`

No external dependencies or APIs.

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (actionable, see message) |
| 2 | Needs attention (git dirty, etc) |

All scripts print clear error messages.

---

## Logging

All scripts log to stdout (no log files).

To save output:

```bash
./opencode_elf_install.sh 2>&1 | tee install.log
```

Then review:

```bash
cat install.log
```

---

## Environment Variables

Optional configuration:

```bash
export OPENCODE_DIR=/custom/path/.opencode
export ELF_BASE_PATH=/custom/path/elf

./opencode_elf_install.sh
```

If not set, defaults:
- `OPENCODE_DIR` → `$HOME/.opencode`
- `ELF_BASE_PATH` → `$OPENCODE_DIR/emergent-learning`

---

## Troubleshooting Commands

```bash
# What's wrong with my setup?
./scripts/validate-setup.sh

# What's the git status?
./scripts/diagnose-git-state.sh

# Show recent commits
cd Emergent-Learning-Framework_ELF
git log --oneline -10

# Show recent changes
git diff HEAD~1

# Check if patches apply
cd ..
git apply --check scripts/patches/launcher-openai.patch

# See what the sync would do (dry run not available, but check output)
./scripts/opc-elf-sync.sh 2>&1 | head -50
```

---

## Common Issues & Solutions

**Issue: "git pull" fails with divergent branches**
```bash
./scripts/reset-elf-repo.sh
```

**Issue: Patches don't apply**
```bash
cd Emergent-Learning-Framework_ELF
git log --oneline -5
git diff HEAD~1 src/watcher/launcher.py
cd ..
./scripts/regenerate-patches.sh launcher.py
./opencode_elf_install.sh
```

**Issue: "validate-setup.sh" fails**
```bash
# Read the output carefully, it tells you what's missing
./scripts/validate-setup.sh
# Fix the issues shown
./opencode_elf_install.sh
```

**Issue: Plugin not installed**
```bash
# Check if installed
ls ~/.opencode/plugin/ELF_superpowers_plug.js

# Manually install if missing
mkdir -p ~/.opencode/plugin
cp scripts/ELF_superpowers_plug.js ~/.opencode/plugin/
```

**Issue: Databases not backed up**
```bash
# Backups stored here with timestamps
ls -la backups/
```

---

## Script Maintenance

All scripts follow:
- ✅ Bash strict mode (`set -euo pipefail`)
- ✅ Clear error messages
- ✅ Proper quoting for paths with spaces
- ✅ No hardcoded paths (use env vars)
- ✅ Idempotent (safe to run multiple times)

To modify scripts:
1. Edit in `scripts/` directory
2. Test with `bash -n script.sh` (syntax check)
3. Test with actual run
4. Update this guide if behavior changes

---

## Getting Help

1. **Quick answer**: See this file
2. **Getting started**: See `QUICK_START.md`
3. **Detailed info**: See `IMPLEMENTATION_SUMMARY.md`
4. **Troubleshooting**: See `AGENTS.md` → "If Patches Fail"
5. **Verification**: See `VERIFICATION_REPORT.md`
6. **Technical**: See `Spec.md`

---

Last updated: 2026-01-26
