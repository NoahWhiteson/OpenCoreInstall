#!/bin/bash

# Start OpenCore Frontend Server

cd "$(dirname "$0")/../frontend" || exit 1

# Read port from .env.local if it exists
if [ -f .env.local ]; then
    PORT=$(grep -oP 'PORT=\K[0-9]+' .env.local 2>/dev/null || echo "3001")
else
    PORT=3001
fi

echo "Starting OpenCore Frontend on port $PORT..."
PORT=$PORT npm start

