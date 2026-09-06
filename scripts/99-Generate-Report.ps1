#Requires -Version 5.1
<#
.SYNOPSIS
    Generates a comprehensive final environment report.

.DESCRIPTION
    Reads all previously generated reports from the reports/ directory and compiles
    them into a single FINAL-ENVIRONMENT-REPORT.md with all components, versions,
    ports, validation results, and recommended next steps.

.PARAMETER DryRun
    Generate and display report without saving to file.

.PARAMETER OutputPath
    Directory to read reports from and write final report to. Defaults to ..\reports.

.EXAMPLE
    .\99-Generate-Report.ps1
    .\99-Generate-Report.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$OutputPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputPath) { $OutputPath = Join-Path $ProjectRoot "reports" }

Import-Module "$ProjectRoot\modules\Logging.psm1"       -Force
Import-Module "$ProjectRoot\modules\Configuration.psm1" -Force

$logFile = Initialize-Log -ScriptName "99-Generate-Report" -LogDir (Join-Path $ProjectRoot "logs")

function Read-JsonReport {
    param([string]$FileName)
    $path = Join-Path $OutputPath $FileName
    if (Test-Path $path) {
        try { return Get-Content $path -Raw | ConvertFrom-Json }
        catch { return $null }
    }
    return $null
}

function Get-StatusBadge { param([bool]$ok) if ($ok) { "✅" } else { "❌" } }

