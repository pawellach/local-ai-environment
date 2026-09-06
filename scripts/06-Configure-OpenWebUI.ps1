#Requires -Version 5.1
<#
.SYNOPSIS
    Configures Open-WebUI to connect to the local Ollama instance.

.DESCRIPTION
    Sets the OLLAMA_BASE_URL environment variable (user scope), verifies Ollama
    is running, optionally starts Open-WebUI, and validates the full connection chain:
    Open-WebUI -> Ollama -> installed model.

.PARAMETER DryRun
    Show configuration steps without modifying environment or starting services.

.PARAMETER NonInteractive
    Skip interactive prompts.

.PARAMETER OllamaUrl
    Ollama API URL. Default: http://localhost:11434

.PARAMETER OpenWebUIPort
    Port for Open-WebUI. Default: 3000

.EXAMPLE
    .\06-Configure-OpenWebUI.ps1
    .\06-Configure-OpenWebUI.ps1 -OpenWebUIPort 8080 -DryRun
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$NonInteractive,
    [string]$OllamaUrl    = "http://localhost:11434",
    [int]$OpenWebUIPort   = 3000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$OutputPath  = Join-Path $ProjectRoot "reports"

Import-Module "$ProjectRoot\modules\Logging.psm1"       -Force
Import-Module "$ProjectRoot\modules\System.psm1"        -Force
Import-Module "$ProjectRoot\modules\Validation.psm1"    -Force
Import-Module "$ProjectRoot\modules\Configuration.psm1" -Force

$logFile = Initialize-Log -ScriptName "06-Configure-OpenWebUI" -LogDir (Join-Path $ProjectRoot "logs")

