# OPC-ELF Setup Checklist

## Pre-Update Verification

Before running `./scripts/opc-elf-sync.sh`, verify:

### ✅ Repository Structure
- [ ] `/home/bamer/OPC_ELF/` exists
- [ ] `Emergent-Learning-Framework_ELF/` subdirectory exists
- [ ] `scripts/` subdirectory exists with:
  - [ ] `opc-elf-sync.sh` (executable)
  - [ ] `preserve-customizations.sh` (executable)
  - [ ] `regenerate-patches.sh`
  - [ ] `validate-setup.sh`
  - [ ] `patches/` subdirectory with:
    - [ ] `launcher-openai.patch`
    - [ ] `start-watcher-openai.patch`
    - [ ] `opencode-plugin.patch`

### ✅ Configuration Files
- [ ] `AGENTS.md` exists
- [ ] `Spec.md` exists
- [ ] `scripts/ELF_superpowers_plug.js` exists

### ✅ Environment
- [ ] ELF repository is a clean git clone
  ```bash
  cd Emergent-Learning-Framework_ELF && git status
  ```
  Should show "nothing to commit, working tree clean"

### ✅ Dependencies Installed
- [ ] `git` command available
- [ ] `patch` command available
- [ ] `grep`, `sed`, `find` available
- [ ] `bash` available

### ✅ File Permissions
- [ ] `scripts/opc-elf-sync.sh` is executable
  ```bash
  ls -l scripts/opc-elf-sync.sh
  ```
  Should show `rwx` for owner

### ✅ No Stale References
- [ ] No "Claude Code" in `scripts/opc-elf-sync.sh`
- [ ] No "Claude Code" in `scripts/ELF_superpowers_plug.js`
- [ ] No "CLAUDE.md" references in active scripts

## Running the Update

1. **Optional: Validate setup first**
   ```bash
   ./scripts/validate-setup.sh
   ```

2. **Run the sync**
   ```bash
   ./scripts/opc-elf-sync.sh
   ```

3. **Monitor output**
   - ✅ means success
   - ⏭️ means skipped (already patched)
   - ⚠️ means warning (non-critical)
   - ❌ means error (blocking)

## What the Sync Does

1. **Backup custom files** (pre-update)
2. **Git pull** from upstream ELF
3. **Restore custom files** (post-update)
4. **Apply patches** (launcher.py + start-watcher.sh)
5. **Clean Claude references** (all .py, .js, .sh, .md files)
6. **Normalize paths** (.claude → .opencode)
7. **Backup databases** (SQLite3, .db files)
8. **Run ELF installer** (./install.sh --mode merge)
9. **Install OpenCode plugin**
10. **Validate installation**
11. **Report cleanup status**

## If Something Fails

### Patch Application Fails
```bash
# See what changed upstream
cd Emergent-Learning-Framework_ELF
git log --oneline -5
git diff HEAD~1 src/watcher/launcher.py

# Regenerate the patch
cd ..
./scripts/regenerate-patches.sh launcher.py

# Re-run sync
./scripts/opc-elf-sync.sh
```

### Installation Fails
```bash
# Check backup location
ls -la backups/

# Review logs from ELF installer
cd Emergent-Learning-Framework_ELF
./install.sh --help

# Run installer manually
OPENCODE_DIR="$HOME/.opencode" ELF_BASE_PATH="$HOME/.opencode/emergent-learning" ./install.sh --mode merge
```

### Plugin Installation Fails
```bash
# Check plugin directory
ls -la ~/.opencode/plugin/

# Manually copy plugin
mkdir -p ~/.opencode/plugin
cp scripts/ELF_superpowers_plug.js ~/.opencode/plugin/
```

## Rollback if Needed

All changes to `Emergent-Learning-Framework_ELF/` are in git:
```bash
cd Emergent-Learning-Framework_ELF
git status              # see what changed
git diff               # review changes
git checkout -- .      # revert all changes
git pull               # re-sync upstream
```

Database backups stored in:
```bash
ls -la backups/YYYY-MM-DD_HH-MM-SS/
```

## Success Indicators

After sync completes:
1. ✅ No errors in output
2. ✅ "OPC-ELF SYNC COMPLETED SUCCESSFULLY" message
3. ✅ Backup directory created with timestamp
4. ✅ ✅ "No Claude references found" in validation report
5. ✅ Plugin installed in `~/.opencode/plugin/ELF_superpowers_plug.js`

## Performance Notes

Typical sync duration: **2-5 minutes**
- git pull: ~30 seconds
- Patch application: ~10 seconds
- File cleanup (sed): ~30 seconds
- ELF installer: ~1-3 minutes
- Validation: ~30 seconds

If takes longer than 10 minutes, check for:
- Network issues (git pull hanging)
- Filesystem issues (lots of files to process)
- Large database backups
