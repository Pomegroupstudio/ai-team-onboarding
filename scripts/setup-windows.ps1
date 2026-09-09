# ==============================================================================
# Pome Studio - Agentic AI 1-Click Setup for Windows
# Configures VS Code, Ripgrep, Roo Code & DeepSeek Workspace in < 60 seconds
# ==============================================================================

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   🚀 Pome Studio - Agentic AI 1-Click Windows Setup      " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Continue"

# ------------------------------------------------------------------------------
# STEP 1: Verify Network & DeepSeek API Access (VPN / Proxy Check)
# ------------------------------------------------------------------------------
Write-Host "[1/5] Checking connection to DeepSeek API..." -ForegroundColor Yellow
$networkOk = $false
try {
    $resp = curl.exe -I -s --max-time 6 https://api.deepseek.com 2>&1
    if ($resp -match "HTTP/\S+\s+(200|401|403|404)") {
        $networkOk = $true
        Write-Host "      [OK] Successfully connected to DeepSeek API!" -ForegroundColor Green
    }
} catch {
    $networkOk = $false
}

if (-not $networkOk) {
    Write-Host "      [!] WARNING: Could not reach https://api.deepseek.com" -ForegroundColor Red
    Write-Host "      Please ensure your VPN / v2rayN is turned ON with 'System Proxy' enabled." -ForegroundColor Yellow
    Write-Host "      (لطفاً مطمئن شوید فیلترشکن یا v2rayN روشن است و در حالت System Proxy قرار دارد)" -ForegroundColor Magenta
    Write-Host ""
    $continue = Read-Host "Do you want to continue anyway? (y/n)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Host "Setup aborted. Reconnect VPN and run this script again." -ForegroundColor Red
        exit
    }
}

# ------------------------------------------------------------------------------
# STEP 2: Close Running VS Code Instances
# ------------------------------------------------------------------------------
Write-Host "[2/5] Closing running VS Code processes..." -ForegroundColor Yellow
Stop-Process -Name "Code" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Write-Host "      [OK] Clean state ready." -ForegroundColor Green

# ------------------------------------------------------------------------------
# STEP 3: Setup Ripgrep (Zero-Patch Method)
# ------------------------------------------------------------------------------
Write-Host "[3/5] Configuring Ripgrep engine..." -ForegroundColor Yellow

$userBin = "$env:USERPROFILE\bin"
if (-not (Test-Path $userBin)) {
    New-Item -ItemType Directory -Path $userBin -Force | Out-Null
}
$userRg = "$userBin\rg.exe"

# 3a. Search for bundled rg.exe in VS Code or existing copies
$foundRg = (Get-ChildItem -Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code" -Filter "rg.exe" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 500000 } | Select-Object -First 1).FullName

if (-not $foundRg) {
    $foundRg = (Get-ChildItem -Path "C:\Program Files\Microsoft VS Code" -Filter "rg.exe" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 500000 } | Select-Object -First 1).FullName
}

if (-not $foundRg -and (Test-Path "$env:USERPROFILE\rg.exe")) {
    $foundRg = "$env:USERPROFILE\rg.exe"
}

# 3b. If not found locally, download official standalone release
if (-not $foundRg) {
    Write-Host "      Downloading standalone ripgrep binary from GitHub..." -ForegroundColor Cyan
    $zipPath = "$env:TEMP\ripgrep.zip"
    $rgUrl = "https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-x86_64-pc-windows-msvc.zip"
    try {
        curl.exe -L -o $zipPath $rgUrl --max-time 20
        tar.exe -xf $zipPath -C "$env:TEMP"
        $foundRg = (Get-ChildItem -Path "$env:TEMP" -Filter "rg.exe" -Recurse | Where-Object { $_.Length -gt 500000 } | Select-Object -First 1).FullName
    } catch {
        Write-Host "      Download failed. Will attempt search across C:\..." -ForegroundColor Yellow
        $foundRg = (Get-ChildItem -Path "C:\" -Filter "rg.exe" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 500000 } | Select-Object -First 1).FullName
    }
}

if (-not $foundRg) {
    Write-Host "      [ERROR] Could not find or download rg.exe." -ForegroundColor Red
    exit 1
}

# 3c. Place rg.exe in user bin
Copy-Item $foundRg $userRg -Force
Copy-Item $foundRg "$env:USERPROFILE\rg.exe" -Force

# 3d. Add User bin to permanent PATH if not present
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$userBin*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$userBin", "User")
    $env:Path += ";$userBin"
    Write-Host "      [OK] Added $userBin to User PATH." -ForegroundColor Green
}

