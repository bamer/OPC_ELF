#!/usr/bin/env bash
set -euo pipefail

# Fix database schema issues
# Repair heuristics table that has NULL values in NOT NULL columns

OPENCODE_DIR="${OPENCODE_DIR:-$HOME/.opencode}"
ELF_INSTALL_DIR="${ELF_BASE_PATH:-$OPENCODE_DIR/emergent-learning}"

# Try both possible database locations
DB_PATH=""
if [ -f "$ELF_INSTALL_DIR/memory/index.db" ]; then
    DB_PATH="$ELF_INSTALL_DIR/memory/index.db"
elif [ -f "$ELF_INSTALL_DIR/.env/.sqlite" ]; then
    DB_PATH="$ELF_INSTALL_DIR/.env/.sqlite"
fi

if [ -z "$DB_PATH" ] || [ ! -f "$DB_PATH" ]; then
    echo "ERROR: Database not found"
    echo "Checked:"
    echo "  - $ELF_INSTALL_DIR/memory/index.db"
    echo "  - $ELF_INSTALL_DIR/.env/.sqlite"
    echo ""
    echo "ELF may not be installed yet. Run:"
    echo "  bash opencode_elf_install.sh"
    exit 1
fi

echo "=========================================="
echo " ELF Database Repair"
echo "=========================================="
echo ""
echo "Database: $DB_PATH"
echo ""

# Backup database
BACKUP_PATH="$DB_PATH.backup.$(date +%s)"
echo "Creating backup: $BACKUP_PATH"
cp "$DB_PATH" "$BACKUP_PATH"
echo "✅ Backup created"
echo ""

# Fix schema using dedicated Python script
echo "Fixing heuristics table schema..."

SCRIPTS_DIR="$(dirname "${BASH_SOURCE[0]}")"
python3 "$SCRIPTS_DIR/fix-heuristics-schema.py"

echo ""

# Verify database integrity using Python
echo "Verifying database integrity..."

python3 << 'PYEOF' || python << 'PYEOF'
import sqlite3

db_path = """$DB_PATH"""

try:
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("PRAGMA integrity_check")
    result = cursor.fetchone()
    conn.close()
    
    if result[0] == "ok":
        print("✅ Database integrity check passed")
    else:
        print("⚠️  Integrity check result: %s" % result[0])
        
except Exception as e:
    print("⚠️  Could not verify integrity: %s" % str(e))
PYEOF

echo ""

echo ""
echo "=========================================="
echo "✅ Database repair complete"
echo "=========================================="
echo ""
echo "Backup saved at: $BACKUP_PATH"
echo "If you need to rollback:"
echo "  cp $BACKUP_PATH $DB_PATH"
