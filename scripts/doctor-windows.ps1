# ==============================================================================
# Pome Studio - Roo Code & DeepSeek Diagnostic Doctor (Windows)
# Use this script anytime Roo Code gets stuck or freezes
# ==============================================================================

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   🩺 Roo Code & DeepSeek Diagnostic Doctor (Windows)     " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true

# 1. Network / VPN Check
Write-Host "Checking [1/4] DeepSeek API Connectivity..." -NoNewline
try {
    $curlResp = curl.exe -I -s --max-time 5 https://api.deepseek.com 2>&1
    if ($curlResp -match "HTTP/\S+\s+(200|401|403|404)") {
        Write-Host " [PASS]" -ForegroundColor Green
    } else {
        Write-Host " [FAIL]" -ForegroundColor Red
        Write-Host "   -> Cannot reach https://api.deepseek.com" -ForegroundColor Yellow
        Write-Host "   -> Fix: Turn on v2rayN / VPN and verify 'System Proxy' is active." -ForegroundColor Yellow
        $allPassed = $false
    }
} catch {
    Write-Host " [FAIL]" -ForegroundColor Red
    $allPassed = $false
}

# 2. Ripgrep Engine Check
Write-Host "Checking [2/4] Ripgrep Search Engine..." -NoNewline
$rgPath = (Get-Command "rg" -ErrorAction SilentlyContinue).Source
if (-not $rgPath -and (Test-Path "$env:USERPROFILE\bin\rg.exe")) {
    $rgPath = "$env:USERPROFILE\bin\rg.exe"
}
if (-not $rgPath -and (Test-Path "$env:USERPROFILE\rg.exe")) {
    $rgPath = "$env:USERPROFILE\rg.exe"
}

if ($rgPath) {
    try {
        $rgVer = (& $rgPath --version 2>&1 | Select-Object -First 1)
        Write-Host " [PASS] ($rgVer)" -ForegroundColor Green
    } catch {
        Write-Host " [FAIL]" -ForegroundColor Red
        Write-Host "   -> Found rg at $rgPath, but failed to execute." -ForegroundColor Yellow
        $allPassed = $false
    }
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    Write-Host "   -> Ripgrep binary not found in PATH or User Profile." -ForegroundColor Yellow
    Write-Host "   -> Fix: Run the 1-click setup script: irm https://pomegroupstudio.github.io/ai-team-onboarding/scripts/setup-windows.ps1 | iex" -ForegroundColor Cyan
    $allPassed = $false
}

# 3. VS Code & Roo Code Extension Check
Write-Host "Checking [3/4] Roo Code Extension Installation..." -NoNewline
$extPath = "$env:USERPROFILE\.vscode\extensions"
$rooExt = Get-ChildItem -Path $extPath -Filter "rooveterinaryinc.roo-cline-*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1

if ($rooExt) {
    Write-Host " [PASS] ($($rooExt.Name))" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    Write-Host "   -> Roo Code extension folder not found under $extPath" -ForegroundColor Yellow
    Write-Host "   -> Fix: Open VS Code, go to Extensions (Ctrl+Shift+X), search for 'Roo Code', and click Install." -ForegroundColor Yellow
    $allPassed = $false
}

# 4. Project Workspace Check
Write-Host "Checking [4/4] Project Workspace..." -NoNewline
$workspace = "$env:USERPROFILE\ai-workspace"
if (Test-Path $workspace) {
    Write-Host " [PASS] ($workspace exists)" -ForegroundColor Green
} else {
    Write-Host " [WARN]" -ForegroundColor Yellow
    Write-Host "   -> No default ai-workspace found at $workspace" -ForegroundColor Yellow
    Write-Host "   -> Reminder: Roo Code requires an OPEN FOLDER in VS Code (File > Open Folder)." -ForegroundColor White
}

Write-Host ""
Write-Host "----------------------------------------------------------" -ForegroundColor Gray
if ($allPassed) {
    Write-Host "✨ All core components are HEALTHY! If Roo Code is still stuck:" -ForegroundColor Green
    Write-Host "   1. Ensure a folder is open in VS Code (File > Open Folder)" -ForegroundColor White
    Write-Host "   2. Click the gear icon in Roo Code and verify your DeepSeek API Key" -ForegroundColor White
    Write-Host "   3. Reload VS Code (Help > Toggle Developer Tools > Console to check errors)" -ForegroundColor White
} else {
    Write-Host "⚠️ Issues detected! Run the 1-click automatic repair script:" -ForegroundColor Yellow
    Write-Host "   irm https://pomegroupstudio.github.io/ai-team-onboarding/scripts/setup-windows.ps1 | iex" -ForegroundColor Cyan
}
Write-Host "----------------------------------------------------------" -ForegroundColor Gray
Write-Host ""
