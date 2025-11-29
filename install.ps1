# OpenCore Installation Script for Windows
# This script downloads and sets up OpenCore backend and frontend

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  OpenCore Installation Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Node.js is not installed. Please install Node.js 18+ first." -ForegroundColor Red
    exit 1
}

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "Error: npm is not installed. Please install npm first." -ForegroundColor Red
    exit 1
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Error: git is not installed. Please install git first." -ForegroundColor Red
    exit 1
}

Write-Host "✓ Prerequisites check passed" -ForegroundColor Green
Write-Host ""

# Get installation directory
$INSTALL_DIR = Read-Host "Enter installation directory (default: .\opencore)"
if ([string]::IsNullOrWhiteSpace($INSTALL_DIR)) {
    $INSTALL_DIR = ".\opencore"
}

if (Test-Path $INSTALL_DIR) {
    Write-Host "Directory $INSTALL_DIR already exists." -ForegroundColor Yellow
    $REMOVE_DIR = Read-Host "Do you want to remove it and reinstall? (y/N)"
    if ($REMOVE_DIR -eq "y" -or $REMOVE_DIR -eq "Y") {
        Remove-Item -Recurse -Force $INSTALL_DIR
        Write-Host "Removed existing directory" -ForegroundColor Green
    } else {
        Write-Host "Installation cancelled."
        exit 0
    }
}

New-Item -ItemType Directory -Force -Path $INSTALL_DIR | Out-Null
Set-Location $INSTALL_DIR

# Get GitHub repository URL
$GITHUB_URL = Read-Host "Enter GitHub repository URL (default: https://github.com/NoahWhiteson/OpenCore.git)"
if ([string]::IsNullOrWhiteSpace($GITHUB_URL)) {
    $GITHUB_URL = "https://github.com/NoahWhiteson/OpenCore.git"
}

Write-Host ""
Write-Host "Cloning repository..." -ForegroundColor Yellow
git clone $GITHUB_URL temp_repo
Move-Item -Path "temp_repo\*" -Destination "." -Force
Move-Item -Path "temp_repo\.*" -Destination "." -Force -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force temp_repo

Write-Host "✓ Repository cloned" -ForegroundColor Green
Write-Host ""

# Configuration
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Configuration" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Admin credentials
$ADMIN_USERNAME = Read-Host "Enter admin username (default: admin)"
if ([string]::IsNullOrWhiteSpace($ADMIN_USERNAME)) {
    $ADMIN_USERNAME = "admin"
}

$ADMIN_PASSWORD = Read-Host "Enter admin password" -AsSecureString
$ADMIN_PASSWORD_PLAIN = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ADMIN_PASSWORD)
)
if ([string]::IsNullOrWhiteSpace($ADMIN_PASSWORD_PLAIN)) {
    Write-Host "Error: Password cannot be empty" -ForegroundColor Red
    exit 1
}

# Generate JWT secret
$JWT_SECRET = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | ForEach-Object {[char]$_})

# Generate encryption key
$ENCRYPTION_KEY = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | ForEach-Object {[char]$_})

# Port configuration - generate unique ports
$BACKEND_PORT_DEFAULT = (3000 + (Get-Random -Maximum 1000))
$FRONTEND_PORT_DEFAULT = 4962

$BACKEND_PORT = Read-Host "Enter backend port (default: $BACKEND_PORT_DEFAULT)"
if ([string]::IsNullOrWhiteSpace($BACKEND_PORT)) {
    $BACKEND_PORT = $BACKEND_PORT_DEFAULT
}

$FRONTEND_PORT = Read-Host "Enter frontend port (default: $FRONTEND_PORT_DEFAULT)"
if ([string]::IsNullOrWhiteSpace($FRONTEND_PORT)) {
    $FRONTEND_PORT = $FRONTEND_PORT_DEFAULT
}

# Add firewall rules (Windows)
Write-Host ""
Write-Host "Configuring firewall..." -ForegroundColor Yellow
try {
    # Windows Firewall
    $firewall = New-Object -ComObject HNetCfg.FwMgr
    $firewallProfile = $firewall.LocalPolicy.CurrentProfile
    
    # Add backend port
    $backendRule = New-Object -ComObject HNetCfg.FwOpenPort
    $backendRule.Port = [int]$BACKEND_PORT
    $backendRule.Protocol = 6  # TCP
    $backendRule.Name = "OpenCore Backend"
    $firewallProfile.GloballyOpenPorts.Add($backendRule)
    Write-Host "✓ Allowed backend port $BACKEND_PORT" -ForegroundColor Green
    
    # Add frontend port
    $frontendRule = New-Object -ComObject HNetCfg.FwOpenPort
    $frontendRule.Port = [int]$FRONTEND_PORT
    $frontendRule.Protocol = 6  # TCP
    $frontendRule.Name = "OpenCore Frontend"
    $firewallProfile.GloballyOpenPorts.Add($frontendRule)
    Write-Host "✓ Allowed frontend port $FRONTEND_PORT" -ForegroundColor Green
    
    # Add port 4962
    $port4962Rule = New-Object -ComObject HNetCfg.FwOpenPort
    $port4962Rule.Port = 4962
    $port4962Rule.Protocol = 6  # TCP
    $port4962Rule.Name = "OpenCore Port 4962"
    $firewallProfile.GloballyOpenPorts.Add($port4962Rule)
    Write-Host "✓ Allowed port 4962/tcp" -ForegroundColor Green
} catch {
    Write-Host "⚠ Could not configure Windows Firewall. You may need to run as Administrator." -ForegroundColor Yellow
    Write-Host "  Please manually open ports $BACKEND_PORT, $FRONTEND_PORT, and 4962" -ForegroundColor Yellow
}

