#Requires -Version 5.1
<#
.SYNOPSIS
    Audits the local system hardware and software environment.

.DESCRIPTION
    Collects OS, CPU, RAM, GPU, and disk information. Checks for required tools.
    Recommends a local LLM model tier based on detected hardware.
    Saves machine-readable JSON and human-readable Markdown reports.

.PARAMETER DryRun
    Show what would be collected without saving reports.

.PARAMETER NonInteractive
    Skip all interactive prompts.

.PARAMETER OutputPath
    Directory to write reports. Defaults to ..\reports relative to script location.

.EXAMPLE
    .\00-System-Check.ps1
    .\00-System-Check.ps1 -DryRun -Verbose
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$NonInteractive,
    [string]$OutputPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputPath) { $OutputPath = Join-Path $ProjectRoot "reports" }

Import-Module "$ProjectRoot\modules\Logging.psm1"    -Force
Import-Module "$ProjectRoot\modules\System.psm1"     -Force
Import-Module "$ProjectRoot\modules\Configuration.psm1" -Force

$logFile = Initialize-Log -ScriptName "00-System-Check" -LogDir (Join-Path $ProjectRoot "logs")

try {
    Write-Log "=== System Check Started ===" -Level INFO

    # --- Hardware ---
    Write-Log "Collecting OS information..." -Level INFO
    $os  = Get-OSInfo
    $cpu = Get-CPUInfo
    $mem = Get-MemoryInfo
    $gpu = Get-GPUInfo
    $disk = Get-DiskInfo
    $tier = Get-HardwareTier

    Write-Host "`n=== OPERATING SYSTEM ===" -ForegroundColor Cyan
    Write-Host "  Edition      : $($os.Edition)"
    Write-Host "  Version      : $($os.Version)  (Build $($os.Build))"
    Write-Host "  Architecture : $($os.Architecture)"

    Write-Host "`n=== HARDWARE ===" -ForegroundColor Cyan
    Write-Host "  CPU          : $($cpu.Name)"
    Write-Host "  Cores        : $($cpu.PhysicalCores) physical / $($cpu.LogicalCores) logical"
    Write-Host "  RAM Total    : $($mem.TotalGB) GB"
    Write-Host "  RAM Available: $($mem.AvailableGB) GB"
    foreach ($g in $gpu) {
        Write-Host "  GPU          : $($g.Name)  ($($g.VRAMDisplay))"
    }
    foreach ($d in $disk) {
        Write-Host "  Disk $($d.Drive)      : $($d.FreeGB) GB free / $($d.TotalGB) GB total"
    }

    # --- Software ---
    Write-Host "`n=== INSTALLED TOOLS ===" -ForegroundColor Cyan
    $tools = @(
        @{ Name = "git";        Command = "git" }
        @{ Name = "node";       Command = "node" }
        @{ Name = "npm";        Command = "npm" }
        @{ Name = "python";     Command = "python" }
        @{ Name = "python3";    Command = "python3" }
        @{ Name = "wsl";        Command = "wsl" }
        @{ Name = "docker";     Command = "docker" }
        @{ Name = "ollama";     Command = "ollama" }
    )

    $toolResults = @{}
    foreach ($t in $tools) {
        $ver = Get-CommandVersion -Command $t.Command
        $toolResults[$t.Name] = $ver
        $symbol = if ($ver) { "[OK]" } else { "[--]" }
        $color  = if ($ver) { "Green" } else { "DarkGray" }
        Write-Host ("  {0,-12} {1}  {2}" -f $t.Name, $symbol, ($ver ?? "not found")) -ForegroundColor $color
    }

    # open-webui via pip
    $owuVersion = $null
    try {
        $pipShow = & pip show open-webui 2>&1
        if ($LASTEXITCODE -eq 0) {
            $verLine = $pipShow | Where-Object { $_ -match '^Version:' }
            $owuVersion = ($verLine -replace '^Version:\s*', '').Trim()
        }
    } catch { }
    $toolResults["open-webui"] = $owuVersion
    $symbol = if ($owuVersion) { "[OK]" } else { "[--]" }
    $color  = if ($owuVersion) { "Green" } else { "DarkGray" }
    Write-Host ("  {0,-12} {1}  {2}" -f "open-webui", $symbol, ($owuVersion ?? "not found")) -ForegroundColor $color

    # --- LLM Recommendation ---
    Write-Host "`n=== HARDWARE TIER: $tier ===" -ForegroundColor Yellow
    $modelsConfigPath = Join-Path $ProjectRoot "config\models.psd1"
    if (Test-Path $modelsConfigPath) {
        $modelsCfg = Import-PowerShellDataFile $modelsConfigPath
        $recommended = $modelsCfg[$tier]
        Write-Host "  Recommended models for '$tier' tier:" -ForegroundColor Yellow
        foreach ($m in $recommended) {
            Write-Host ("    - {0,-20} ({1} GB)  {2}" -f $m.OllamaTag, $m.ApproximateSizeGB, $m.Description)
        }
        Write-Host "  Run 05-Configure-Local-LLM.ps1 to download a model." -ForegroundColor DarkCyan
    } else {
        Write-Log "models.psd1 not found at $modelsConfigPath" -Level WARNING
    }

    # --- Reports ---
    $reportData = @{
        GeneratedAt   = (Get-Date -Format "o")
        OS            = $os
        CPU           = $cpu
        Memory        = $mem
        GPU           = $gpu
        Disk          = $disk
        HardwareTier  = $tier
        Tools         = $toolResults
    }

    $mdLines = @(
        "# System Report",
        "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "",
        "## Operating System",
        "| Field | Value |",
        "|-------|-------|",
        "| Edition | $($os.Edition) |",
        "| Version | $($os.Version) (Build $($os.Build)) |",
        "| Architecture | $($os.Architecture) |",
        "",
        "## Hardware",
        "| Component | Details |",
        "|-----------|---------|",
        "| CPU | $($cpu.Name) ($($cpu.PhysicalCores)P / $($cpu.LogicalCores)L cores) |",
        "| RAM | $($mem.TotalGB) GB total / $($mem.AvailableGB) GB available |"
    )
    foreach ($g in $gpu) { $mdLines += "| GPU | $($g.Name) ($($g.VRAMDisplay)) |" }
    foreach ($d in $disk) { $mdLines += "| Disk $($d.Drive) | $($d.FreeGB) GB free / $($d.TotalGB) GB total |" }
    $mdLines += @(
        "",
        "## Hardware Tier: $tier",
        "",
        "## Installed Tools",
        "| Tool | Status | Version |",
        "|------|--------|---------|"
    )
    foreach ($k in $toolResults.Keys) {
        $v = $toolResults[$k]
        $s = if ($v) { "✅ Found" } else { "⬜ Not Found" }
        $mdLines += "| $k | $s | $($v ?? '-') |"
    }

    if (-not $DryRun) {
        if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
        Save-JsonReport -Path (Join-Path $OutputPath "system-report.json") -Data $reportData
        Save-MarkdownReport -Path (Join-Path $OutputPath "system-report.md") -Content ($mdLines -join "`n")
        Write-Log "Reports saved to $OutputPath" -Level SUCCESS
    } else {
        Write-Log "DryRun: reports not saved." -Level WARNING
    }

    Write-Log "=== System Check Complete ===" -Level SUCCESS
    exit 0
}
catch {
    Write-Log "ERROR: $_" -Level ERROR
    exit 1
}
finally {
    Close-Log
}
