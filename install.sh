#!/bin/bash

# OpenCore Installation Script
# This script downloads and sets up OpenCore backend and frontend

set -e

echo "=========================================="
echo "  OpenCore Installation Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "Checking prerequisites..."
if ! command_exists node; then
    echo -e "${RED}Error: Node.js is not installed. Please install Node.js 18+ first.${NC}"
    exit 1
fi

if ! command_exists npm; then
    echo -e "${RED}Error: npm is not installed. Please install npm first.${NC}"
    exit 1
fi

if ! command_exists git; then
    echo -e "${RED}Error: git is not installed. Please install git first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# Get installation directory
read -p "Enter installation directory (default: ./opencore): " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-./opencore}

if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Directory $INSTALL_DIR already exists.${NC}"
    read -p "Do you want to remove it and reinstall? (y/N): " REMOVE_DIR
    if [[ $REMOVE_DIR =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}Removed existing directory${NC}"
    else
        echo "Installation cancelled."
        exit 0
    fi
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Get GitHub repository URL
read -p "Enter GitHub repository URL (default: https://github.com/NoahWhiteson/OpenCore.git): " GITHUB_URL
GITHUB_URL=${GITHUB_URL:-https://github.com/NoahWhiteson/OpenCore.git}

echo ""
echo "Cloning repository..."
git clone "$GITHUB_URL" temp_repo
mv temp_repo/* temp_repo/.* . 2>/dev/null || true
rmdir temp_repo

echo -e "${GREEN}✓ Repository cloned${NC}"
echo ""

# Configuration
echo "=========================================="
echo "  Configuration"
echo "=========================================="
echo ""

# Admin credentials
read -p "Enter admin username (default: admin): " ADMIN_USERNAME
ADMIN_USERNAME=${ADMIN_USERNAME:-admin}

read -sp "Enter admin password: " ADMIN_PASSWORD
echo ""
if [ -z "$ADMIN_PASSWORD" ]; then
    echo -e "${RED}Error: Password cannot be empty${NC}"
    exit 1
fi

# Generate JWT secret
JWT_SECRET=$(openssl rand -hex 32 2>/dev/null || node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")

# Generate encryption key
ENCRYPTION_KEY=$(openssl rand -hex 32 2>/dev/null || node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")

# Port configuration - generate unique ports
BACKEND_PORT_DEFAULT=$((3000 + RANDOM % 1000))
FRONTEND_PORT_DEFAULT=$((4000 + RANDOM % 1000))

read -p "Enter backend port (default: $BACKEND_PORT_DEFAULT): " BACKEND_PORT
BACKEND_PORT=${BACKEND_PORT:-$BACKEND_PORT_DEFAULT}

read -p "Enter frontend port (default: $FRONTEND_PORT_DEFAULT): " FRONTEND_PORT
FRONTEND_PORT=${FRONTEND_PORT:-$FRONTEND_PORT_DEFAULT}

# Get public IP
read -p "Enter your public IP address (or press Enter to auto-detect): " PUBLIC_IP
if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "localhost")
    echo "Auto-detected IP: $PUBLIC_IP"
fi

# Allowed origins
ALLOWED_ORIGINS="http://${PUBLIC_IP}:${FRONTEND_PORT},http://localhost:${FRONTEND_PORT}"

echo ""
echo "Creating .env file for backend..."
cat > backend/.env <<EOF
# Admin Credentials
ADMIN_USERNAME=$ADMIN_USERNAME
ADMIN_PASSWORD=$ADMIN_PASSWORD

# JWT Configuration
JWT_SECRET=$JWT_SECRET
JWT_EXPIRES_IN=24h

# Encryption
ENCRYPTION_KEY=$ENCRYPTION_KEY

# Server Configuration
PORT=$BACKEND_PORT
NODE_ENV=production

# CORS
ALLOWED_ORIGINS=$ALLOWED_ORIGINS
EOF

echo -e "${GREEN}✓ Backend .env file created${NC}"

echo ""
echo "Creating .env.local file for frontend..."
cat > frontend/.env.local <<EOF
NEXT_PUBLIC_API_URL=http://${PUBLIC_IP}:${BACKEND_PORT}
EOF

echo -e "${GREEN}✓ Frontend .env.local file created${NC}"

echo ""
echo "Installing backend dependencies..."
cd backend
npm install
cd ..

echo ""
echo "Installing frontend dependencies..."
cd frontend
npm install
cd ..

echo ""
echo "Building frontend..."
cd frontend
npm run build
cd ..

echo ""
echo "Making start scripts executable..."
chmod +x install/start-backend.sh install/start-frontend.sh 2>/dev/null || true

echo ""
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Backend Port: $BACKEND_PORT"
echo "  Frontend Port: $FRONTEND_PORT"
echo "  Public URL: http://${PUBLIC_IP}:${FRONTEND_PORT}"
echo "  Admin Username: $ADMIN_USERNAME"
echo ""
echo "To start the servers:"
echo "  1. Backend: cd $INSTALL_DIR/backend && npm start"
echo "  2. Frontend: cd $INSTALL_DIR/frontend && npm start"
echo ""
echo "Or use the provided start scripts:"
echo "  ./start-backend.sh"
echo "  ./start-frontend.sh"
echo ""

