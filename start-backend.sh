#!/bin/bash

# Start OpenCore Backend Server

cd "$(dirname "$0")/../backend" || exit 1

echo "Starting OpenCore Backend..."
npm start

