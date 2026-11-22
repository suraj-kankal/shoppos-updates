$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$appName    = "BillSetu"
$installDir = Join-Path $env:LOCALAPPDATA $appName
$oldDir     = Join-Path $env:LOCALAPPDATA "ShopPOS"
$libsDir    = Join-Path $installDir "libs"
$jarPath    = Join-Path $installDir "BillSetu.jar"
$iconPath   = Join-Path $installDir "billsetu.ico"

$verInfo = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/suraj-kankal/shoppos-updates/main/version.json" -UseBasicParsing
$jarUrl  = $verInfo.jarUrl
$libsUrl = "https://github.com/suraj-kankal/shoppos-updates/releases/download/v1.0.0/libs.zip"
$iconUrl = "https://raw.githubusercontent.com/suraj-kankal/shoppos-updates/main/billsetu.ico"
$waUrl   = "https://github.com/suraj-kankal/shoppos-updates/releases/latest/download/wa-bridge.zip"

Write-Host "Installing $appName..." -ForegroundColor Cyan

# 1. Ensure Java is installed
$javaw = Get-Command javaw.exe -ErrorAction SilentlyContinue
if (-not $javaw) {
    Write-Host "Java not found. Installing Eclipse Temurin JRE..." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id EclipseAdoptium.Temurin.21.JRE -e --silent --accept-package-agreements --accept-source-agreements
    } else {
        $javaMsi = Join-Path $env:TEMP "temurin21-jre.msi"
        Invoke-WebRequest -Uri "https://api.adoptium.net/v3/installer/latest/21/ga/windows/x64/jre/hotspot/normal/eclipse" -OutFile $javaMsi -UseBasicParsing
        Start-Process msiexec.exe -ArgumentList "/i `"$javaMsi`" /qn /norestart" -Wait
        Remove-Item $javaMsi -Force -ErrorAction SilentlyContinue
    }
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    $javaw = Get-Command javaw.exe -ErrorAction SilentlyContinue
    if (-not $javaw) {
        $fallbackJavaw = Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Filter "javaw.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($fallbackJavaw) { $javaw = Get-Command $fallbackJavaw.FullName }
    }
    if (-not $javaw) {
        throw "Java installation failed. Please install Java 21+ from https://adoptium.net and run again."
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

# 3. Stop running BillSetu & wa-bridge instances if open
Get-CimInstance Win32_Process -Filter "Name = 'javaw.exe' OR Name = 'java.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*BillSetu.jar*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*wa-bridge*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# 4. Download BillSetu.jar, icon, and libs.zip
Write-Host "Downloading BillSetu v$($verInfo.version)..." -ForegroundColor Gray
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

# 5. Install Node.js (if missing) & WhatsApp Bridge
Write-Host "Checking Node.js for WhatsApp integration..." -ForegroundColor Cyan
try {
    $nodeExe = "C:\Program Files\nodejs\node.exe"
    if (-not (Get-Command node -ErrorAction SilentlyContinue) -and -not (Test-Path $nodeExe)) {
        Write-Host "Installing Node.js LTS..." -ForegroundColor Yellow
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements | Out-Null
        } else {
            $nodeMsi = Join-Path $env:TEMP "node-lts.msi"
            Invoke-WebRequest -Uri "https://nodejs.org/dist/v22.14.0/node-v22.14.0-x64.msi" -OutFile $nodeMsi -UseBasicParsing
            Start-Process msiexec.exe -ArgumentList "/i `"$nodeMsi`" /qn /norestart" -Wait
            Remove-Item $nodeMsi -Force -ErrorAction SilentlyContinue
        }
    }

    $waDir = Join-Path $installDir "wa-bridge"
    New-Item -ItemType Directory -Force -Path $waDir | Out-Null
    $waZip = Join-Path $env:TEMP "wa-bridge.zip"
    Invoke-WebRequest -Uri $waUrl -OutFile $waZip -UseBasicParsing
    Expand-Archive -Path $waZip -DestinationPath $waDir -Force
    Remove-Item $waZip -Force -ErrorAction SilentlyContinue

    $npmCmd = if (Test-Path "C:\Program Files\nodejs\npm.cmd") { "C:\Program Files\nodejs\npm.cmd" } else { "npm.cmd" }
    Push-Location $waDir
    & $npmCmd install --omit=dev --silent
    Pop-Location
} catch {
    Write-Host "WhatsApp Bridge setup skipped: $_" -ForegroundColor DarkYellow
}

# 6. Create Desktop & Start Menu shortcuts
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
