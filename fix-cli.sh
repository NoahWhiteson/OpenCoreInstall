#!/bin/bash

# Auto-fix script for OpenCore CLI
# This script fixes common CLI permission and installation issues

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI_FILE="$SCRIPT_DIR/opencore-cli.js"

echo "Fixing OpenCore CLI..."

# Make CLI file executable
if [ -f "$CLI_FILE" ]; then
    chmod +x "$CLI_FILE"
    echo "✓ Made CLI file executable"
fi

# Try to find and fix linked binaries
BIN_PATHS=(
    "/usr/local/bin/opencore"
    "/usr/bin/opencore"
    "$HOME/.npm-global/bin/opencore"
    "$HOME/.local/bin/opencore"
)

for BIN_PATH in "${BIN_PATHS[@]}"; do
    if [ -f "$BIN_PATH" ] || [ -L "$BIN_PATH" ]; then
        chmod +x "$BIN_PATH" 2>/dev/null && echo "✓ Fixed permissions on $BIN_PATH"
    fi
done

# Try to re-link if needed
if [ -f "$CLI_FILE" ] && command -v npm >/dev/null 2>&1; then
    cd "$SCRIPT_DIR"
    npm link 2>/dev/null && echo "✓ Re-linked CLI globally"
    
    # Fix permissions after linking
    for BIN_PATH in "${BIN_PATHS[@]}"; do
        if [ -f "$BIN_PATH" ] || [ -L "$BIN_PATH" ]; then
            chmod +x "$BIN_PATH" 2>/dev/null
        fi
    done
fi

echo "Done!"

