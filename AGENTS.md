# AGENTS.md

## Scope
- This repo wraps upstream ELF with OpenCode integration; update flow in `scripts/opc-elf-sync.sh`.
- Automatically removes Claude references from upstream files during sync.

## Commands
- **Main installer** (use this): `bash opencode_elf_install.sh` (interactive, validates, diagnoses, fixes, syncs)
- **Validate setup**: `./scripts/validate-setup.sh` (optional, for troubleshooting)
- **Sync** (update + backup + clean + install + plugin symlink): `./scripts/opc-elf-sync.sh`
  - Performs git fetch, resets to upstream, cleans Claude references, applies patches, symlinks plugin (lazy-activated), validates cleanup
  - Plugin auto-installs in ELF directory, symlinked from ~/.opencode/plugins (no contamination until /elf_activate)
- **Clean installed Claude refs** (if .opencode/emergent-learning still has Claude paths): `OPENCODE_DIR=$HOME/.opencode ELF_BASE_PATH=$HOME/.opencode/emergent-learning bash ./scripts/clean-installed-claude-refs.sh`
- **Fix database** (if integrity issues): `OPENCODE_DIR=$HOME/.opencode ELF_BASE_PATH=$HOME/.opencode/emergent-learning bash ./scripts/fix-database.sh`
  - Repairs NULL values in NOT NULL columns, backs up database
- **Preserve customizations**: `./scripts/preserve-customizations.sh {backup|restore|patch}`
- **Regenerate patches** (if upstream changed): `./scripts/regenerate-patches.sh {launcher.py|start-watcher.sh}`
- **Reset ELF repo** (if branches diverged): `./scripts/reset-elf-repo.sh`
  - Discards local ELF changes, resets to clean upstream state
- Upstream install (from ELF repo): `cd Emergent-Learning-Framework_ELF && ./install.sh`
- Tests (upstream): `cd Emergent-Learning-Framework_ELF && make test`
- Lint (upstream): `cd Emergent-Learning-Framework_ELF && make lint`

## GitHub-Style Patches
- Patch directory: `scripts/patches/` contains GitHub-style patch files
- `src-claude-cleanup.patch`: Converts all Claude references to OpenCode paths (`.claude` → `.opencode`, env vars, etc)
- `launcher-openai.patch`: Adds OpenAI-compatible launcher for watcher
- `start-watcher-openai.patch`: Adds OpenAI/OpenCode watcher support
- `opencode-plugin.patch`: Adds OpenCode plugin with ELF hooks

## If Patches Fail During Sync
1. **Check what changed upstream**: `cd Emergent-Learning-Framework_ELF && git log --oneline -5`
2. **Review affected file changes**: `git diff HEAD~1 src/watcher/launcher.py`
3. **Update the patch file** in `scripts/patches/` with new context
4. **Re-generate patches**: `diff -u original/ modified/ > scripts/patches/filename.patch`
5. **Re-run sync**: `./scripts/opc-elf-sync.sh`

Note: Patches use `--dry-run` first, so they won't break files. If a patch fails, it's reported in the output and sync continues (non-critical).

## Git Update Strategy
- Uses `git fetch` + `git reset --hard origin/main` to sync
- **Discards local changes** in ELF repo (safe: custom files backed up separately)
- Avoids "divergent branches" errors from merge/rebase conflicts
- Always uses upstream as source of truth
- If you've made direct edits to ELF files, they will be lost - restore from `backups/custom/`

## Style
- Shell scripts: bash strict mode (`set -euo pipefail`), keep paths configurable via env vars.
- JS plugin: avoid hardcoded home paths; derive from `OPENCODE_DIR`/`ELF_BASE_PATH`.
