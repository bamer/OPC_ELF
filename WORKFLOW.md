# OPC-ELF Installation & Sync Workflow

Clean, minimal workflow for installing and updating ELF with OpenCode integration.

## Installation

```bash
bash opencode_elf_install.sh
```

This runs the sync script once, which:
1. **Reset**: Repo to origin/main (always fresh)
2. **Backup**: Existing databases
3. **Install**: ELF framework with `ELF_BASE_PATH` env var
4. **Plugin**: Copy to ELF root + symlink in ~/.opencode/plugins
5. **Verify**: All components installed correctly

## Updates

```bash
./scripts/opc-elf-sync.sh
```

Same workflow as above - use for regular updates.

## Directory Structure

```
OPC_ELF/
  scripts/
    ELF_superpowers.js    ← Plugin source (version controlled)
    opc-elf-sync.sh       ← Sync script

Emergent-Learning-Framework_ELF/
  ← Clean upstream copy, no modifications

~/.opencode/
  emergent-learning/
    ELF_superpowers.js    ← Plugin installed here
    [rest of ELF]
    
  plugins/
    ELF_superpowers.js    → symlink to ~/.opencode/emergent-learning/ELF_superpowers.js
```

## Environment Variables

- `ELF_BASE_PATH` - Path to ELF installation (default: ~/.opencode/emergent-learning)
  - Set by install script, used by all ELF components
  - Eliminates need for path replacements/patches

- `OPENCODE_DIR` - OpenCode config directory (default: ~/.opencode)

## Key Design Decisions

1. **No patches needed** - ELF_BASE_PATH env var handles all path resolution
2. **Plugin separate** - Lives in OPC_ELF, installed to ELF root, symlinked from .opencode/plugins
3. **Always fresh ELF** - `git reset --hard origin/main` ensures clean state
4. **Data preserved** - DBs backed up before install
5. **Lazy activation** - Plugin inactive until `/elf_activate` called

## Usage

After installation:

1. Start OpenCode
2. In any session, type: `/elf_activate`
3. ELF hooks now active (automatic learning from tool outputs)
4. Auto check-in/check-out on session lifecycle

To disable ELF, just restart OpenCode (hooks deactivate per-session).
