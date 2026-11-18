$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$installDir = "$env:LOCALAPPDATA\BillSetu"
$oldDir = "$env:LOCALAPPDATA\ShopPOS"
$libsDir = "$installDir\libs"
$jarPath = "$installDir\BillSetu.jar"
$versionJsonUrl = "https://raw.githubusercontent.com/suraj-kankal/shoppos-updates/main/version.json"

Write-Host "Installing BillSetu..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

# Migrate existing ShopPOS data (shop.db, storage, tokens) if upgrading on an existing PC
if ((Test-Path "$oldDir\shop.db") -and (-not (Test-Path "$installDir\shop.db"))) {
    Write-Host "Migrating existing database and bills to BillSetu..." -ForegroundColor Yellow
    Copy-Item "$oldDir\shop.db" "$installDir\shop.db" -Force
    if (Test-Path "$oldDir\storage") { Copy-Item "$oldDir\storage" "$installDir\storage" -Recurse -Force }
    if (Test-Path "$oldDir\tokens") { Copy-Item "$oldDir\tokens" "$installDir\tokens" -Recurse -Force }
}

# Check if Java is installed
if (-not (Get-Command javaw -ErrorAction SilentlyContinue)) {
    Write-Host "Java not found. Installing Java 21..." -ForegroundColor Yellow
    winget install --id EclipseAdoptium.Temurin.21.JRE -e --silent --accept-package-agreements --accept-source-agreements
}

$versionInfo = Invoke-RestMethod -Uri $versionJsonUrl
$jarUrl = $versionInfo.jarUrl

# Download shared libraries once (~61 MB)
if (-not (Test-Path $libsDir) -or (Get-ChildItem $libsDir -Filter *.jar -ErrorAction SilentlyContinue).Count -eq 0) {
    $libsZip = "$env:TEMP\billsetu_libs.zip"
    $libsUrl = if ($versionInfo.libsUrl) { $versionInfo.libsUrl } else { "https://github.com/suraj-kankal/shoppos-updates/releases/download/v$($versionInfo.version)/libs.zip" }
    Write-Host "Downloading required libraries (one-time setup)..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $libsUrl -OutFile $libsZip -UseBasicParsing
    New-Item -ItemType Directory -Force -Path $libsDir | Out-Null
    Expand-Archive -Path $libsZip -DestinationPath $libsDir -Force
    Remove-Item $libsZip -ErrorAction SilentlyContinue
}

Write-Host "Downloading BillSetu v$($versionInfo.version)..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $jarUrl -OutFile $jarPath -UseBasicParsing

if (-not (Test-Path $jarPath)) {
    throw "Download failed: $jarPath was not created."
}

# Remove old ShopPOS shortcut if present and create BillSetu Desktop Shortcut
Remove-Item "$env:USERPROFILE\Desktop\ShopPOS.lnk" -ErrorAction SilentlyContinue

$icoPath = "$installDir\billsetu.ico"
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/suraj-kankal/shoppos-updates/main/billsetu.ico" -OutFile $icoPath -UseBasicParsing
} catch {}

$ws = New-Object -ComObject WScript.Shell
$shortcut = $ws.CreateShortcut("$env:USERPROFILE\Desktop\BillSetu.lnk")
$shortcut.TargetPath = "javaw.exe"
$shortcut.Arguments = "-jar `"$jarPath`""
$shortcut.WorkingDirectory = $installDir
if (Test-Path $icoPath) { $shortcut.IconLocation = $icoPath }
$shortcut.Save()

Write-Host "BillSetu v$($versionInfo.version) installed! Launching..." -ForegroundColor Green
Start-Process "javaw.exe" -ArgumentList "-jar `"$jarPath`"" -WorkingDirectory $installDir
