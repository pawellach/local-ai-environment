#Requires -Version 5.1
<#
.SYNOPSIS
    Validates the complete local AI environment.

.DESCRIPTION
    Tests each component of the stack and reports PASS / WARNING / FAIL for each.
    Saves a validation report to reports/validation-report.md and .json.
    Exit code 1 if any component FAILs.

.PARAMETER DryRun
    Run checks without saving reports.

.PARAMETER NonInteractive
    Skip prompts.

.PARAMETER SkipLLMTest
    Skip the test inference (useful if Ollama is running but no model is present).

.EXAMPLE
    .\07-Validate-Environment.ps1
    .\07-Validate-Environment.ps1 -SkipLLMTest -Verbose
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$NonInteractive,
    [switch]$SkipLLMTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$OutputPath  = Join-Path $ProjectRoot "reports"

Import-Module "$ProjectRoot\modules\Logging.psm1"       -Force
Import-Module "$ProjectRoot\modules\System.psm1"        -Force
Import-Module "$ProjectRoot\modules\Validation.psm1"    -Force
Import-Module "$ProjectRoot\modules\Configuration.psm1" -Force

$logFile = Initialize-Log -ScriptName "07-Validate-Environment" -LogDir (Join-Path $ProjectRoot "logs")

$results = @()

function Add-Check {
    param([string]$Component, [string]$Status, [string]$Message, [string]$Detail = "")
    $r = New-ValidationResult -Component $Component -Status $Status -Message $Message -Detail $Detail
    $script:results += $r
    $icon = switch ($Status) {
        "PASS"    { "✅" }
        "WARNING" { "⚠️" }
        "FAIL"    { "❌" }
    }
    $color = switch ($Status) { "PASS" { "Green" } "WARNING" { "Yellow" } "FAIL" { "Red" } }
    Write-Host ("  {0} {1,-28} {2}" -f $icon, $Component, $Message) -ForegroundColor $color
    Write-Log "$Status $Component : $Message" -Level $(if ($Status -eq "FAIL") { "ERROR" } elseif ($Status -eq "WARNING") { "WARNING" } else { "INFO" })
}

