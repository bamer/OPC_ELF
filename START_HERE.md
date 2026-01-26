# START HERE

You just cloned/downloaded OPC-ELF. Follow these steps:

## Step 1: Run the Installer

```bash
cd /home/bamer/OPC_ELF
bash opencode_elf_install.sh
```

The installer will:
1. Ask questions (just answer yes/no)
2. Validate everything
3. Check git state
4. Fix any issues
5. Run the sync
6. Show success/error

## Step 2: Done!

If you see:
```
========================================
 Installation Complete
========================================

✅ OpenCode-ELF is ready to use
```

Then you're done. The system is set up.

## What Gets Installed

After running the installer:

- ✅ Latest ELF code from upstream
- ✅ OpenCode compatibility patches applied
- ✅ All Claude references removed
- ✅ Plugin installed at: `~/.opencode/plugin/ELF_superpowers_plug.js`
- ✅ Databases backed up with timestamp

## For Future Updates

Just run again:

```bash
./opencode_elf_install.sh
```

It's safe to run multiple times. Patches that are already applied will be skipped.

## If Something Goes Wrong

See the troubleshooting:

```bash
# Check if setup is valid
./scripts/validate-setup.sh

# Check git health
./scripts/diagnose-git-state.sh

# Fix git issues
./scripts/reset-elf-repo.sh

# Manual sync (if needed)
./scripts/opc-elf-sync.sh
```

Or read the detailed guides:
- `QUICK_START.md` - Getting started
- `AGENTS.md` - Commands & help
- `SETUP_CHECKLIST.md` - Manual verification

## That's It!

You're ready to use OpenCode with ELF integration.

Next steps depend on your workflow:
- If you're developing, see the ELF repo: `Emergent-Learning-Framework_ELF/`
- If you're using OpenCode, the plugin is ready: `~/.opencode/plugin/`
- For advanced setup, see `README.md`

---

Questions? See:
- `README.md` - Overview
- `QUICK_START.md` - Getting started
- `SCRIPTS_GUIDE.md` - What each script does
- `AGENTS.md` - Commands reference
