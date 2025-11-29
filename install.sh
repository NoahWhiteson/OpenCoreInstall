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
    echo -e "${RED}Error: Node.js is not installed. Please install Node.js 20.9.0+ first.${NC}"
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2)
NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1)
NODE_MINOR=$(echo $NODE_VERSION | cut -d'.' -f2)
NODE_PATCH=$(echo $NODE_VERSION | cut -d'.' -f3)

if [ "$NODE_MAJOR" -lt 20 ] || ([ "$NODE_MAJOR" -eq 20 ] && [ "$NODE_MINOR" -lt 9 ]); then
    echo -e "${RED}Error: Node.js version 20.9.0 or higher is required.${NC}"
    echo -e "${RED}Current version: $(node -v)${NC}"
    echo -e "${YELLOW}Please upgrade Node.js: https://nodejs.org/${NC}"
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

echo -e "${GREEN}✓ Prerequisites check passed (Node.js $(node -v))${NC}"
echo ""

# Get installation directory (where OpenCore will be installed)
read -p "Enter installation directory (default: ./opencore): " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-./opencore}
INSTALL_DIR=$(cd "$INSTALL_DIR" 2>/dev/null && pwd || echo "$(pwd)/${INSTALL_DIR#./}")

# Convert to absolute path
if [[ "$INSTALL_DIR" != /* ]]; then
    INSTALL_DIR="$(pwd)/$INSTALL_DIR"
fi

# Check if INSTALL_DIR already contains OpenCore
if [ -d "$INSTALL_DIR/backend" ] && [ -d "$INSTALL_DIR/frontend" ]; then
    echo -e "${YELLOW}OpenCore already exists in $INSTALL_DIR${NC}"
    read -p "Do you want to remove it and reinstall? (y/N): " REINSTALL
    if [[ ! $REINSTALL =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    rm -rf "$INSTALL_DIR/backend" "$INSTALL_DIR/frontend"
fi

# Create installation directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Get GitHub repository URL
read -p "Enter GitHub repository URL (default: https://github.com/NoahWhiteson/OpenCore.git): " GITHUB_URL
GITHUB_URL=${GITHUB_URL:-https://github.com/NoahWhiteson/OpenCore.git}

echo ""
echo "Cloning OpenCore repository to $INSTALL_DIR..."
cd "$INSTALL_DIR"

# Clone the main OpenCore repository (not the install repo)
git clone "$GITHUB_URL" temp_repo

# Move backend and frontend directories to INSTALL_DIR
if [ -d "temp_repo/backend" ]; then
    mv temp_repo/backend "$INSTALL_DIR/"
    echo -e "${GREEN}✓ Backend cloned${NC}"
fi

if [ -d "temp_repo/frontend" ]; then
    mv temp_repo/frontend "$INSTALL_DIR/"
    echo -e "${GREEN}✓ Frontend cloned${NC}"
fi

# Copy other important files if they exist
if [ -f "temp_repo/.gitignore" ]; then
    cp temp_repo/.gitignore "$INSTALL_DIR/" 2>/dev/null || true
fi
if [ -f "temp_repo/README.md" ]; then
    cp temp_repo/README.md "$INSTALL_DIR/" 2>/dev/null || true
fi

# Clean up temp directory
rm -rf temp_repo

cd "$INSTALL_DIR"

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
FRONTEND_PORT_DEFAULT=4962

read -p "Enter backend port (default: $BACKEND_PORT_DEFAULT): " BACKEND_PORT
BACKEND_PORT=${BACKEND_PORT:-$BACKEND_PORT_DEFAULT}

read -p "Enter frontend port (default: $FRONTEND_PORT_DEFAULT): " FRONTEND_PORT
FRONTEND_PORT=${FRONTEND_PORT:-$FRONTEND_PORT_DEFAULT}

# Add firewall rules
echo ""
echo "Configuring firewall..."
if command_exists ufw; then
    echo "Adding UFW firewall rules..."
    ufw allow ${BACKEND_PORT}/tcp 2>/dev/null && echo -e "${GREEN}✓ Allowed backend port ${BACKEND_PORT}${NC}" || echo -e "${YELLOW}⚠ Could not add backend port rule (may need sudo)${NC}"
    ufw allow ${FRONTEND_PORT}/tcp 2>/dev/null && echo -e "${GREEN}✓ Allowed frontend port ${FRONTEND_PORT}${NC}" || echo -e "${YELLOW}⚠ Could not add frontend port rule (may need sudo)${NC}"
    ufw allow 4962/tcp 2>/dev/null && echo -e "${GREEN}✓ Allowed port 4962/tcp${NC}" || echo -e "${YELLOW}⚠ Could not add port 4962 rule (may need sudo)${NC}"
elif command_exists firewall-cmd; then
    echo "Adding firewalld rules..."
    firewall-cmd --permanent --add-port=${BACKEND_PORT}/tcp 2>/dev/null && echo -e "${GREEN}✓ Allowed backend port ${BACKEND_PORT}${NC}" || echo -e "${YELLOW}⚠ Could not add backend port rule${NC}"
    firewall-cmd --permanent --add-port=${FRONTEND_PORT}/tcp 2>/dev/null && echo -e "${GREEN}✓ Allowed frontend port ${FRONTEND_PORT}${NC}" || echo -e "${YELLOW}⚠ Could not add frontend port rule${NC}"
    firewall-cmd --permanent --add-port=4962/tcp 2>/dev/null && echo -e "${GREEN}✓ Allowed port 4962/tcp${NC}" || echo -e "${YELLOW}⚠ Could not add port 4962 rule${NC}"
    firewall-cmd --reload 2>/dev/null || true
else
    echo -e "${YELLOW}⚠ No firewall management tool found (ufw or firewalld). Please manually open ports ${BACKEND_PORT}, ${FRONTEND_PORT}, and 4962${NC}"
fi

# Get public IP (IPv4 only)
read -p "Enter your public IPv4 address (or press Enter to auto-detect): " PUBLIC_IP
if [ -z "$PUBLIC_IP" ]; then
    # Try to get IPv4 address specifically
    PUBLIC_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "localhost")
    echo "Auto-detected IPv4: $PUBLIC_IP"
fi

# Validate it's an IPv4 address (contains dots, not colons)
if [[ "$PUBLIC_IP" == *":"* ]] && [[ "$PUBLIC_IP" != *"."* ]]; then
    echo -e "${YELLOW}⚠ Warning: Detected IPv6 address. Please enter an IPv4 address (e.g., 72.61.3.42)${NC}"
    read -p "Enter your public IPv4 address: " PUBLIC_IP
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
HOST=0.0.0.0
NODE_ENV=production

# CORS
ALLOWED_ORIGINS=$ALLOWED_ORIGINS
EOF

echo -e "${GREEN}✓ Backend .env file created${NC}"

echo ""
echo "Creating .env.local file for frontend..."
cat > frontend/.env.local <<EOF
NEXT_PUBLIC_API_URL=http://${PUBLIC_IP}:${BACKEND_PORT}
PORT=${FRONTEND_PORT}
HOST=0.0.0.0
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
echo "Installing OpenCore CLI..."

# Find the install directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Install CLI from the install directory
if [ -d "$SCRIPT_DIR" ]; then
    cd "$SCRIPT_DIR"
    npm install --silent 2>/dev/null || true
    
    # Make CLI executable first
    chmod +x "$SCRIPT_DIR/opencore-cli.js" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/fix-cli.sh" 2>/dev/null || true
    
    # Try to install CLI globally
    if command_exists npm; then
        echo "Installing OpenCore CLI globally..."
        cd "$SCRIPT_DIR"
        npm link 2>/dev/null || {
            echo -e "${YELLOW}Note: Could not install CLI globally. To install manually:${NC}"
            echo "  cd $SCRIPT_DIR && npm link"
            echo "Or run directly: node $SCRIPT_DIR/opencore-cli.js"
        }
        
        # Fix permissions on the linked binary (check multiple locations)
        BIN_PATHS=(
            "/usr/local/bin/opencore"
            "/usr/bin/opencore"
            "$HOME/.npm-global/bin/opencore"
            "$HOME/.local/bin/opencore"
        )
        
        for BIN_PATH in "${BIN_PATHS[@]}"; do
            if [ -f "$BIN_PATH" ] || [ -L "$BIN_PATH" ]; then
                chmod +x "$BIN_PATH" 2>/dev/null && echo -e "${GREEN}✓ Fixed permissions on CLI binary${NC}"
                break
            fi
        done
        
        # Run fix script to ensure everything is correct
        if [ -f "$SCRIPT_DIR/fix-cli.sh" ]; then
            bash "$SCRIPT_DIR/fix-cli.sh" 2>/dev/null || true
        fi
    fi
    
    # Make scripts executable
    chmod +x "$SCRIPT_DIR/start-backend.sh" "$SCRIPT_DIR/start-frontend.sh" 2>/dev/null || true
    
    # Save installation location to CLI config
    echo "Saving installation location..."
    mkdir -p ~/.opencore
    cat > ~/.opencore/config.json <<EOF
{
  "installPath": "$INSTALL_DIR",
  "updatedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    echo -e "${GREEN}✓ Installation location saved${NC}"
fi

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
echo "  Installation Directory: $INSTALL_DIR"
echo ""
echo "To start the servers, use the OpenCore CLI:"
echo "  opencore backend start"
echo "  opencore frontend start"
echo ""
echo "Or start both:"
echo "  opencore start"
echo ""
echo "To stop servers:"
echo "  opencore backend stop"
echo "  opencore frontend stop"
echo "  opencore stop"
echo ""
echo "If the CLI is not available, you can also:"
echo "  1. Backend: cd $INSTALL_DIR/backend && npm start"
echo "  2. Frontend: cd $INSTALL_DIR/frontend && npm start"
echo ""

