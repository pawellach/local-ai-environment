#Requires -Version 5.1
<#
.SYNOPSIS
    Downloads and tests a local LLM model via Ollama.

.DESCRIPTION
    Detects hardware tier, presents appropriate model recommendations from
    config/models.psd1, and downloads the selected model using Ollama.
    Runs a test inference and saves the result.

.PARAMETER DryRun
    Show recommendations and selected model without downloading.

.PARAMETER NonInteractive
    Skip prompts. Automatically selects the first recommended model for the detected tier.

.PARAMETER ModelOverride
    Specify an exact Ollama model tag to use instead of the recommendation (e.g. "llama3.2:3b").

.EXAMPLE
    .\05-Configure-Local-LLM.ps1
    .\05-Configure-Local-LLM.ps1 -ModelOverride "qwen2.5:7b"
    .\05-Configure-Local-LLM.ps1 -DryRun -NonInteractive
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$NonInteractive,
    [string]$ModelOverride = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$OutputPath  = Join-Path $ProjectRoot "reports"

Import-Module "$ProjectRoot\modules\Logging.psm1"       -Force
Import-Module "$ProjectRoot\modules\System.psm1"        -Force
Import-Module "$ProjectRoot\modules\Validation.psm1"    -Force
Import-Module "$ProjectRoot\modules\Configuration.psm1" -Force

$logFile = Initialize-Log -ScriptName "05-Configure-Local-LLM" -LogDir (Join-Path $ProjectRoot "logs")

