#!/usr/bin/env bash
set -euo pipefail

# Script to preserve custom files during ELF updates
# This should be called by opc-elf-sync.sh before and after git pull

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ELF_REPO="$ROOT_DIR/Emergent-Learning-Framework_ELF"
CUSTOM_BACKUP_DIR="$ROOT_DIR/backups/custom"
CUSTOM_FILES_DIR="$ROOT_DIR/custom_files"

mkdir -p "$CUSTOM_BACKUP_DIR"
mkdir -p "$CUSTOM_FILES_DIR"

# Function to backup custom files
backup_custom_files() {
    echo "Backing up custom files..."

    # Backup our custom plugin
    if [ -f "$ROOT_DIR/scripts/ELF_superpowers_plug.js" ]; then
        cp -f "$ROOT_DIR/scripts/ELF_superpowers_plug.js" "$CUSTOM_BACKUP_DIR/"
    fi

    # Backup our custom launcher
    if [ -f "$ELF_REPO/src/watcher/launcher.py" ]; then
        cp -f "$ELF_REPO/src/watcher/launcher.py" "$CUSTOM_BACKUP_DIR/"
    fi

    # Backup our custom start-watcher.sh
    if [ -f "$ELF_REPO/tools/scripts/start-watcher.sh" ]; then
        cp -f "$ELF_REPO/tools/scripts/start-watcher.sh" "$CUSTOM_BACKUP_DIR/"
    fi

    echo "Custom files backed up to $CUSTOM_BACKUP_DIR"
}

# Function to restore custom files
restore_custom_files() {
    echo "Restoring custom files..."

    # Restore our custom plugin
    if [ -f "$CUSTOM_BACKUP_DIR/ELF_superpowers_plug.js" ]; then
        cp -f "$CUSTOM_BACKUP_DIR/ELF_superpowers_plug.js" "$ROOT_DIR/scripts/"
    fi

    # Restore our custom launcher
    if [ -f "$CUSTOM_BACKUP_DIR/launcher.py" ]; then
        cp -f "$CUSTOM_BACKUP_DIR/launcher.py" "$ELF_REPO/src/watcher/"
    fi

    # Restore our custom start-watcher.sh
    if [ -f "$CUSTOM_BACKUP_DIR/start-watcher.sh" ]; then
        cp -f "$CUSTOM_BACKUP_DIR/start-watcher.sh" "$ELF_REPO/tools/scripts/"
    fi

    echo "Custom files restored from $CUSTOM_BACKUP_DIR"
}

# Function to apply custom patches
apply_custom_patches() {
    echo "Applying custom patches..."

    # Apply patch for launcher.py if needed
    apply_launcher_patch

    # Apply patch for start-watcher.sh if needed
    apply_start_watcher_patch

    echo "Custom patches applied"
}

# Function to apply launcher.py patch
apply_launcher_patch() {
    local launcher_file="$ELF_REPO/src/watcher/launcher.py"
    local backup_launcher="$CUSTOM_BACKUP_DIR/launcher.py"

    if [ ! -f "$launcher_file" ]; then
        echo "Creating launcher.py (file missing upstream)..."
        # If we have a backup, restore it
        if [ -f "$backup_launcher" ]; then
            cp "$backup_launcher" "$launcher_file"
        else
            # Create fresh launcher.py
            cat > "$launcher_file" << 'EOF'
#!/usr/bin/env python3
"""
Local watcher launcher for OpenAI-compatible endpoints.
"""

import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from elf_paths import get_base_path

COORDINATION_DIR = Path(os.environ.get("ELF_BASE_PATH", str(get_base_path()))) / ".coordination"
WATCHER_LOG = COORDINATION_DIR / "watcher-log.md"
STOP_FILE = COORDINATION_DIR / "watcher-stop"

DEFAULT_BASE_URL = "http://localhost:12134/v1"
DEFAULT_MODEL = "nemotron-v3-coder"
DEFAULT_INTERVAL = 30

def resolve_base_url() -> str:
    base_url = os.environ.get("OPENCODE_WATCHER_BASE_URL")
    if not base_url:
        base_url = os.environ.get("OPENAI_BASE_URL")
    return (base_url or DEFAULT_BASE_URL).rstrip("/")

def resolve_model() -> str:
    return os.environ.get("OPENCODE_WATCHER_MODEL") or DEFAULT_MODEL

def resolve_interval() -> int:
    value = os.environ.get("OPENCODE_WATCHER_INTERVAL")
    if not value:
        return DEFAULT_INTERVAL
    try:
        return int(value)
    except ValueError:
        return DEFAULT_INTERVAL

def fetch_prompt() -> str:
    script_path = Path(__file__).with_name("watcher_loop.py")
    result = subprocess.run(
        [sys.executable, str(script_path), "prompt"],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()

def call_openai(base_url: str, model: str, prompt: str) -> str:
    url = f"{base_url}/chat/completions"
    api_key = os.environ.get("OPENCODE_WATCHER_API_KEY") or os.environ.get("OPENAI_API_KEY")
    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    payload: Dict[str, Any] = {
        "model": model,
        "messages": [
            {"role": "system", "content": "You are a monitoring agent for ELF watcher."},
            {"role": "user", "content": prompt},
        ],
        "temperature": 0.2,
    }

    request = Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers)
    try:
        with urlopen(request, timeout=300) as response:
            data = json.loads(response.read().decode("utf-8"))
    except (HTTPError, URLError) as exc:
        raise RuntimeError(f"Watcher request failed: {exc}") from exc

    choices = data.get("choices") or []
    if not choices:
        raise RuntimeError("Watcher response missing choices")
    return choices[0].get("message", {}).get("content", "").strip()

def append_log(text: str) -> None:
    COORDINATION_DIR.mkdir(parents=True, exist_ok=True)
    WATCHER_LOG.write_text(WATCHER_LOG.read_text() + text + "\n" if WATCHER_LOG.exists() else text + "\n")

def should_stop(response: str) -> bool:
    if STOP_FILE.exists():
        return True
    for line in response.splitlines():
        if line.strip().upper().startswith("STATUS:"):
            status = line.split(":", 1)[-1].strip().lower()
            if status in {"complete", "stopped"}:
                return True
    return False

def main() -> int:
    base_url = resolve_base_url()
    model = resolve_model()
    interval = resolve_interval()
    once = "--once" in sys.argv

    while True:
        if STOP_FILE.exists():
            return 0
        prompt = fetch_prompt()
        response = call_openai(base_url, model, prompt)
        append_log(response)
        if should_stop(response) or once:
            return 0
        time.sleep(interval)

if __name__ == "__main__":
    raise SystemExit(main())
EOF
        fi
    else
        echo "launcher.py already exists upstream, applying surgical patches..."
        # Apply specific patches to existing launcher.py
        apply_surgical_patches_to_launcher
    fi
}

