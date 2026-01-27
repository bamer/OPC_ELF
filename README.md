# OpenCode + ELF Integration

Clean, minimal integration of the Emergent Learning Framework with OpenCode.

## Quick Start

```bash
bash opencode_elf_install.sh
```

Then in OpenCode, call `/elf_activate` in any session to enable ELF hooks.

## What This Does

- **Installs ELF** to `~/.opencode/emergent-learning` with proper path resolution
- **Adds plugin** for automatic learning from tool outputs  
- **Lazy activation** - no contamination until you explicitly enable it
- **Auto backup** of existing data before updates

## Documentation

- **[WORKFLOW.md](WORKFLOW.md)** - Installation and sync workflow
- **[AGENTS.md](AGENTS.md)** - Project directives and commands

## Repository Structure

```
├── opencode_elf_install.sh      # Interactive installer
├── scripts/
│   ├── opc-elf-sync.sh          # Sync script (reset → backup → install → plugin → verify)
│   ├── ELF_superpowers.js       # OpenCode plugin source
│   └── patches-optional/        # Future enhancement patches
├── Emergent-Learning-Framework_ELF/  # Upstream ELF repo (always clean)
└── backups/                     # Auto-generated backups
```

## How It Works

1. **Always Fresh** - ELF repo reset to upstream on each sync
2. **Paths via Env** - `ELF_BASE_PATH` env var handles all path resolution (no patches needed)
3. **Plugin Separate** - OpenCode plugin lives in OPC_ELF, installed to ELF root, symlinked
4. **Lazy Hooks** - Plugin inactive until `/elf_activate` called
5. **Data Safe** - Databases backed up before install

## For Developers

To update:
```bash
./scripts/opc-elf-sync.sh
```

To test Python scripts directly:
```bash
cd ~/.opencode/emergent-learning
ELF_BASE_PATH=$PWD .venv/bin/python src/query/query.py --context
```

## Key Design Principles

- ✅ Zero contamination until explicitly enabled
- ✅ No patches or post-processing (ELF_BASE_PATH handles it)
- ✅ Plugin independent of ELF codebase
- ✅ Data always preserved
- ✅ Repo always in clean state
