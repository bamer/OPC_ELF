# AGENTS.md

## Scope
- This repo wraps upstream ELF with OpenCode integration; update flow in `scripts/opc-elf-sync.sh`.

## Commands
- Sync (update + backup + install + plugin): `./scripts/opc-elf-sync.sh`
- Preserve customizations: `./scripts/preserve-customizations.sh {backup|restore|patch}`
- Upstream install (from ELF repo): `cd Emergent-Learning-Framework_ELF && ./install.sh`
- Tests (upstream): `cd Emergent-Learning-Framework_ELF && make test`
- Lint (upstream): `cd Emergent-Learning-Framework_ELF && make lint`

## Architecture
- Upstream repo: `Emergent-Learning-Framework_ELF/` (Python core + dashboard).
- OpenCode plugin: `ELF_superpowers_plug.js` copied to `~/.opencode/plugin/`.
- Update orchestration: `scripts/opc-elf-sync.sh` + backups in `backups/`.

## Style
- Shell scripts: bash strict mode (`set -euo pipefail`), keep paths configurable via env vars.
- JS plugin: avoid hardcoded home paths; derive from `OPENCODE_DIR`/`ELF_BASE_PATH`.
