# OpenCore Installation Scripts

Automated installation scripts and CLI tool for OpenCore system monitoring platform.

## Quick Install

### Linux/Mac

```bash
chmod +x install.sh
./install.sh
```

### Windows

```powershell
.\install.ps1
```

## What It Does

The installation script will:
1. Check Node.js version (requires 20.9.0+)
2. Clone the OpenCore repository from GitHub
3. Prompt you for configuration:
   - Admin username and password
   - Backend port (default: random 3000-3999)
   - Frontend port (default: random 4000-4999)
   - Public IP address
4. Generate secure JWT and encryption keys
5. Install all dependencies
6. Build the frontend
7. Install the OpenCore CLI tool
8. Create all necessary configuration files

## Using the OpenCore CLI

After installation, the OpenCore CLI tool is automatically installed. Use it to manage your servers:

### Start Servers
```bash
opencore backend start    # Start backend only
opencore frontend start   # Start frontend only
opencore start            # Start both
```

### Stop Servers
```bash
opencore backend stop     # Stop backend only
opencore frontend stop    # Stop frontend only
opencore stop             # Stop both
```

### Help
```bash
opencore                  # Show help
```

## Manual Start Scripts

If the CLI is not available, you can use the start scripts:

### Linux/Mac
```bash
./start-backend.sh
./start-frontend.sh
```

### Windows
```powershell
.\start-backend.ps1
.\start-frontend.ps1
```

## Requirements

- **Node.js 20.9.0 or higher** (required for Next.js 16)
- **npm** (comes with Node.js)
- **Git**

## Troubleshooting

### Node.js Version Too Old

If you see "Node.js version >=20.9.0 is required":
1. Upgrade Node.js: https://nodejs.org/
2. Or use a Node version manager:
   - **nvm** (Linux/Mac): `nvm install 20 && nvm use 20`
   - **nvm-windows**: Download from https://github.com/coreybutler/nvm-windows

### CLI Not Found

If `opencore` command is not found:
```bash
cd /path/to/opencore/install
npm link
```

Or run directly:
```bash
node /path/to/opencore/install/opencore-cli.js backend start
```

## Manual Installation

For manual installation instructions, see the main [OpenCore repository](https://github.com/NoahWhiteson/OpenCore).