# Function to apply surgical patches to existing launcher.py
apply_surgical_patches_to_launcher() {
    local launcher_file="$ELF_REPO/src/watcher/launcher.py"

    # Check if OpenAI support is already present
    if grep -q "OPENCODE_WATCHER_BASE_URL" "$launcher_file"; then
        echo "launcher.py already has OpenAI support, skipping patch"
        return
    fi

    echo "Applying OpenAI compatibility patch to launcher.py..."

    # Create backup
    cp "$launcher_file" "$launcher_file.bak"

    # Apply patch using sed to modify specific sections
    # This is a simplified example - in a real scenario, we'd use more precise patching
    sed -i '/def call_openai/,/return response/d' "$launcher_file"

    # Insert our OpenAI-compatible call_openai function
    sed -i '/def append_log/i\
def call_openai(base_url: str, model: str, prompt: str) -> str:\
    url = f"{base_url}/chat/completions"\
    api_key = os.environ.get("OPENCODE_WATCHER_API_KEY") or os.environ.get("OPENAI_API_KEY")\
    headers = {"Content-Type": "application/json"}\
    if api_key:\
        headers["Authorization"] = f"Bearer {api_key}"\
\
    payload: Dict[str, Any] = {\
        "model": model,\
        "messages": [\
            {"role": "system", "content": "You are a monitoring agent for ELF watcher."},\
            {"role": "user", "content": prompt},\
        ],\
        "temperature": 0.2,\
    }\
\
    request = Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers)\
    try:\
        with urlopen(request, timeout=300) as response:\
            data = json.loads(response.read().decode("utf-8"))\
    except (HTTPError, URLError) as exc:\
        raise RuntimeError(f"Watcher request failed: {exc}") from exc\
\
    choices = data.get("choices") or []\
    if not choices:\
        raise RuntimeError("Watcher response missing choices")\
    return choices[0].get("message", {}).get("content", "").strip()' "$launcher_file"

    echo "OpenAI compatibility patch applied to launcher.py"
}

# Function to apply start-watcher.sh patch
apply_start_watcher_patch() {
    local start_watcher_file="$ELF_REPO/tools/scripts/start-watcher.sh"

    if [ ! -f "$start_watcher_file" ]; then
        echo "start-watcher.sh not found, cannot apply patch"
        return
    fi

    # Check if our patch is already applied
    if grep -q "OPENCODE_WATCHER_BASE_URL" "$start_watcher_file"; then
        echo "start-watcher.sh already has OpenAI support, skipping patch"
        return
    fi

    echo "Applying OpenAI compatibility patch to start-watcher.sh..."

    # Create backup
    cp "$start_watcher_file" "$start_watcher_file.bak"

    # Apply surgical patch using sed - replace only the specific lines
    sed -i '34c# Check for ANTHROPIC_API_KEY or OpenAI-compatible base URL' "$start_watcher_file"
    sed -i '35cif [ -z "$ANTHROPIC_API_KEY" ] && [ -z "$OPENCODE_WATCHER_BASE_URL" ] && [ -z "$OPENAI_BASE_URL" ]; then' "$start_watcher_file"
    sed -i '36c    echo "Error: ANTHROPIC_API_KEY or OPENCODE_WATCHER_BASE_URL is required"' "$start_watcher_file"
    sed -i '37c    echo "Example: export OPENCODE_WATCHER_BASE_URL='\''http://localhost:12134/v1'\''"' "$start_watcher_file"

    echo "OpenAI compatibility patch applied to start-watcher.sh"
}

# Main logic
case "$1" in
    backup)
        backup_custom_files
        ;;
    restore)
        restore_custom_files
        ;;
    patch)
        apply_custom_patches
        ;;
    *)
        echo "Usage: $0 {backup|restore|patch}"
        exit 1
        ;;
esac