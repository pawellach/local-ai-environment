#Requires -Version 5.1
<#
.SYNOPSIS
    Cleans the Docker environment with explicit user confirmation for destructive operations.

.DESCRIPTION
    Supports three modes:
      AUDIT - No changes. Reports current state.
      SAFE  - Removes only clearly unused resources (stopped containers, dangling images, unused anonymous volumes).
      FULL  - Full clean for fresh n8n deployment. Requires explicit typed confirmation phrase.

    All destructive operations are preceded by a discovery phase and user confirmation.
    Before FULL mode, a before-state report is saved automatically.

.PARAMETER Mode
    Cleaning mode: AUDIT, SAFE, or FULL. Required.

.PARAMETER DryRun
    Show what WOULD be removed without actually removing anything.

.PARAMETER NonInteractive
    Skip interactive prompts (only safe for AUDIT or scripted SAFE mode).

.EXAMPLE
    .\02-Docker-Clean.ps1 -Mode AUDIT
    .\02-Docker-Clean.ps1 -Mode SAFE -DryRun
    .\02-Docker-Clean.ps1 -Mode FULL
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("AUDIT","SAFE","FULL")]
    [string]$Mode,
    [switch]$DryRun,
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$OutputPath  = Join-Path $ProjectRoot "reports"

Import-Module "$ProjectRoot\modules\Logging.psm1"    -Force
Import-Module "$ProjectRoot\modules\Docker.psm1"     -Force
Import-Module "$ProjectRoot\modules\Configuration.psm1" -Force

$logFile = Initialize-Log -ScriptName "02-Docker-Clean-$Mode" -LogDir (Join-Path $ProjectRoot "logs")

function Invoke-DockerCommand {
    param([string]$Command, [bool]$IsDryRun)
    if ($IsDryRun) {
        Write-Log "  [DryRun] Would execute: docker $Command" -Level DEBUG
        return "[DryRun - not executed]"
    }
    Write-Log "  Executing: docker $Command" -Level INFO
    $result = Invoke-Expression "docker $Command 2>&1"
    return $result
}