try {
    Write-Log "=== Open-WebUI Configuration Started ===" -Level INFO

    # --- Verify Ollama ---
    Write-Host "`n=== Checking Ollama ===" -ForegroundColor Cyan
    $ollamaPort   = Test-PortListening -Port 11434
    $ollamaApi    = if ($ollamaPort) { Test-HttpEndpoint -Url $OllamaUrl -TimeoutSecs 5 } else { @{ Success = $false; Error = "Port closed" } }

    if ($ollamaApi.Success) {
        Write-Host "  Ollama API: $OllamaUrl  [OK]" -ForegroundColor Green
        Write-Log "Ollama API is responding." -Level SUCCESS
    } else {
        Write-Host "  Ollama API: $OllamaUrl  [NOT RUNNING]" -ForegroundColor Red
        Write-Host "  Start Ollama from the tray or run: ollama serve" -ForegroundColor Yellow
        Write-Log "Ollama not reachable at $OllamaUrl. Exiting." -Level ERROR
        exit 1
    }

    # --- Set OLLAMA_BASE_URL ---
    Write-Host "`n=== Setting OLLAMA_BASE_URL ===" -ForegroundColor Cyan
    $currentVal = [System.Environment]::GetEnvironmentVariable("OLLAMA_BASE_URL", "User")

    if ($currentVal -eq $OllamaUrl) {
        Write-Host "  OLLAMA_BASE_URL already set to $OllamaUrl" -ForegroundColor Green
        Write-Log "OLLAMA_BASE_URL already correct." -Level INFO
    } else {
        if (-not $DryRun) {
            [System.Environment]::SetEnvironmentVariable("OLLAMA_BASE_URL", $OllamaUrl, "User")
            $env:OLLAMA_BASE_URL = $OllamaUrl
            Write-Host "  OLLAMA_BASE_URL set to $OllamaUrl (user scope)" -ForegroundColor Green
            Write-Log "OLLAMA_BASE_URL set to $OllamaUrl" -Level SUCCESS
        } else {
            Write-Host "  [DryRun] Would set OLLAMA_BASE_URL=$OllamaUrl" -ForegroundColor DarkGray
            Write-Log "DryRun: would set OLLAMA_BASE_URL=$OllamaUrl" -Level DEBUG
        }
    }

    # --- Check Open-WebUI installation ---
    Write-Host "`n=== Checking Open-WebUI ===" -ForegroundColor Cyan
    $owuInstalled = $false
    try {
        $pipShow = & python -m pip show open-webui 2>&1
        $owuInstalled = ($LASTEXITCODE -eq 0)
    } catch {}

    if (-not $owuInstalled) {
        Write-Host "  Open-WebUI is not installed. Run 03-Install-OpenWebUI.ps1 first." -ForegroundColor Red
        Write-Log "Open-WebUI not installed." -Level ERROR
        exit 1
    }
    Write-Host "  Open-WebUI is installed." -ForegroundColor Green

    # --- Check if already running ---
    $owuRunning = Test-PortListening -Port $OpenWebUIPort
    $owuApi     = $null

    if ($owuRunning) {
        $owuApi = Test-HttpEndpoint -Url "http://localhost:$OpenWebUIPort" -TimeoutSecs 5
        if ($owuApi.Success) {
            Write-Host "  Open-WebUI is already running on port $OpenWebUIPort  [OK]" -ForegroundColor Green
            Write-Log "Open-WebUI already running." -Level INFO
        }
    }

    if (-not $owuRunning -and -not $DryRun) {
        Write-Host "  Open-WebUI is not running on port $OpenWebUIPort." -ForegroundColor Yellow

        $startNow = $true
        if (-not $NonInteractive) {
            $startNow = Get-UserConfirmation -Prompt "  Start Open-WebUI now? [Y/N]"
        }

        if ($startNow) {
            Write-Host "  Starting Open-WebUI in background..." -ForegroundColor Cyan
            Write-Log "Starting Open-WebUI on port $OpenWebUIPort" -Level INFO

            $env:OLLAMA_BASE_URL = $OllamaUrl
            $job = Start-Job -ScriptBlock {
                param($port)
                $env:OLLAMA_BASE_URL = "http://localhost:11434"
                & open-webui serve --port $port 2>&1
            } -ArgumentList $OpenWebUIPort

            Write-Host "  Waiting for Open-WebUI to become available (up to 30s)..." -ForegroundColor DarkGray
            $timeout = 30
            $ready   = $false
            for ($i = 0; $i -lt $timeout; $i++) {
                Start-Sleep -Seconds 1
                if (Test-PortListening -Port $OpenWebUIPort) {
                    $ready = $true
                    break
                }
                Write-Host "  ." -NoNewline -ForegroundColor DarkGray
            }
            Write-Host ""

            if ($ready) {
                $owuApi    = Test-HttpEndpoint -Url "http://localhost:$OpenWebUIPort" -TimeoutSecs 5
                $owuRunning = $true
                Write-Host "  Open-WebUI is running." -ForegroundColor Green
                Write-Log "Open-WebUI started successfully." -Level SUCCESS
            } else {
                Write-Host "  Open-WebUI did not start within 30 seconds." -ForegroundColor Yellow
                Write-Host "  Start manually: .\Start-OpenWebUI.ps1" -ForegroundColor DarkGray
                Write-Log "Open-WebUI did not start in time." -Level WARNING
            }
        } else {
            Write-Host "  You can start Open-WebUI later with: .\Start-OpenWebUI.ps1" -ForegroundColor DarkGray
        }
    }

    # --- Connection Summary ---
    Write-Host "`n=== CONNECTION SUMMARY ===" -ForegroundColor Yellow
    Write-Host ("  Ollama API       : {0,-30} [{1}]" -f $OllamaUrl,     (if ($ollamaApi.Success) { "RUNNING" } else { "DOWN" }))
    Write-Host ("  Open-WebUI       : {0,-30} [{1}]" -f "http://localhost:$OpenWebUIPort", (if ($owuRunning) { "RUNNING" } else { "NOT STARTED" }))
    if ($owuRunning) {
        Write-Host "  Browser URL      : http://localhost:$OpenWebUIPort" -ForegroundColor Green
    }

    # --- Report ---
    $reportData = @{
        GeneratedAt      = (Get-Date -Format "o")
        OllamaUrl        = $OllamaUrl
        OllamaRunning    = $ollamaApi.Success
        OpenWebUIPort    = $OpenWebUIPort
        OpenWebUIRunning = $owuRunning
        DryRun           = $DryRun.IsPresent
    }
    $mdContent = @(
        "# Open-WebUI Configuration Report",
        "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "",
        "| Service | URL | Status |",
        "|---------|-----|--------|",
        "| Ollama API | $OllamaUrl | $(if ($ollamaApi.Success) { '✅ Running' } else { '❌ Down' }) |",
        "| Open-WebUI | http://localhost:$OpenWebUIPort | $(if ($owuRunning) { '✅ Running' } else { '⬜ Not Started' }) |",
        "",
        "## Start Open-WebUI",
        "```powershell",
        ".\Start-OpenWebUI.ps1",
        "```",
        "",
        "## Environment Variable",
        "``OLLAMA_BASE_URL = $OllamaUrl`` (set in User scope)"
    ) -join "`n"

    if (-not $DryRun) {
        if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
        Save-JsonReport     -Path (Join-Path $OutputPath "openwebui-config-report.json") -Data $reportData
        Save-MarkdownReport -Path (Join-Path $OutputPath "openwebui-config-report.md")  -Content $mdContent
        Write-Log "Reports saved." -Level SUCCESS
    }

    Write-Log "=== Open-WebUI Configuration Complete ===" -Level SUCCESS
    exit 0
}
catch {
    Write-Log "ERROR: $_" -Level ERROR
    exit 1
}
finally {
    Close-Log
}
