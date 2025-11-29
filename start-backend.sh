#!/bin/bash

# Start OpenCore Backend Server
# This script finds the OpenCore installation and starts the backend

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check if backend exists in current directory structure
if [ -d "$INSTALL_DIR/backend" ]; then
    BACKEND_DIR="$INSTALL_DIR/backend"
elif [ -d "$INSTALL_DIR/opencore/backend" ]; then
    BACKEND_DIR="$INSTALL_DIR/opencore/backend"
else
    echo "Error: Could not find backend directory"
    echo "Searched in: $INSTALL_DIR"
    exit 1
fi

cd "$BACKEND_DIR" || exit 1

echo "Starting OpenCore Backend..."
echo "Directory: $BACKEND_DIR"
npm start