try {
    Write-Log "=== Docker Clean ($Mode mode) Started ===" -Level INFO

    if (-not (Test-DockerAvailable)) {
        Write-Log "Docker is not installed. Nothing to clean." -Level WARNING
        Write-Host "`n  Docker is not installed. Nothing to clean." -ForegroundColor Yellow
        exit 0
    }

    if (-not (Test-DockerRunning)) {
        Write-Log "Docker daemon is not running. Start Docker Desktop first." -Level ERROR
        Write-Host "`n  Docker daemon is not running. Start Docker Desktop and retry." -ForegroundColor Red
        exit 1
    }

    $audit = Get-DockerAudit

    if ($Mode -eq "AUDIT") {
        Write-Host "`n=== DOCKER AUDIT (no changes) ===" -ForegroundColor Cyan
        Write-Host ($audit | ConvertTo-Json -Depth 5)
        Write-Log "AUDIT mode complete. No changes made." -Level SUCCESS
        exit 0
    }

    # --- SAFE / FULL ---

    if ($Mode -eq "FULL") {
        Write-Host "`n" -NoNewline
        Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
        Write-Host "!!!    DOCKER FULL CLEAN REQUESTED     !!!" -ForegroundColor Red
        Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
        Write-Host "`n  This will remove:" -ForegroundColor Yellow
        Write-Host "    - ALL stopped containers ($($audit.Containers.Stopped))"
        Write-Host "    - ALL unused images ($($audit.Images.Total) total, $($audit.Images.Dangling) dangling)"
        Write-Host "    - ALL unused volumes ($($audit.Volumes.Unused) unused)"
        Write-Host "    - ALL unused networks"
        Write-Host "    - ALL build cache"
        Write-Host "`n  Disk space to recover (estimate):"
        Write-Host "    $($audit.DiskUsage | Out-String)" -ForegroundColor Yellow

        if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
        $beforeData = $audit + @{ GeneratedAt = (Get-Date -Format "o"); Mode = "BEFORE_FULL_CLEAN" }
        Save-JsonReport -Path (Join-Path $OutputPath "docker-before-clean.json") -Data $beforeData
        Write-Log "Before-clean snapshot saved." -Level INFO

        if (-not $DryRun) {
            if ($NonInteractive) {
                Write-Log "NonInteractive mode with FULL clean: refusing to proceed without confirmation." -Level ERROR
                Write-Host "`n  FULL mode cannot run in -NonInteractive mode. Exiting." -ForegroundColor Red
                exit 1
            }
            $confirmed = Confirm-DestructiveOperation -ConfirmPhrase "I CONFIRM DOCKER FULL CLEAN" `
                -Prompt "`n  Type exactly: I CONFIRM DOCKER FULL CLEAN"
            if (-not $confirmed) {
                Write-Log "User did not confirm FULL clean. Aborting." -Level WARNING
                Write-Host "`n  Aborted." -ForegroundColor Yellow
                exit 0
            }
        } else {
            Write-Log "DryRun: FULL clean steps shown but nothing executed." -Level WARNING
        }
    } else {
        # SAFE mode confirmation
        Write-Host "`n=== SAFE CLEAN ===" -ForegroundColor Cyan
        Write-Host "  Will remove:"
        Write-Host "    - Stopped containers ($($audit.Containers.Stopped))"
        Write-Host "    - Dangling images ($($audit.Images.Dangling))"
        Write-Host "    - Unused anonymous volumes"
        Write-Host "    - Build cache older than 24h"
        if (-not $NonInteractive -and -not $DryRun) {
            $ok = Get-UserConfirmation -Prompt "`n  Proceed with SAFE clean? [Y/N]"
            if (-not $ok) {
                Write-Log "User cancelled SAFE clean." -Level INFO
                Write-Host "`n  Cancelled." -ForegroundColor Yellow
                exit 0
            }
        }
    }

    # --- Execute Cleaning ---
    $cleanLog = @()

    Write-Host "`n  Cleaning..." -ForegroundColor Cyan

    if ($Mode -in @("SAFE","FULL")) {
        $r = Invoke-DockerCommand "container prune --force" $DryRun.IsPresent
        $cleanLog += "Container prune: $r"
        Write-Log "Container prune done." -Level INFO

        if ($Mode -eq "SAFE") {
            $r = Invoke-DockerCommand "image prune --force" $DryRun.IsPresent
        } else {
            $r = Invoke-DockerCommand "image prune --all --force" $DryRun.IsPresent
        }
        $cleanLog += "Image prune: $r"
        Write-Log "Image prune done." -Level INFO

        if ($Mode -eq "SAFE") {
            $r = Invoke-DockerCommand "volume prune --force --filter 'label!=keep'" $DryRun.IsPresent
        } else {
            $r = Invoke-DockerCommand "volume prune --all --force" $DryRun.IsPresent
        }
        $cleanLog += "Volume prune: $r"
        Write-Log "Volume prune done." -Level INFO

        if ($Mode -eq "FULL") {
            $r = Invoke-DockerCommand "network prune --force" $DryRun.IsPresent
            $cleanLog += "Network prune: $r"
            Write-Log "Network prune done." -Level INFO
        }

        $cacheFilter = if ($Mode -eq "SAFE") { "--filter until=24h" } else { "" }
        $r = Invoke-DockerCommand "builder prune --force $cacheFilter" $DryRun.IsPresent
        $cleanLog += "Builder prune: $r"
        Write-Log "Builder cache prune done." -Level INFO
    }

    Write-Host "`n  Clean complete." -ForegroundColor Green

    if (-not $DryRun) {
        $afterAudit = Get-DockerAudit
        $afterData  = $afterAudit + @{ GeneratedAt = (Get-Date -Format "o"); Mode = "AFTER_${Mode}_CLEAN" }
        if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
        Save-JsonReport -Path (Join-Path $OutputPath "docker-after-clean.json") -Data $afterData

        $summaryMd = @(
            "# Docker Clean Summary",
            "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
            "Mode: **$Mode**",
            "",
            "## Operations Performed",
            ($cleanLog -join "`n"),
            "",
            "## Post-Clean State",
            "- Containers: $($afterAudit.Containers.Running) running / $($afterAudit.Containers.Stopped) stopped",
            "- Images: $($afterAudit.Images.Total) total",
            "- Volumes: $($afterAudit.Volumes.Total) total"
        ) -join "`n"
        Save-MarkdownReport -Path (Join-Path $OutputPath "docker-clean-summary.md") -Content $summaryMd
        Write-Log "Post-clean reports saved." -Level SUCCESS
    }

    Write-Log "=== Docker Clean Complete ===" -Level SUCCESS
    exit 0
}
catch {
    Write-Log "ERROR: $_" -Level ERROR
    exit 1
}
finally {
    Close-Log
}