# Get public IP (IPv4 only)
$PUBLIC_IP = Read-Host "Enter your public IPv4 address (or press Enter to auto-detect)"
if ([string]::IsNullOrWhiteSpace($PUBLIC_IP)) {
    try {
        # Try to get IPv4 address specifically
        $PUBLIC_IP = (Invoke-WebRequest -Uri "https://api.ipify.org?format=text" -UseBasicParsing).Content.Trim()
        Write-Host "Auto-detected IPv4: $PUBLIC_IP" -ForegroundColor Green
    } catch {
        $PUBLIC_IP = "localhost"
        Write-Host "Could not auto-detect IP, using localhost" -ForegroundColor Yellow
    }
}

# Validate it's an IPv4 address (contains dots, not colons)
if ($PUBLIC_IP -match ":" -and $PUBLIC_IP -notmatch "\.") {
    Write-Host "⚠ Warning: Detected IPv6 address. Please enter an IPv4 address (e.g., 72.61.3.42)" -ForegroundColor Yellow
    $PUBLIC_IP = Read-Host "Enter your public IPv4 address"
}

# Allowed origins
$ALLOWED_ORIGINS = "http://${PUBLIC_IP}:${FRONTEND_PORT},http://localhost:${FRONTEND_PORT}"

Write-Host ""
Write-Host "Creating .env file for backend..." -ForegroundColor Yellow
$BACKEND_ENV = @"
# Admin Credentials
ADMIN_USERNAME=$ADMIN_USERNAME
ADMIN_PASSWORD=$ADMIN_PASSWORD_PLAIN

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
"@

$BACKEND_ENV | Out-File -FilePath "backend\.env" -Encoding utf8
Write-Host "✓ Backend .env file created" -ForegroundColor Green

Write-Host ""
Write-Host "Creating .env.local file for frontend..." -ForegroundColor Yellow
$FRONTEND_ENV = @"
NEXT_PUBLIC_API_URL=http://${PUBLIC_IP}:${BACKEND_PORT}
PORT=${FRONTEND_PORT}
HOST=0.0.0.0
"@

$FRONTEND_ENV | Out-File -FilePath "frontend\.env.local" -Encoding utf8
Write-Host "✓ Frontend .env.local file created" -ForegroundColor Green
Write-Host "⚠ Note: If you change NEXT_PUBLIC_API_URL, you must rebuild the frontend:" -ForegroundColor Yellow
Write-Host "   cd frontend; npm run build" -ForegroundColor Yellow

Write-Host ""
Write-Host "Installing backend dependencies..." -ForegroundColor Yellow
Set-Location backend
npm install
Set-Location ..

Write-Host ""
Write-Host "Installing frontend dependencies..." -ForegroundColor Yellow
Set-Location frontend
npm install
Set-Location ..

Write-Host ""
Write-Host "Building frontend..." -ForegroundColor Yellow
Set-Location frontend
npm run build
Set-Location ..

Write-Host ""
Write-Host "Installing OpenCore CLI..." -ForegroundColor Yellow

# Find the install directory (where this script is located)
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

if (Test-Path $SCRIPT_DIR) {
    Set-Location $SCRIPT_DIR
    npm install --silent 2>$null

    # Try to install CLI globally
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host "Installing OpenCore CLI globally..." -ForegroundColor Yellow
        npm link 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Note: Could not install CLI globally. To install manually:" -ForegroundColor Yellow
            Write-Host "  cd $SCRIPT_DIR; npm link"
        }
    }
    
    # Save installation location to CLI config
    Write-Host "Saving installation location..." -ForegroundColor Yellow
    $configDir = Join-Path $env:USERPROFILE ".opencore"
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir | Out-Null
    }
    $configFile = Join-Path $configDir "config.json"
    $config = @{
        installPath = $INSTALL_DIR
        updatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    } | ConvertTo-Json
    $config | Out-File -FilePath $configFile -Encoding utf8
    Write-Host "✓ Installation location saved" -ForegroundColor Green
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:"
Write-Host "  Backend Port: $BACKEND_PORT"
Write-Host "  Frontend Port: $FRONTEND_PORT"
Write-Host "  Public URL: http://${PUBLIC_IP}:${FRONTEND_PORT}"
Write-Host "  Admin Username: $ADMIN_USERNAME"
Write-Host "  Installation Directory: $INSTALL_DIR"
Write-Host ""
Write-Host "To start the servers, use the OpenCore CLI:"
Write-Host "  opencore backend start"
Write-Host "  opencore frontend start"
Write-Host ""
Write-Host "Or start both:"
Write-Host "  opencore start"
Write-Host ""
Write-Host "To stop servers:"
Write-Host "  opencore backend stop"
Write-Host "  opencore frontend stop"
Write-Host "  opencore stop"
Write-Host ""
Write-Host "If the CLI is not available, you can also:"
Write-Host "  1. Backend: cd $INSTALL_DIR\backend; npm start"
Write-Host "  2. Frontend: cd $INSTALL_DIR\frontend; npm start"
Write-Host ""

