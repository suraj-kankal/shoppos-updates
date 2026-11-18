$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$appName    = "BillSetu"
$installDir = Join-Path $env:LOCALAPPDATA $appName
$oldDir     = Join-Path $env:LOCALAPPDATA "ShopPOS"
$libsDir    = Join-Path $installDir "libs"
$jarPath    = Join-Path $installDir "BillSetu.jar"
$iconPath   = Join-Path $installDir "billsetu.ico"

$jarUrl     = "https://github.com/suraj-kankal/shoppos-updates/releases/download/v1.0.0/BillSetu-1.0.0.jar"
$libsUrl    = "https://github.com/suraj-kankal/shoppos-updates/releases/download/v1.0.0/libs.zip"
$iconUrl    = "https://raw.githubusercontent.com/suraj-kankal/shoppos-updates/main/billsetu.ico"

Write-Host "Installing $appName..." -ForegroundColor Cyan

# 1. Ensure Java is installed
$javaw = Get-Command javaw.exe -ErrorAction SilentlyContinue
if (-not $javaw) {
    Write-Host "Java not found. Installing Eclipse Temurin JRE..." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id EclipseAdoptium.Temurin.21.JRE -e --silent --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        $javaw = Get-Command javaw.exe -ErrorAction SilentlyContinue
    }
    if (-not $javaw) {
        throw "Java is required. Please install Java 17+ from https://adoptium.net and run the installer again."
    }
}

# 2. Create install directory & migrate old ShopPOS data if present
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
if ((Test-Path $oldDir) -and (-not (Test-Path (Join-Path $installDir "shop.db")))) {
    Write-Host "Migrating existing ShopPOS data to BillSetu..." -ForegroundColor Yellow
    if (Test-Path (Join-Path $oldDir "shop.db")) {
        Copy-Item (Join-Path $oldDir "shop.db") (Join-Path $installDir "shop.db") -Force
    }
    if (Test-Path (Join-Path $oldDir "storage")) {
        Copy-Item (Join-Path $oldDir "storage") (Join-Path $installDir "storage") -Recurse -Force
    }
}

# 3. Stop running BillSetu instance if open
Get-CimInstance Win32_Process -Filter "Name = 'javaw.exe' OR Name = 'java.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*BillSetu.jar*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# 4. Download BillSetu.jar, icon, and libs.zip
Write-Host "Downloading BillSetu-1.0.0.jar..." -ForegroundColor Gray
Invoke-WebRequest -Uri $jarUrl -OutFile $jarPath -UseBasicParsing

Write-Host "Downloading icon..." -ForegroundColor Gray
Invoke-WebRequest -Uri $iconUrl -OutFile $iconPath -UseBasicParsing

if (-not (Test-Path $libsDir) -or ((Get-ChildItem $libsDir -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0)) {
    Write-Host "Downloading dependencies (libs.zip, first-time only)..." -ForegroundColor Gray
    $libsZip = Join-Path $env:TEMP "billsetu_libs.zip"
    Invoke-WebRequest -Uri $libsUrl -OutFile $libsZip -UseBasicParsing
    New-Item -ItemType Directory -Path $libsDir -Force | Out-Null
    Expand-Archive -Path $libsZip -DestinationPath $libsDir -Force
    Remove-Item $libsZip -Force -ErrorAction SilentlyContinue
}

# 5. Create Desktop & Start Menu shortcuts
$shell = New-Object -ComObject WScript.Shell
$desktopLink = Join-Path ([Environment]::GetFolderPath("Desktop")) "$appName.lnk"
$startMenuDir = Join-Path ([Environment]::GetFolderPath("Programs")) $appName
New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
$startMenuLink = Join-Path $startMenuDir "$appName.lnk"

foreach ($lnkPath in @($desktopLink, $startMenuLink)) {
    $shortcut = $shell.CreateShortcut($lnkPath)
    $shortcut.TargetPath = $javaw.Source
    $shortcut.Arguments = "-jar `"$jarPath`""
    $shortcut.WorkingDirectory = $installDir
    $shortcut.IconLocation = $iconPath
    $shortcut.Description = "BillSetu Retail Billing Software"
    $shortcut.Save()
}

Write-Host "$appName installed successfully!" -ForegroundColor Green
Start-Process -FilePath $javaw.Source -ArgumentList "-jar `"$jarPath`"" -WorkingDirectory $installDir