try {
    Write-Log "=== Generating Final Report ===" -Level INFO

    $genDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $sys      = Read-JsonReport "system-report.json"
    $docker   = Read-JsonReport "docker-audit.json"
    $owuInst  = Read-JsonReport "openwebui-install-report.json"
    $ollama   = Read-JsonReport "ollama-install-report.json"
    $llmCfg   = Read-JsonReport "llm-config-report.json"
    $llmTest  = Read-JsonReport "llm-test-result.json"
    $owuCfg   = Read-JsonReport "openwebui-config-report.json"
    $val      = Read-JsonReport "validation-report.json"

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# Local AI Environment — Final Report")
    $lines.Add("Generated: $genDate")
    $lines.Add("")
    $lines.Add("---")

    # 1. System Information
    $lines.Add("## 1. System Information")
    if ($sys) {
        $lines.Add("| Field | Value |")
        $lines.Add("|-------|-------|")
        $lines.Add("| OS | $($sys.OS.Edition) $($sys.OS.Version) (Build $($sys.OS.Build)) |")
        $lines.Add("| Architecture | $($sys.OS.Architecture) |")
        $lines.Add("| CPU | $($sys.CPU.Name) ($($sys.CPU.PhysicalCores)P/$($sys.CPU.LogicalCores)L cores) |")
        $lines.Add("| RAM | $($sys.Memory.TotalGB) GB total / $($sys.Memory.AvailableGB) GB available |")
        if ($sys.GPU) {
            foreach ($g in $sys.GPU) {
                $lines.Add("| GPU | $($g.Name) ($($g.VRAMDisplay)) |")
            }
        }
        if ($sys.Disk) {
            foreach ($d in $sys.Disk) {
                $lines.Add("| Disk $($d.Drive) | $($d.FreeGB) GB free / $($d.TotalGB) GB total |")
            }
        }
        $lines.Add("| Hardware Tier | $($sys.HardwareTier) |")
    } else {
        $lines.Add("_Not generated. Run 00-System-Check.ps1_")
    }
    $lines.Add("")

    # 2. Installed Components
    $lines.Add("## 2. Installed Components and Versions")
    $lines.Add("| Component | Version | Status |")
    $lines.Add("|-----------|---------|--------|")
    if ($sys -and $sys.Tools) {
        foreach ($key in $sys.Tools.PSObject.Properties.Name) {
            $ver = $sys.Tools.$key
            $lines.Add("| $key | $($ver ?? '-') | $(Get-StatusBadge ($null -ne $ver)) |")
        }
    }
    if ($ollama) {
        $lines.Add("| Ollama | $($ollama.OllamaVersion) | $(Get-StatusBadge ($null -ne $ollama.OllamaVersion)) |")
    }
    if ($owuInst) {
        $lines.Add("| Open-WebUI | $($owuInst.OpenWebUIVersion) | $(Get-StatusBadge ($null -ne $owuInst.OpenWebUIVersion)) |")
    }
    $lines.Add("")

    # 3. Docker State
    $lines.Add("## 3. Docker State")
    if ($docker) {
        if ($docker.DockerInstalled -eq $false) {
            $lines.Add("Docker is **not installed**. Planned for Phase 2 (n8n).")
        } elseif ($docker.DockerRunning -eq $false) {
            $lines.Add("Docker is installed but **not running**.")
        } else {
            $lines.Add("| Field | Value |")
            $lines.Add("|-------|-------|")
            $lines.Add("| Version | $($docker.Version) |")
            $lines.Add("| Containers | $($docker.Containers.Running) running / $($docker.Containers.Stopped) stopped |")
            $lines.Add("| Images | $($docker.Images.Total) total ($($docker.Images.Dangling) dangling) |")
            $lines.Add("| Volumes | $($docker.Volumes.Total) total ($($docker.Volumes.Unused) unused) |")
        }
    } else {
        $lines.Add("_Not generated. Run 01-Docker-Audit.ps1_")
    }
    $lines.Add("")

    # 4. Open-WebUI State
    $lines.Add("## 4. Open-WebUI State")
    if ($owuCfg) {
        $lines.Add("| Field | Value |")
        $lines.Add("|-------|-------|")
        $lines.Add("| Port | $($owuCfg.OpenWebUIPort) |")
        $lines.Add("| Running | $(Get-StatusBadge $owuCfg.OpenWebUIRunning) |")
        $lines.Add("| OLLAMA_BASE_URL | $($owuCfg.OllamaUrl) |")
        $lines.Add("| Browser URL | http://localhost:$($owuCfg.OpenWebUIPort) |")
    } elseif ($owuInst) {
        $lines.Add("Installed (v$($owuInst.OpenWebUIVersion)) but not configured. Run 06-Configure-OpenWebUI.ps1")
    } else {
        $lines.Add("_Not installed. Run 03-Install-OpenWebUI.ps1_")
    }
    $lines.Add("")

    # 5. Ollama State
    $lines.Add("## 5. Ollama State")
    if ($ollama) {
        $lines.Add("| Field | Value |")
        $lines.Add("|-------|-------|")
        $lines.Add("| Version | $($ollama.OllamaVersion) |")
        $lines.Add("| API URL | $($ollama.APIUrl) |")
        $lines.Add("| API Running | $(Get-StatusBadge $ollama.APIRunning) |")
    } else {
        $lines.Add("_Not generated. Run 04-Install-Ollama.ps1_")
    }
    $lines.Add("")

    # 6. Installed Models
    $lines.Add("## 6. Installed Models")
    if ($llmCfg) {
        $lines.Add("| Field | Value |")
        $lines.Add("|-------|-------|")
        $lines.Add("| Selected Model | $($llmCfg.SelectedModel) |")
        $lines.Add("| Hardware Tier | $($llmCfg.HardwareTier) |")
        if ($llmTest) {
            $lines.Add("| Inference Test | $(if ($llmTest.Passed) { '✅ PASSED' } else { '⚠️ Unexpected output' }) in $($llmTest.ElapsedMs)ms |")
        }
    } else {
        $lines.Add("_No model configured. Run 05-Configure-Local-LLM.ps1_")
    }
    $lines.Add("")

    # 7. Network Ports
    $lines.Add("## 7. Network Ports")
    $lines.Add("| Port | Service | Notes |")
    $lines.Add("|------|---------|-------|")
    $lines.Add("| 11434 | Ollama API | localhost only (default) |")
    $lines.Add("| 3000 | Open-WebUI | localhost only |")
    $lines.Add("| 5678 | n8n (future) | planned for Phase 2 |")
    $lines.Add("")

    # 8. Validation Results
    $lines.Add("## 8. Validation Results")
    if ($val -and $val.Results) {
        $lines.Add("| Component | Status | Message |")
        $lines.Add("|-----------|--------|---------|")
        foreach ($r in $val.Results) {
            $icon = switch ($r.Status) { "PASS" { "✅" } "WARNING" { "⚠️" } "FAIL" { "❌" } default { "?" } }
            $lines.Add("| $($r.Component) | $icon $($r.Status) | $($r.Message) |")
        }
        $lines.Add("")
        $lines.Add("**Summary:** PASS: $($val.Summary.Pass) / WARNING: $($val.Summary.Warning) / FAIL: $($val.Summary.Fail)")
    } else {
        $lines.Add("_Not generated. Run 07-Validate-Environment.ps1_")
    }
    $lines.Add("")

    # 9. Configuration Locations
    $lines.Add("## 9. Configuration Locations")
    $lines.Add("| File | Purpose |")
    $lines.Add("|------|---------|")
    $lines.Add("| config/environment.psd1 | Ports, URLs, paths |")
    $lines.Add("| config/models.psd1 | LLM model recommendations |")
    $lines.Add("| Start-OpenWebUI.ps1 | Open-WebUI launcher |")
    $lines.Add("| OLLAMA_BASE_URL (User env) | Ollama connection for Open-WebUI |")
    $lines.Add("")

    # 10. Log Locations
    $lines.Add("## 10. Log Locations")
    $lines.Add("All script logs are saved to the ``logs/`` directory.")
    $logFiles = Get-ChildItem (Join-Path $ProjectRoot "logs") -Filter "*.log" -ErrorAction SilentlyContinue
    if ($logFiles) {
        foreach ($lf in $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 10) {
            $lines.Add("- logs/$($lf.Name)")
        }
    }
    $lines.Add("")

    # 11. Known Issues
    $lines.Add("## 11. Known Issues")
    if ($val -and $val.Results) {
        $fails = $val.Results | Where-Object { $_.Status -eq "FAIL" }
        if ($fails) {
            foreach ($f in $fails) {
                $lines.Add("- ❌ **$($f.Component)**: $($f.Message)")
            }
        } else {
            $lines.Add("No FAIL items detected.")
        }
    } else {
        $lines.Add("_Run 07-Validate-Environment.ps1 to detect issues._")
    }
    $lines.Add("")

    # 12. Next Steps
    $lines.Add("## 12. Recommended Next Steps")
    $lines.Add("1. Start Ollama from the system tray (or run ``ollama serve``)")
    $lines.Add("2. Start Open-WebUI: ``.\Start-OpenWebUI.ps1``")
    $lines.Add("3. Open browser: http://localhost:3000")
    $lines.Add("4. Create your admin account in Open-WebUI on first launch")
    $lines.Add("5. (Optional) Run 07-Validate-Environment.ps1 to re-validate")
    $lines.Add("6. (Future) Run 01-Docker-Audit.ps1 to prepare for n8n deployment")
    $lines.Add("")
    $lines.Add("---")
    $lines.Add("_Report generated by Local-AI-Environment v1.0.0_")

    $finalReport = $lines -join "`n"

    # Console summary
    Write-Host "`n=== FINAL REPORT SUMMARY ===" -ForegroundColor Cyan
    Write-Host "  OS       : $($sys.OS.Edition ?? 'unknown') $($sys.OS.Version ?? '')"
    Write-Host "  Ollama   : $($ollama.OllamaVersion ?? 'not installed')"
    Write-Host "  WebUI    : $($owuInst.OpenWebUIVersion ?? 'not installed')"
    Write-Host "  Model    : $($llmCfg.SelectedModel ?? 'none')"
    if ($val -and $val.Summary) {
        Write-Host "  Tests    : PASS=$($val.Summary.Pass) WARNING=$($val.Summary.Warning) FAIL=$($val.Summary.Fail)"
    }

    if (-not $DryRun) {
        if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
        Save-MarkdownReport -Path (Join-Path $OutputPath "FINAL-ENVIRONMENT-REPORT.md") -Content $finalReport
        Write-Log "Final report saved: $OutputPath\FINAL-ENVIRONMENT-REPORT.md" -Level SUCCESS
        Write-Host "`n  Report saved: $OutputPath\FINAL-ENVIRONMENT-REPORT.md" -ForegroundColor Green
    } else {
        Write-Host "`n  [DryRun] Report not saved." -ForegroundColor DarkGray
        Write-Host $finalReport
    }

    Write-Log "=== Final Report Generation Complete ===" -Level SUCCESS
    exit 0
}
catch {
    Write-Log "ERROR: $_" -Level ERROR
    exit 1
}
finally {
    Close-Log
}
