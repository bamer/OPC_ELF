# Quick Start Guide

## TL;DR - Run This Now

```bash
cd /home/bamer/OPC_ELF
bash opencode_elf_install.sh
```

It's interactive - just answer the prompts!

Expected output should show:
```
========================================
 OPC-ELF SYNC COMPLETED SUCCESSFULLY
 Backup stored in: backups/YYYY-MM-DD_HH-MM-SS
========================================
```

With final checks showing:
```
✅ No Claude references found in ELF repository
```

## What Just Happened

The sync automatically:
1. ✅ Backed up your custom files
2. ✅ Updated from upstream ELF repository
3. ✅ Applied OpenCode patches
4. ✅ Removed all Claude references
5. ✅ Installed the OpenCode plugin
6. ✅ Backed up databases

## Verify It Worked

```bash
# Check backup was created
ls -la backups/ | head -5

# Check plugin installed
ls -la ~/.opencode/plugin/ELF_superpowers_plug.js

# Check no Claude references remain (should output nothing)
grep -r "Claude" Emergent-Learning-Framework_ELF --include="*.py" --include="*.js" --include="*.sh" --include="*.md" 2>/dev/null | head -5
```

## If Something Failed

The installer handles most cases, but for advanced troubleshooting:

### Manual validation
```bash
./scripts/validate-setup.sh
```

### Manual git diagnosis
```bash
./scripts/diagnose-git-state.sh
```

### Manual git reset
```bash
./scripts/reset-elf-repo.sh
```

### Manual sync
```bash
./scripts/opc-elf-sync.sh
```

## Environment Variables (Optional)

```bash
# Use custom OpenCode directory
export OPENCODE_DIR=/custom/path/.opencode
export ELF_BASE_PATH=/custom/path/elf

# Then run
./scripts/opc-elf-sync.sh
```

## Common Questions

**Q: Can I run this multiple times?**
A: Yes! Safe to run. Already-applied patches are skipped.

**Q: Will it overwrite my changes?**
A: Only changes to ELF repo files. Your custom files are backed up first, restored after. If you edited files directly in `Emergent-Learning-Framework_ELF/`, they will be lost but can be restored from `backups/custom/`.

**Q: What if internet is slow?**
A: `git pull` might take time, rest is local (fast).

**Q: Where are databases backed up?**
A: `backups/YYYY-MM-DD_HH-MM-SS/` with timestamp.

**Q: Can I use different OpenCode install?**
A: Yes, set `OPENCODE_DIR` and `ELF_BASE_PATH` env vars.

**Q: How long does it take?**
A: Typically 2-5 minutes (depends on internet speed).

## Next Steps

1. **For detailed info**: Read `SETUP_CHECKLIST.md`
2. **For troubleshooting**: See `AGENTS.md` → "If Patches Fail During Sync"
3. **For architecture**: See `Spec.md`
4. **For full details**: See `IMPLEMENTATION_SUMMARY.md`

## Still Having Issues?

Check these in order:
1. Run `./scripts/validate-setup.sh` → tells you what's wrong
2. Review logs from last sync
3. Check `AGENTS.md` for your specific error
4. See `SETUP_CHECKLIST.md` for manual fixes
5. Review `IMPLEMENTATION_SUMMARY.md` → "Error Scenarios & Recovery"
