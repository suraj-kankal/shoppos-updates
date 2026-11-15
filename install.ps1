$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$installDir = "$env:LOCALAPPDATA\ShopPOS"
$jarPath = "$installDir\ShopPOS.jar"
$jarUrl = "https://github.com/suraj-kankal/shoppos-updates/releases/download/v1.0.0/offline-billing-1.0.0.jar"

Write-Host "Installing ShopPOS..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

# Check if Java is installed
if (-not (Get-Command javaw -ErrorAction SilentlyContinue)) {
    Write-Host "Java not found. Installing Java 21..." -ForegroundColor Yellow
    winget install --id EclipseAdoptium.Temurin.21.JRE -e --silent --accept-package-agreements --accept-source-agreements
}

Write-Host "Downloading ShopPOS v1.0.0..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $jarUrl -OutFile $jarPath -UseBasicParsing

if (-not (Test-Path $jarPath)) {
    throw "Download failed: $jarPath was not created."
}

# Create Desktop Shortcut
$ws = New-Object -ComObject WScript.Shell
$shortcut = $ws.CreateShortcut("$env:USERPROFILE\Desktop\ShopPOS.lnk")
$shortcut.TargetPath = "javaw.exe"
$shortcut.Arguments = "-jar `"$jarPath`""
$shortcut.WorkingDirectory = $installDir
$shortcut.Save()

Write-Host "ShopPOS installed! Launching..." -ForegroundColor Green
Start-Process "javaw.exe" -ArgumentList "-jar `"$jarPath`"" -WorkingDirectory $installDir
