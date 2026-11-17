$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$installDir = "$env:LOCALAPPDATA\ShopPOS"
$jarPath = "$installDir\ShopPOS.jar"
$versionJsonUrl = "https://raw.githubusercontent.com/suraj-kankal/shoppos-updates/main/version.json"

Write-Host "Installing BillSetu..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

# Check if Java is installed
if (-not (Get-Command javaw -ErrorAction SilentlyContinue)) {
    Write-Host "Java not found. Installing Java 21..." -ForegroundColor Yellow
    winget install --id EclipseAdoptium.Temurin.21.JRE -e --silent --accept-package-agreements --accept-source-agreements
}

$versionInfo = Invoke-RestMethod -Uri $versionJsonUrl
$jarUrl = $versionInfo.jarUrl

Write-Host "Downloading BillSetu v$($versionInfo.version)..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $jarUrl -OutFile $jarPath -UseBasicParsing

if (-not (Test-Path $jarPath)) {
    throw "Download failed: $jarPath was not created."
}

# Remove old ShopPOS shortcut if present and create BillSetu Desktop Shortcut
Remove-Item "$env:USERPROFILE\Desktop\ShopPOS.lnk" -ErrorAction SilentlyContinue

$icoPath = "$installDir\billsetu.ico"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/suraj-kankal/shoppos-updates/main/billsetu.ico" -OutFile $icoPath -UseBasicParsing

$ws = New-Object -ComObject WScript.Shell
$shortcut = $ws.CreateShortcut("$env:USERPROFILE\Desktop\BillSetu.lnk")
$shortcut.TargetPath = "javaw.exe"
$shortcut.Arguments = "-jar `"$jarPath`""
$shortcut.WorkingDirectory = $installDir
$shortcut.IconLocation = $icoPath
$shortcut.Save()

Write-Host "BillSetu v$($versionInfo.version) installed! Launching..." -ForegroundColor Green
Start-Process "javaw.exe" -ArgumentList "-jar `"$jarPath`"" -WorkingDirectory $installDir
