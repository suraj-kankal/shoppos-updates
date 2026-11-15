$installDir = "$env:LOCALAPPDATA\ShopPOS"
$jarPath = "$installDir\ShopPOS.jar"
$jarUrl = "https://github.com/suraj-kankal/shoppos-updates/releases/download/v1.0.0/offline-billing-1.0.0.jar"

Write-Host "Installing ShopPOS..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

# 1. Install Java 21 Runtime automatically if not present
if (-not (Get-Command javaw -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Java Runtime..." -ForegroundColor Yellow
    winget install EclipseAdoptium.Temurin.21.JRE --silent --accept-package-agreements --accept-source-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

# 2. Download ShopPOS JAR from GitHub Release
Write-Host "Downloading ShopPOS v1.0.0..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $jarUrl -OutFile $jarPath

# 3. Create Desktop Shortcut
$desktop = [Environment]::GetFolderPath("Desktop")
$ws = New-Object -ComObject WScript.Shell
$shortcut = $ws.CreateShortcut("$desktop\ShopPOS.lnk")
$shortcut.TargetPath = "javaw.exe"
$shortcut.Arguments = "-jar `"$jarPath`""
$shortcut.WorkingDirectory = $installDir
$shortcut.Save()

Write-Host "ShopPOS installed! Launching..." -ForegroundColor Green
Start-Process "javaw.exe" -ArgumentList "-jar `"$jarPath`"" -WorkingDirectory $installDir
