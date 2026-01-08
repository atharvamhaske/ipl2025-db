#!/bin/bash
# ============================================================================
# PostgreSQL Setup Script for IPL 2025 Cricket Database
# ============================================================================

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "IPL 2025 Cricket Database Setup"
echo "=========================================="
echo "Project root: $PROJECT_ROOT"

# Configuration
DB_NAME="cricketdb"
DB_USER="${PGUSER:-postgres}"
DB_PORT="${PGPORT:-5432}"
DB_HOST="${PGHOST:-localhost}"

# Check if PostgreSQL is installed
if ! command -v psql &> /dev/null; then
    echo "ERROR: PostgreSQL is not installed."
    echo "Install with: sudo dnf install postgresql-server postgresql"
    exit 1
fi

# Check if PostgreSQL is running
if ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -q 2>/dev/null; then
    echo "PostgreSQL is not running on $DB_HOST:$DB_PORT"
    echo ""
    echo "To initialize and start PostgreSQL:"
    echo "  1. Initialize: sudo postgresql-setup --initdb"
    echo "  2. Start: sudo systemctl start postgresql"
    echo "  3. Enable: sudo systemctl enable postgresql"
    echo ""
    echo "Or for user-level PostgreSQL:"
    echo "  1. initdb -D ~/pgdata"
    echo "  2. pg_ctl -D ~/pgdata -l ~/pgdata/logfile start"
    exit 1
fi

echo "✓ PostgreSQL is running on $DB_HOST:$DB_PORT"

# Create database if not exists
echo "Creating database '$DB_NAME'..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 || \
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "CREATE DATABASE $DB_NAME"
echo "✓ Database '$DB_NAME' ready"

# Initialize schema
echo "Initializing schema..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$PROJECT_ROOT/sql/schema.sql"
echo "✓ Schema initialized"

# Run ingestion
echo "Running data ingestion..."
python3 "$PROJECT_ROOT/scripts/ingest_cricket_data.py" \
    --db-url "postgresql://$DB_USER@$DB_HOST:$DB_PORT/$DB_NAME" \
    --data-dir "$PROJECT_ROOT/data/"

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Connect to database:"
echo "  psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"
echo ""
echo "Run verification queries:"
echo "  psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $PROJECT_ROOT/sql/verify.sql"