try {
    Write-Log "=== Environment Validation Started ===" -Level INFO
    Write-Host "`n=== ENVIRONMENT VALIDATION ===" -ForegroundColor Cyan
    Write-Host ""

    # 1. PowerShell version
    $psVer = $PSVersionTable.PSVersion
    if ($psVer.Major -ge 5 -and ($psVer.Major -gt 5 -or $psVer.Minor -ge 1)) {
        Add-Check "PowerShell" "PASS" "v$($psVer.ToString())"
    } else {
        Add-Check "PowerShell" "FAIL" "v$($psVer.ToString()) — need 5.1+"
    }

    # 2. Git
    $gitVer = Get-CommandVersion -Command "git"
    if ($gitVer) {
        Add-Check "Git" "PASS" $gitVer
    } else {
        Add-Check "Git" "WARNING" "Not installed (optional for this stack)"
    }

    # 3. Python 3.11+
    $pyVer = $null
    foreach ($exe in @("python","python3")) {
        try {
            $raw = & $exe --version 2>&1
            if ($raw -match '(\d+)\.(\d+)') {
                $major = [int]$Matches[1]; $minor = [int]$Matches[2]
                if ($major -gt 3 -or ($major -eq 3 -and $minor -ge 11)) {
                    $pyVer = "$major.$minor"
                    break
                }
            }
        } catch {}
    }
    if ($pyVer) {
        Add-Check "Python" "PASS" "v$pyVer"
    } else {
        Add-Check "Python" "FAIL" "Python 3.11+ not found"
    }

    # 4. pip
    $pipOk = $false
    try { $pipOk = (& python -m pip --version 2>&1) -ne $null -and $LASTEXITCODE -eq 0 } catch {}
    if ($pipOk) {
        Add-Check "pip" "PASS" "Available"
    } else {
        Add-Check "pip" "FAIL" "pip not available"
    }

    # 5. Open-WebUI installed
    $owuVersion = $null
    try {
        $pipShow = & python -m pip show open-webui 2>&1
        if ($LASTEXITCODE -eq 0) {
            $verLine = $pipShow | Where-Object { $_ -match '^Version:' }
            $owuVersion = ($verLine -replace '^Version:\s*', '').Trim()
        }
    } catch {}
    if ($owuVersion) {
        Add-Check "Open-WebUI (installed)" "PASS" "v$owuVersion"
    } else {
        Add-Check "Open-WebUI (installed)" "FAIL" "Not installed — run 03-Install-OpenWebUI.ps1"
    }

    # 6. Ollama CLI
    $ollamaVer = Get-CommandVersion -Command "ollama"
    if ($ollamaVer) {
        Add-Check "Ollama CLI" "PASS" $ollamaVer
    } else {
        Add-Check "Ollama CLI" "FAIL" "Not found — run 04-Install-Ollama.ps1"
    }

    # 7. Ollama API
    $ollamaApi = Test-HttpEndpoint -Url "http://localhost:11434" -TimeoutSecs 5
    if ($ollamaApi.Success) {
        Add-Check "Ollama API" "PASS" "Responding at localhost:11434"
    } else {
        Add-Check "Ollama API" "FAIL" "Not responding — start Ollama from tray or run 'ollama serve'"
    }

    # 8. Models installed
    $modelCount = 0
    $firstModel = ""
    if ($ollamaApi.Success) {
        try {
            $modelList = & ollama list 2>&1
            $modelLines = ($modelList | Select-String -Pattern '^\S').Matches
            $modelCount = ($modelList | Where-Object { $_ -match '^\w' -and $_ -notmatch '^NAME' }).Count
            $firstModel = ($modelList | Where-Object { $_ -match '^\w' -and $_ -notmatch '^NAME' } | Select-Object -First 1) -replace '\s.*', ''
        } catch {}
    }
    if ($modelCount -gt 0) {
        Add-Check "Ollama Models" "PASS" "$modelCount model(s) installed ($firstModel ...)"
    } elseif ($ollamaApi.Success) {
        Add-Check "Ollama Models" "WARNING" "No models installed — run 05-Configure-Local-LLM.ps1"
    } else {
        Add-Check "Ollama Models" "WARNING" "Cannot check — Ollama not running"
    }

    # 9. LLM inference
    if (-not $SkipLLMTest -and $modelCount -gt 0 -and $ollamaApi.Success) {
        Write-Host "  Running inference test (may take 10-30s)..." -ForegroundColor DarkGray
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $testOut = & ollama run $firstModel "Reply with exactly: TEST_OK" 2>&1
            $sw.Stop()
            $passed = ($testOut -join " ") -match "TEST_OK"
            if ($passed) {
                Add-Check "LLM Inference" "PASS" "Responded in $($sw.ElapsedMilliseconds)ms"
            } else {
                Add-Check "LLM Inference" "WARNING" "Responded but unexpected output ($($sw.ElapsedMilliseconds)ms)"
            }
        } catch {
            Add-Check "LLM Inference" "FAIL" "Inference error: $_"
        }
    } elseif ($SkipLLMTest) {
        Add-Check "LLM Inference" "WARNING" "Skipped (-SkipLLMTest)"
    } else {
        Add-Check "LLM Inference" "WARNING" "Skipped — no models or Ollama not running"
    }

    # 10. Open-WebUI port
    $owuPort = Test-PortListening -Port 3000
    if ($owuPort) {
        Add-Check "Open-WebUI (running)" "PASS" "Port 3000 is open"
    } else {
        Add-Check "Open-WebUI (running)" "WARNING" "Not running — start with .\Start-OpenWebUI.ps1"
    }

    # 11. Open-WebUI API
    if ($owuPort) {
        $owuApi = Test-HttpEndpoint -Url "http://localhost:3000" -TimeoutSecs 5
        if ($owuApi.Success) {
            Add-Check "Open-WebUI API" "PASS" "Responding at localhost:3000"
        } else {
            Add-Check "Open-WebUI API" "WARNING" "Port open but API not responding yet"
        }
    } else {
        Add-Check "Open-WebUI API" "WARNING" "Skipped — service not running"
    }

    # 12. Docker (optional)
    $dockerVer = Get-CommandVersion -Command "docker"
    if ($dockerVer) {
        Add-Check "Docker (optional)" "PASS" $dockerVer
    } else {
        Add-Check "Docker (optional)" "WARNING" "Not installed (needed for future n8n phase)"
    }

    # --- Summary ---
    $failCount = ($results | Where-Object { $_.Status -eq "FAIL" }).Count
    $warnCount = ($results | Where-Object { $_.Status -eq "WARNING" }).Count
    $passCount = ($results | Where-Object { $_.Status -eq "PASS" }).Count

    Write-Host ""
    Write-Host ("  PASS: {0}   WARNING: {1}   FAIL: {2}" -f $passCount, $warnCount, $failCount) -ForegroundColor $(if ($failCount -gt 0) { "Red" } elseif ($warnCount -gt 0) { "Yellow" } else { "Green" })

    # --- Reports ---
    $reportData = @{
        GeneratedAt = (Get-Date -Format "o")
        Results     = $results
        Summary     = @{ Pass = $passCount; Warning = $warnCount; Fail = $failCount }
    }
    $mdContent = @(
        "# Validation Report",
        "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "",
        (Format-ValidationTable -Results $results),
        "",
        "## Summary",
        "- ✅ PASS: $passCount",
        "- ⚠️ WARNING: $warnCount",
        "- ❌ FAIL: $failCount"
    ) -join "`n"

    if (-not $DryRun) {
        if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
        Save-JsonReport     -Path (Join-Path $OutputPath "validation-report.json") -Data $reportData
        Save-MarkdownReport -Path (Join-Path $OutputPath "validation-report.md")  -Content $mdContent
        Write-Log "Reports saved." -Level SUCCESS
    }

    Write-Log "=== Validation Complete: $passCount PASS, $warnCount WARNING, $failCount FAIL ===" -Level $(if ($failCount -gt 0) { "ERROR" } else { "SUCCESS" })
    exit $(if ($failCount -gt 0) { 1 } else { 0 })
}
catch {
    Write-Log "ERROR: $_" -Level ERROR
    exit 1
}
finally {
    Close-Log
}