# 3e. Distribute rg.exe to all VS Code internal unpacked paths (Zero-Patch Roo Code discovery)
$vsCodeRoots = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code",
    "C:\Program Files\Microsoft VS Code"
)

foreach ($vsRoot in $vsCodeRoots) {
    if (Test-Path $vsRoot) {
        $appDirs = @(Get-ChildItem -Path $vsRoot -Filter "resources" -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path "$($_.FullName)\app" } | ForEach-Object { "$($_.FullName)\app" })
        $appDirs += "$vsRoot\resources\app"
        
        foreach ($appDir in ($appDirs | Select-Object -Unique)) {
            $destTargets = @(
                "$appDir\rg.exe",
                "$appDir\node_modules.asar.unpacked\@vscode\ripgrep\bin\rg.exe",
                "$appDir\node_modules.asar.unpacked\@vscode\ripgrep\bin\win32-x64\rg.exe",
                "$appDir\node_modules.asar.unpacked\vscode-ripgrep\bin\rg.exe"
            )
            foreach ($target in $destTargets) {
                $pDir = Split-Path $target -Parent
                if (-not (Test-Path $pDir)) {
                    New-Item -ItemType Directory -Path $pDir -Force | Out-Null
                }
                Copy-Item $userRg $target -Force
            }
        }
    }
}

# Verify execution
$rgVer = (& $userRg --version 2>&1 | Select-Object -First 1)
Write-Host "      [OK] Ripgrep ready: $rgVer" -ForegroundColor Green

# ------------------------------------------------------------------------------
# STEP 4: Ensure Roo Code Extension Is Installed
# ------------------------------------------------------------------------------
Write-Host "[4/5] Checking Roo Code extension..." -ForegroundColor Yellow
$codeCli = (Get-Command "code" -ErrorAction SilentlyContinue).Source
if (-not $codeCli) {
    $codeCli = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"
    if (-not (Test-Path $codeCli)) {
        $codeCli = "C:\Program Files\Microsoft VS Code\bin\code.cmd"
    }
}

if (Test-Path $codeCli) {
    Write-Host "      Installing/Updating Roo Code extension..." -ForegroundColor Cyan
    & $codeCli --install-extension rooveterinaryinc.roo-cline --force | Out-Null
    Write-Host "      [OK] Roo Code extension installed." -ForegroundColor Green
} else {
    Write-Host "      [!] VS Code CLI not in path. Please verify Roo Code is installed in VS Code Extensions." -ForegroundColor Yellow
}

# ------------------------------------------------------------------------------
# STEP 5: Create Starter Project Workspace & Launch VS Code
# ------------------------------------------------------------------------------
Write-Host "[5/5] Creating starter workspace..." -ForegroundColor Yellow
$workspace = "$env:USERPROFILE\ai-workspace"
if (-not (Test-Path $workspace)) {
    New-Item -ItemType Directory -Path $workspace -Force | Out-Null
}

$readmePath = "$workspace\README.md"
if (-not (Test-Path $readmePath)) {
    @"
# AI Coding Workspace 🚀
Welcome to your agentic AI workspace powered by **Roo Code** and **DeepSeek**!

### Quick Start:
1. Open the **Roo Code** sidebar on the left (Roo icon).
2. Ensure API Provider is **DeepSeek** with your API key.
3. Click **+** (New Task) and type:
   \`Create a modern Pomodoro timer web app with sound and statistics\`
4. Press **Enter** and watch Roo Code build your project!
"@ | Out-File -FilePath $readmePath -Encoding utf8
}

Write-Host "      [OK] Workspace ready at: $workspace" -ForegroundColor Green
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "   🎉 SETUP COMPLETE! Launching VS Code...                " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Golden Rules for Roo Code:" -ForegroundColor Cyan
Write-Host " 1. Always keep a workspace folder open (like $workspace)" -ForegroundColor White
Write-Host " 2. Keep your VPN / v2rayN system proxy active" -ForegroundColor White
Write-Host " 3. Use 'deepseek-chat' for fast coding or 'deepseek-reasoner' for complex logic" -ForegroundColor White
Write-Host ""

# Launch VS Code directly into the workspace
if (Test-Path $codeCli) {
    & $codeCli $workspace
} else {
    Start-Process "code" -ArgumentList "`"$workspace`"" -ErrorAction SilentlyContinue
}
