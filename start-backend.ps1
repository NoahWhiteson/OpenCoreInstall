# Start OpenCore Backend Server

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location "$scriptPath\..\backend"

Write-Host "Starting OpenCore Backend..." -ForegroundColor Green
npm start

