#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Ollama — the local LLM runtime for Windows.

.DESCRIPTION
    Installs Ollama using winget (preferred) or direct installer download from ollama.ai.
    Idempotent: skips installation if Ollama is already present.
    Verifies the CLI and local API. Does NOT expose the API to external networks.

.PARAMETER DryRun
    Show what would be done without making changes.

.PARAMETER NonInteractive
    Skip all prompts. Use defaults.

.EXAMPLE
    .\04-Install-Ollama.ps1
    .\04-Install-Ollama.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot  = Split-Path -Parent $PSScriptRoot
$OutputPath   = Join-Path $ProjectRoot "reports"
$OllamaApiUrl = "http://localhost:11434"
$InstallerUrl = "https://ollama.ai/download/OllamaSetup.exe"

Import-Module "$ProjectRoot\modules\Logging.psm1"       -Force
Import-Module "$ProjectRoot\modules\System.psm1"        -Force
Import-Module "$ProjectRoot\modules\Validation.psm1"    -Force
Import-Module "$ProjectRoot\modules\Configuration.psm1" -Force

$logFile = Initialize-Log -ScriptName "04-Install-Ollama" -LogDir (Join-Path $ProjectRoot "logs")

try {
    Write-Log "=== Ollama Installation Started ===" -Level INFO

    # --- Check existing ---
    $alreadyInstalled = Test-CommandExists -Command "ollama"
    $currentVersion   = if ($alreadyInstalled) { Get-CommandVersion -Command "ollama" } else { $null }

    if ($alreadyInstalled) {
        Write-Host "`n  Ollama is already installed: $currentVersion" -ForegroundColor Green
        Write-Log "Ollama already installed ($currentVersion). Skipping install." -Level SUCCESS
    } else {
        Write-Host "`n  Ollama not found. Installing..." -ForegroundColor Cyan

        $installedViaWinget = $false
        if (-not $DryRun) {
            # Try winget first
            $wingetAvailable = Test-CommandExists -Command "winget"
            if ($wingetAvailable) {
                Write-Log "Attempting installation via winget..." -Level INFO
                Write-Host "  Trying winget install..." -ForegroundColor DarkGray
                try {
                    $wingetResult = & winget install --id Ollama.Ollama --silent `
                        --accept-package-agreements --accept-source-agreements 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $installedViaWinget = $true
                        Write-Log "Ollama installed via winget." -Level SUCCESS
                        Write-Host "  Installed via winget." -ForegroundColor Green
                    } else {
                        Write-Log "winget install failed (exit $LASTEXITCODE). Falling back to direct download." -Level WARNING
                    }
                } catch {
                    Write-Log "winget threw an error: $_. Falling back." -Level WARNING
                }
            }

            if (-not $installedViaWinget) {
                # Direct download fallback
                $installerPath = Join-Path $env:TEMP "OllamaSetup.exe"
                Write-Log "Downloading Ollama installer from $InstallerUrl ..." -Level INFO
                Write-Host "  Downloading installer..." -ForegroundColor DarkGray

                try {
                    Invoke-WebRequest -Uri $InstallerUrl -OutFile $installerPath -UseBasicParsing
                    Write-Log "Installer downloaded to $installerPath" -Level INFO
                } catch {
                    Write-Log "Download failed: $_" -Level ERROR
                    Write-Host "  Failed to download installer." -ForegroundColor Red
                    Write-Host "  Download manually from: $InstallerUrl" -ForegroundColor Yellow
                    exit 1
                }

                Write-Log "Running installer silently..." -Level INFO
                Write-Host "  Running installer (this may take a minute)..." -ForegroundColor DarkGray
                Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait -NoNewWindow
                Write-Log "Installer completed." -Level INFO

                # Cleanup installer
                Remove-Item $installerPath -ErrorAction SilentlyContinue
            }
        } else {
            Write-Log "DryRun: would install Ollama via winget or direct download." -Level DEBUG
            Write-Host "  [DryRun] Would install Ollama." -ForegroundColor DarkGray
        }

        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("PATH", "User")
        $currentVersion = if (-not $DryRun) { Get-CommandVersion -Command "ollama" } else { "DryRun" }
        Write-Host "  Ollama installed: $currentVersion" -ForegroundColor Green
    }

    # --- Check API ---
    Write-Host "`n=== Checking Ollama API ===" -ForegroundColor Cyan
    $portOpen   = Test-PortListening -Port 11434
    $apiResult  = if ($portOpen) { Test-HttpEndpoint -Url $OllamaApiUrl } else { @{ Success = $false; Error = "Port not open" } }

    if ($portOpen -and $apiResult.Success) {
        Write-Host "  Ollama API is running at $OllamaApiUrl" -ForegroundColor Green
        Write-Log "Ollama API responding." -Level SUCCESS
    } else {
        Write-Host "  Ollama API is NOT running." -ForegroundColor Yellow
        Write-Host "  To start: find Ollama in the system tray and click 'Start'," -ForegroundColor DarkGray
        Write-Host "  OR run in a terminal: ollama serve" -ForegroundColor DarkGray
        Write-Log "Ollama API not responding. Manual start required." -Level WARNING
    }

    Write-Host "`n  SECURITY NOTE:" -ForegroundColor DarkYellow
    Write-Host "  Ollama listens on localhost:11434 by default (not exposed to LAN)." -ForegroundColor DarkGray
    Write-Host "  Do NOT set OLLAMA_HOST=0.0.0.0 unless you understand the implications." -ForegroundColor DarkGray

    # --- Report ---
    $reportData = @{
        GeneratedAt       = (Get-Date -Format "o")
        OllamaVersion     = $currentVersion
        APIRunning        = ($portOpen -and $apiResult.Success)
        APIUrl            = $OllamaApiUrl
        DryRun            = $DryRun.IsPresent
    }
    $mdContent = @(
        "# Ollama Installation Report",
        "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "",
        "| Field | Value |",
        "|-------|-------|",
        "| Version | $currentVersion |",
        "| API URL | $OllamaApiUrl |",
        "| API Running | $($portOpen -and $apiResult.Success) |",
        "| DryRun | $($DryRun.IsPresent) |",
        "",
        "## Start Ollama",
        "Ollama runs as a tray application. If the API is not responding:",
        "- Launch Ollama from the Start Menu",
        "- Or run: ``ollama serve``",
        "",
        "## Security",
        "By default Ollama binds to `127.0.0.1:11434` — local only."
    ) -join "`n"

    if (-not $DryRun) {
        if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
        Save-JsonReport     -Path (Join-Path $OutputPath "ollama-install-report.json") -Data $reportData
        Save-MarkdownReport -Path (Join-Path $OutputPath "ollama-install-report.md")  -Content $mdContent
        Write-Log "Reports saved." -Level SUCCESS
    }

    Write-Log "=== Ollama Installation Complete ===" -Level SUCCESS
    exit 0
}
catch {
    Write-Log "ERROR: $_" -Level ERROR
    exit 1
}
finally {
    Close-Log
}
