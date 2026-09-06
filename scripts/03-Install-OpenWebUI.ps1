#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Open-WebUI — the local AI web interface (frontend for Ollama).

.DESCRIPTION
    Open-WebUI (https://github.com/open-webui/open-webui) is an open-source
    web interface that connects to Ollama and provides a ChatGPT-style UI.
    Installed via pip. Requires Python 3.11+.

    Also creates a convenience Start-OpenWebUI.ps1 launcher in the project root.

.PARAMETER DryRun
    Show all steps but make no changes to the system.

.PARAMETER NonInteractive
    Skip interactive prompts and use defaults.

.PARAMETER PythonPath
    Path to python.exe if not on PATH.

.PARAMETER Port
    Port for Open-WebUI to listen on. Default: 3000.

.PARAMETER Force
    Reinstall even if already present.

.EXAMPLE
    .\03-Install-OpenWebUI.ps1
    .\03-Install-OpenWebUI.ps1 -DryRun -Verbose
    .\03-Install-OpenWebUI.ps1 -Port 8080
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$NonInteractive,
    [switch]$Force,
    [string]$PythonPath = "python",
    [int]$Port = 3000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$OutputPath  = Join-Path $ProjectRoot "reports"

Import-Module "$ProjectRoot\modules\Logging.psm1"       -Force
Import-Module "$ProjectRoot\modules\Configuration.psm1" -Force

$logFile = Initialize-Log -ScriptName "03-Install-OpenWebUI" -LogDir (Join-Path $ProjectRoot "logs")

function Get-PythonVersion {
    param([string]$Exe)
    try {
        $raw = & $Exe --version 2>&1
        if ($raw -match '(\d+)\.(\d+)') {
            return [int]$Matches[1], [int]$Matches[2]
        }
    } catch {}
    return $null, $null
}

try {
    Write-Log "=== Open-WebUI Installation Started ===" -Level INFO

    # --- Check Python ---
    Write-Host "`n=== Checking Python ===" -ForegroundColor Cyan
    $pyExe = $PythonPath
    $major, $minor = Get-PythonVersion -Exe $pyExe
    if ($null -eq $major) {
        # Try python3
        $major, $minor = Get-PythonVersion -Exe "python3"
        if ($null -ne $major) { $pyExe = "python3" }
    }

    if ($null -eq $major) {
        Write-Log "Python not found." -Level ERROR
        Write-Host "`n  Python is NOT installed or not on PATH." -ForegroundColor Red
        Write-Host "  Open-WebUI requires Python 3.11 or newer." -ForegroundColor Red
        Write-Host "  Download: https://www.python.org/downloads/" -ForegroundColor Yellow
        Write-Host "  During installation, check 'Add Python to PATH'." -ForegroundColor Yellow
        exit 1
    }

    Write-Host "  Python $major.$minor found ($pyExe)" -ForegroundColor Green

    if ($major -lt 3 -or ($major -eq 3 -and $minor -lt 11)) {
        Write-Log "Python $major.$minor is too old. Need 3.11+." -Level ERROR
        Write-Host "`n  Python $major.$minor is installed but Open-WebUI requires 3.11+." -ForegroundColor Red
        Write-Host "  Download the latest Python: https://www.python.org/downloads/" -ForegroundColor Yellow
        exit 1
    }

    # --- Check pip ---
    Write-Host "`n=== Checking pip ===" -ForegroundColor Cyan
    try {
        $pipVer = & $pyExe -m pip --version 2>&1
        Write-Host "  pip found: $pipVer" -ForegroundColor Green
    } catch {
        Write-Log "pip not available." -Level ERROR
        Write-Host "  pip is not available. Run: $pyExe -m ensurepip --upgrade" -ForegroundColor Red
        exit 1
    }

    # --- Check existing installation ---
    $existingVersion = $null
    try {
        $pipShow = & $pyExe -m pip show open-webui 2>&1
        if ($LASTEXITCODE -eq 0) {
            $verLine = $pipShow | Where-Object { $_ -match '^Version:' }
            $existingVersion = ($verLine -replace '^Version:\s*', '').Trim()
        }
    } catch {}

    if ($existingVersion -and -not $Force) {
        Write-Host "`n  Open-WebUI $existingVersion is already installed." -ForegroundColor Green
        Write-Host "  Use -Force to reinstall or upgrade." -ForegroundColor DarkGray
        Write-Log "Open-WebUI $existingVersion already present. Skipping install." -Level SUCCESS
    } else {
        $action = if ($existingVersion) { "Upgrading" } else { "Installing" }
        Write-Host "`n  $action Open-WebUI via pip..." -ForegroundColor Cyan

        if (-not $DryRun) {
            $installCmd = if ($existingVersion) {
                "$pyExe -m pip install --upgrade open-webui"
            } else {
                "$pyExe -m pip install open-webui"
            }
            Write-Log "Running: $installCmd" -Level INFO
            Invoke-Expression $installCmd
            if ($LASTEXITCODE -ne 0) {
                Write-Log "pip install failed." -Level ERROR
                Write-Host "  Installation failed. Check the output above." -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Log "DryRun: would run: $pyExe -m pip install open-webui" -Level DEBUG
        }

        # Verify
        $installedVersion = $null
        if (-not $DryRun) {
            try {
                $pipShow2 = & $pyExe -m pip show open-webui 2>&1
                $verLine2  = $pipShow2 | Where-Object { $_ -match '^Version:' }
                $installedVersion = ($verLine2 -replace '^Version:\s*', '').Trim()
                Write-Host "  Open-WebUI $installedVersion installed successfully." -ForegroundColor Green
                Write-Log "Installed Open-WebUI $installedVersion" -Level SUCCESS
            } catch {
                Write-Log "Could not verify installation." -Level WARNING
            }
        }
    }

    # --- Create launcher script ---
    $launcherPath = Join-Path $ProjectRoot "Start-OpenWebUI.ps1"
    $launcherContent = @"
# Start Open-WebUI connected to local Ollama instance
# Run this script to launch the web interface, then open http://localhost:$Port in your browser

`$env:OLLAMA_BASE_URL = "http://localhost:11434"
`$env:DATA_DIR = "`$env:USERPROFILE\.open-webui"

Write-Host "Starting Open-WebUI on port $Port..." -ForegroundColor Cyan
Write-Host "Open in browser: http://localhost:$Port" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray

open-webui serve --port $Port
"@

    if (-not $DryRun) {
        Set-Content -Path $launcherPath -Value $launcherContent -Encoding UTF8
        Write-Log "Created launcher: $launcherPath" -Level SUCCESS
    } else {
        Write-Log "DryRun: would create launcher at $launcherPath" -Level DEBUG
    }

    Write-Host "`n=== NEXT STEPS ===" -ForegroundColor Yellow
    Write-Host "  1. Run 04-Install-Ollama.ps1 to install the Ollama runtime."
    Write-Host "  2. Run 05-Configure-Local-LLM.ps1 to download a model."
    Write-Host "  3. Start Open-WebUI with: .\Start-OpenWebUI.ps1"
    Write-Host "  4. Open http://localhost:$Port in your browser."
    Write-Host ""
    Write-Host "  To set OLLAMA_BASE_URL permanently (run in PowerShell):"
    Write-Host "  [System.Environment]::SetEnvironmentVariable('OLLAMA_BASE_URL','http://localhost:11434','User')" -ForegroundColor DarkCyan

    # --- Report ---
    $reportData = @{
        GeneratedAt       = (Get-Date -Format "o")
        PythonExecutable  = $pyExe
        PythonVersion     = "$major.$minor"
        OpenWebUIVersion  = if ($existingVersion) { $existingVersion } else { "installed" }
        Port              = $Port
        LauncherPath      = $launcherPath
        DryRun            = $DryRun.IsPresent
    }
    $mdContent = @(
        "# Open-WebUI Installation Report",
        "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "",
        "| Field | Value |",
        "|-------|-------|",
        "| Python | $pyExe ($major.$minor) |",
        "| Open-WebUI | $($reportData.OpenWebUIVersion) |",
        "| Port | $Port |",
        "| Launcher | $launcherPath |",
        "| DryRun | $($DryRun.IsPresent) |",
        "",
        "## How to Start",
        "```powershell",
        ".\Start-OpenWebUI.ps1",
        "```",
        "Then open: http://localhost:$Port"
    ) -join "`n"

    if (-not $DryRun) {
        if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
        Save-JsonReport     -Path (Join-Path $OutputPath "openwebui-install-report.json") -Data $reportData
        Save-MarkdownReport -Path (Join-Path $OutputPath "openwebui-install-report.md")  -Content $mdContent
        Write-Log "Reports saved." -Level SUCCESS
    }

    Write-Log "=== Open-WebUI Installation Complete ===" -Level SUCCESS
    exit 0
}
catch {
    Write-Log "ERROR: $_" -Level ERROR
    exit 1
}
finally {
    Close-Log
}
