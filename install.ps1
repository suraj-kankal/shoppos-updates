$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$installDir = "$env:LOCALAPPDATA\ShopPOS"
$jarPath = "$installDir\ShopPOS.jar"
$versionJsonUrl = "https://raw.githubusercontent.com/suraj-kankal/shoppos-updates/main/version.json"

Write-Host "Installing ShopPOS..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

# Check if Java is installed
if (-not (Get-Command javaw -ErrorAction SilentlyContinue)) {
    Write-Host "Java not found. Installing Java 21..." -ForegroundColor Yellow
    winget install --id EclipseAdoptium.Temurin.21.JRE -e --silent --accept-package-agreements --accept-source-agreements
}

$versionInfo = Invoke-RestMethod -Uri $versionJsonUrl
$jarUrl = $versionInfo.jarUrl

Write-Host "Downloading ShopPOS v$($versionInfo.version)..." -ForegroundColor Yellow
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

Write-Host "ShopPOS v$($versionInfo.version) installed! Launching..." -ForegroundColor Green
Start-Process "javaw.exe" -ArgumentList "-jar `"$jarPath`"" -WorkingDirectory $installDir
