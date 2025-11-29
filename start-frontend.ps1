# Start OpenCore Frontend Server

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location "$scriptPath\..\frontend"

# Read port from .env.local if it exists
$PORT = "3001"
if (Test-Path ".env.local") {
    $envContent = Get-Content ".env.local" -Raw
    if ($envContent -match "PORT=(\d+)") {
        $PORT = $matches[1]
    }
}

Write-Host "Starting OpenCore Frontend on port $PORT..." -ForegroundColor Green
$env:PORT = $PORT
npm start

