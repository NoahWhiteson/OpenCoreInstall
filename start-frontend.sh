#!/bin/bash

# Start OpenCore Frontend Server
# This script finds the OpenCore installation and starts the frontend

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check if frontend exists in current directory structure
if [ -d "$INSTALL_DIR/frontend" ]; then
    FRONTEND_DIR="$INSTALL_DIR/frontend"
elif [ -d "$INSTALL_DIR/opencore/frontend" ]; then
    FRONTEND_DIR="$INSTALL_DIR/opencore/frontend"
else
    echo "Error: Could not find frontend directory"
    echo "Searched in: $INSTALL_DIR"
    exit 1
fi

cd "$FRONTEND_DIR" || exit 1

# Read port from .env.local if it exists
PORT=3001
if [ -f .env.local ]; then
    PORT_LINE=$(grep -E '^PORT=' .env.local 2>/dev/null || echo "")
    if [ -n "$PORT_LINE" ]; then
        PORT=$(echo "$PORT_LINE" | cut -d'=' -f2)
    fi
fi

echo "Starting OpenCore Frontend on port $PORT..."
echo "Directory: $FRONTEND_DIR"
PORT=$PORT npm start

