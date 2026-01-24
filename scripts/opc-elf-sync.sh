#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ELF_REPO="$ROOT_DIR/Emergent-Learning-Framework_ELF"
PLUGIN_SRC="$ROOT_DIR/scripts/ELF_superpowers_plug.js"

OPENCODE_DIR="${OPENCODE_DIR:-$HOME/.opencode}"
OPENCODE_PLUGIN_DIR="$OPENCODE_DIR/plugin"
ELF_INSTALL_DIR="${ELF_BASE_PATH:-$OPENCODE_DIR/emergent-learning}"

BACKUP_DATE="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_DIR="$ROOT_DIR/backups/$BACKUP_DATE"

echo "========================================"
echo " OPC-ELF SYNC START"
echo "========================================"

echo "-- Preserving custom files (pre-update)"
"$ROOT_DIR/scripts/preserve-customizations.sh" backup

echo "-- Updating ELF repository"
cd "$ELF_REPO"
git pull || true

echo "-- Restoring custom files (post-update)"
"$ROOT_DIR/scripts/preserve-customizations.sh" restore

echo "-- Applying custom patches"
"$ROOT_DIR/scripts/preserve-customizations.sh" patch

echo "-- Normalizing .claude → .opencode"
if [ -d ".claude" ]; then
  mv ".claude" ".opencode"
fi
while read -r file; do
  [ -n "$file" ] || continue
  sed -i 's/\.claude/.opencode/g' "$file"
done < <(grep -RIl "\.claude" . || true)

echo "-- Backing up databases"
mkdir -p "$BACKUP_DIR"
if [ -d "$ELF_INSTALL_DIR" ]; then
  find "$ELF_INSTALL_DIR" -type f \( -name "*.sqlite3" -o -name "*.db" \) | while read -r db; do
    rel_path="${db#$HOME/}"
    backup_target="$BACKUP_DIR/$rel_path"
    mkdir -p "$(dirname "$backup_target")"
    cp "$db" "$backup_target"
  done
fi

echo "-- Running ELF installer"
if [ ! -x "./install.sh" ]; then
  chmod +x ./install.sh
fi
OPENCODE_DIR="$OPENCODE_DIR" ELF_BASE_PATH="$ELF_INSTALL_DIR" ./install.sh --mode merge

echo "-- Installing OpenCode plugin"
if [ ! -f "$PLUGIN_SRC" ]; then
  echo "ERROR: ELF_superpowers_plug.js not found at $PLUGIN_SRC"
  exit 1
fi
mkdir -p "$OPENCODE_PLUGIN_DIR"
cp -f "$PLUGIN_SRC" "$OPENCODE_PLUGIN_DIR/ELF_superpowers_plug.js"

echo "-- Syncing CLAUDE.md → AGENTS.md"
if [ -f "$OPENCODE_DIR/CLAUDE.md" ]; then
  cp -f "$OPENCODE_DIR/CLAUDE.md" "$OPENCODE_DIR/AGENTS.md"
fi

echo "-- Validating OpenCode ELF installation"
if [ ! -d "$ELF_INSTALL_DIR" ]; then
  echo "ERROR: $ELF_INSTALL_DIR not found after install"
  exit 1
fi
if [ ! -f "$OPENCODE_PLUGIN_DIR/ELF_superpowers_plug.js" ]; then
  echo "ERROR: OpenCode plugin not installed"
  exit 1
fi

echo "========================================"
echo " OPC-ELF SYNC COMPLETED SUCCESSFULLY"
echo " Backup stored in: $BACKUP_DIR"
echo "========================================"