try {
    Write-Log "=== Local LLM Configuration Started ===" -Level INFO

    # --- Verify Ollama ---
    if (-not (Test-CommandExists -Command "ollama")) {
        Write-Log "Ollama is not installed. Run 04-Install-Ollama.ps1 first." -Level ERROR
        Write-Host "`n  Ollama not found. Run 04-Install-Ollama.ps1 first." -ForegroundColor Red
        exit 1
    }
    if (-not (Test-PortListening -Port 11434)) {
        Write-Log "Ollama API not running on port 11434." -Level WARNING
        Write-Host "`n  Ollama is not running. Start it from the system tray or run 'ollama serve'." -ForegroundColor Yellow
        exit 1
    }

    # --- Determine hardware tier ---
    $tier = $null
    $sysReportPath = Join-Path $OutputPath "system-report.json"
    if (Test-Path $sysReportPath) {
        try {
            $sysReport = Get-Content $sysReportPath -Raw | ConvertFrom-Json
            $tier = $sysReport.HardwareTier
            Write-Log "Hardware tier from system-report.json: $tier" -Level INFO
        } catch {
            Write-Log "Could not read system-report.json, re-detecting hardware." -Level WARNING
        }
    }
    if (-not $tier) {
        $tier = Get-HardwareTier
        Write-Log "Hardware tier detected: $tier" -Level INFO
    }

    Write-Host "`n  Hardware Tier: $tier" -ForegroundColor Cyan

    # --- Load model config ---
    $modelsCfgPath = Join-Path $ProjectRoot "config\models.psd1"
    if (-not (Test-Path $modelsCfgPath)) {
        Write-Log "models.psd1 not found at $modelsCfgPath" -Level ERROR
        exit 1
    }
    $modelsCfg = Import-PowerShellDataFile $modelsCfgPath
    $candidates = $modelsCfg[$tier]

    # --- Select model ---
    $selectedTag = ""
    $selectedModel = $null

    if ($ModelOverride) {
        $selectedTag = $ModelOverride.Trim()
        $selectedModel = @{ Name = $selectedTag; OllamaTag = $selectedTag; ApproximateSizeGB = "?"; Description = "User override" }
        Write-Host "  Model override: $selectedTag" -ForegroundColor Yellow
        Write-Log "Using model override: $selectedTag" -Level INFO
    } elseif ($NonInteractive) {
        $selectedModel = $candidates[0]
        $selectedTag   = $selectedModel.OllamaTag
        Write-Host "  Non-interactive: auto-selected $selectedTag" -ForegroundColor DarkGray
        Write-Log "Non-interactive: selected $selectedTag" -Level INFO
    } else {
        Write-Host "`n  Recommended models for '$tier' hardware:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host ("  {0,-3} {1,-22} {2,-8} {3,-8} {4}" -f "#", "Tag", "Size(GB)", "MinRAM", "Description")
        Write-Host ("  " + ("-" * 75))
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            $m = $candidates[$i]
            Write-Host ("  {0,-3} {1,-22} {2,-8} {3,-8} {4}" -f ($i+1), $m.OllamaTag, $m.ApproximateSizeGB, "$($m.MinRAMGB)GB", $m.Description)
        }
        Write-Host ""
        Write-Host "  Enter number (1-$($candidates.Count)) or type a custom Ollama tag (e.g. mistral:latest):" -NoNewline
        $choice = Read-Host " "
        if ($choice -match '^\d+$') {
            $idx = [int]$choice - 1
            if ($idx -ge 0 -and $idx -lt $candidates.Count) {
                $selectedModel = $candidates[$idx]
                $selectedTag   = $selectedModel.OllamaTag
            }
        }
        if (-not $selectedTag) {
            $selectedTag   = $choice.Trim()
            $selectedModel = @{ Name = $selectedTag; OllamaTag = $selectedTag; ApproximateSizeGB = "?"; Description = "Custom" }
        }
    }

    # --- Confirm download ---
    Write-Host "`n  Selected model : $selectedTag"
    Write-Host "  Approx size    : $($selectedModel.ApproximateSizeGB) GB"
    Write-Host "  Description    : $($selectedModel.Description)"

    if (-not $DryRun) {
        if (-not $NonInteractive) {
            $ok = Get-UserConfirmation -Prompt "`n  Download and install this model? [Y/N]"
            if (-not $ok) {
                Write-Log "User cancelled model download." -Level INFO
                Write-Host "`n  Cancelled." -ForegroundColor Yellow
                exit 0
            }
        }

        # --- Pull model ---
        Write-Host "`n  Pulling model: $selectedTag" -ForegroundColor Cyan
        Write-Log "Running: ollama pull $selectedTag" -Level INFO
        & ollama pull $selectedTag
        if ($LASTEXITCODE -ne 0) {
            Write-Log "ollama pull failed." -Level ERROR
            exit 1
        }
        Write-Log "Model pull complete." -Level SUCCESS

        # --- Test inference ---
        Write-Host "`n  Running test inference..." -ForegroundColor Cyan
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $testResult = & ollama run $selectedTag "Respond with exactly: TEST_OK" 2>&1
        $sw.Stop()
        $elapsedMs = $sw.ElapsedMilliseconds
        $testPassed = ($testResult -join " ") -match "TEST_OK"

        if ($testPassed) {
            Write-Host "  Test PASSED in $($elapsedMs)ms" -ForegroundColor Green
            Write-Log "Test inference PASSED ($elapsedMs ms)" -Level SUCCESS
        } else {
            Write-Host "  Test returned unexpected output (may still be working):" -ForegroundColor Yellow
            Write-Host "  $($testResult | Select-Object -First 3 | Out-String)" -ForegroundColor DarkGray
            Write-Log "Test inference produced unexpected output." -Level WARNING
        }

        $testData = @{
            Model      = $selectedTag
            Passed     = $testPassed
            ElapsedMs  = $elapsedMs
            Output     = ($testResult -join "`n") | Select-Object -First 500
            RunAt      = (Get-Date -Format "o")
        }
        if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
        Save-JsonReport -Path (Join-Path $OutputPath "llm-test-result.json") -Data $testData
    } else {
        Write-Log "DryRun: would run 'ollama pull $selectedTag' and test inference." -Level DEBUG
        Write-Host "`n  [DryRun] Would download and test $selectedTag" -ForegroundColor DarkGray
    }

    # --- Final report ---
    $reportData = @{
        GeneratedAt   = (Get-Date -Format "o")
        HardwareTier  = $tier
        SelectedModel = $selectedTag
        ModelDetails  = $selectedModel
        DryRun        = $DryRun.IsPresent
    }
    $mdContent = @(
        "# Local LLM Configuration Report",
        "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "",
        "| Field | Value |",
        "|-------|-------|",
        "| Hardware Tier | $tier |",
        "| Selected Model | $selectedTag |",
        "| Approx Size | $($selectedModel.ApproximateSizeGB) GB |",
        "| DryRun | $($DryRun.IsPresent) |",
        "",
        "## Test Model",
        "```",
        "ollama run $selectedTag",
        "```"
    ) -join "`n"

    if (-not $DryRun) {
        Save-JsonReport     -Path (Join-Path $OutputPath "llm-config-report.json") -Data $reportData
        Save-MarkdownReport -Path (Join-Path $OutputPath "llm-config-report.md")  -Content $mdContent
        Write-Log "Reports saved." -Level SUCCESS
    }

    Write-Log "=== Local LLM Configuration Complete ===" -Level SUCCESS
    exit 0
}
catch {
    Write-Log "ERROR: $_" -Level ERROR
    exit 1
}
finally {
    Close-Log
}
