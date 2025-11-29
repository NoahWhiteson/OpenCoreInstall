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
$FRONTEND_PORT_DEFAULT = (4000 + (Get-Random -Maximum 1000))

$BACKEND_PORT = Read-Host "Enter backend port (default: $BACKEND_PORT_DEFAULT)"
if ([string]::IsNullOrWhiteSpace($BACKEND_PORT)) {
    $BACKEND_PORT = $BACKEND_PORT_DEFAULT
}

$FRONTEND_PORT = Read-Host "Enter frontend port (default: $FRONTEND_PORT_DEFAULT)"
if ([string]::IsNullOrWhiteSpace($FRONTEND_PORT)) {
    $FRONTEND_PORT = $FRONTEND_PORT_DEFAULT
}

# Get public IP
$PUBLIC_IP = Read-Host "Enter your public IP address (or press Enter to auto-detect)"
if ([string]::IsNullOrWhiteSpace($PUBLIC_IP)) {
    try {
        $PUBLIC_IP = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content.Trim()
        Write-Host "Auto-detected IP: $PUBLIC_IP" -ForegroundColor Green
    } catch {
        $PUBLIC_IP = "localhost"
        Write-Host "Could not auto-detect IP, using localhost" -ForegroundColor Yellow
    }
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
"@

$FRONTEND_ENV | Out-File -FilePath "frontend\.env.local" -Encoding utf8
Write-Host "✓ Frontend .env.local file created" -ForegroundColor Green

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
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:"
Write-Host "  Backend Port: $BACKEND_PORT"
Write-Host "  Frontend Port: $FRONTEND_PORT"
Write-Host "  Public URL: http://${PUBLIC_IP}:${FRONTEND_PORT}"
Write-Host "  Admin Username: $ADMIN_USERNAME"
Write-Host ""
Write-Host "To start the servers:"
Write-Host "  1. Backend: cd $INSTALL_DIR\backend; npm start"
Write-Host "  2. Frontend: cd $INSTALL_DIR\frontend; npm start"
Write-Host ""

