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
