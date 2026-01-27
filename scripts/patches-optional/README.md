# Optional Patches

These patches are not applied by default but can be used for future enhancements.

## launcher-openai.patch
Enables watcher to spawn agents via OpenAI-compatible backend (local implementation).

**Purpose:** Allow ELF watcher to delegate work to subagents through a local OpenAI API-compatible server.

**When to use:** When implementing watcher integration with custom OpenAI backend.

**How to apply:**
```bash
cd Emergent-Learning-Framework_ELF
patch -p1 < ../scripts/patches-optional/launcher-openai.patch
```

## start-watcher-openai.patch
Adds OpenAI/OpenCode watcher support to startup scripts.

**Purpose:** Customize watcher startup to use OpenAI-compatible backend instead of default.

**When to use:** When setting up watcher with custom backend integration.

**How to apply:**
```bash
cd Emergent-Learning-Framework_ELF
patch -p1 < ../scripts/patches-optional/start-watcher-openai.patch
```

## Integration Flow

To enable watcher → OpenAI backend:

1. Apply the patches above
2. Configure watcher to point to your backend (typically via env vars)
3. ELF watcher will spawn agents through your backend instead of internal execution

## Notes

- These patches modify watcher behavior only, not core ELF
- Safe to apply/revert independently
- Compatible with lazy-activated plugin model
