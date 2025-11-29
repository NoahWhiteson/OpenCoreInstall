# OpenCore Installation Scripts

Automated installation scripts for OpenCore system monitoring platform.

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
1. Clone the OpenCore repository from GitHub
2. Prompt you for configuration:
   - Admin username and password
   - Backend port (default: random 3000-3999)
   - Frontend port (default: random 4000-4999)
   - Public IP address
3. Generate secure JWT and encryption keys
4. Install all dependencies
5. Build the frontend
6. Create all necessary configuration files

## Starting OpenCore

After installation, use the start scripts:

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

## Manual Installation

For manual installation instructions, see the main [OpenCore repository](https://github.com/NoahWhiteson/OpenCore).

