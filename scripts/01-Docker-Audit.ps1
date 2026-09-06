#Requires -Version 5.1
<#
.SYNOPSIS
    Audits the local Docker environment. Makes no changes.

.DESCRIPTION
    Checks whether Docker is installed and running, then collects information
    about containers, images, volumes, networks, and disk usage.
    Saves docker-audit.json and docker-audit.md to the reports directory.

.PARAMETER DryRun
    Collect audit data but skip saving report files.

.PARAMETER NonInteractive
    Skip all interactive prompts.

.PARAMETER OutputPath
    Directory to write reports. Defaults to ..\reports.

.EXAMPLE
    .\01-Docker-Audit.ps1
    .\01-Docker-Audit.ps1 -Verbose
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
Import-Module "$ProjectRoot\modules\Docker.psm1"     -Force
Import-Module "$ProjectRoot\modules\Configuration.psm1" -Force

$logFile = Initialize-Log -ScriptName "01-Docker-Audit" -LogDir (Join-Path $ProjectRoot "logs")

try {
    Write-Log "=== Docker Audit Started ===" -Level INFO

    if (-not (Test-DockerAvailable)) {
        Write-Log "Docker is not installed on this system." -Level WARNING
        Write-Host "`n  Docker is NOT installed." -ForegroundColor Yellow
        Write-Host "  This is expected if Docker has not been set up yet." -ForegroundColor DarkGray
        Write-Host "  Docker is planned for a future phase (n8n deployment)." -ForegroundColor DarkGray

        $noDockerData = @{
            GeneratedAt    = (Get-Date -Format "o")
            DockerInstalled = $false
            Message        = "Docker not installed on this system."
        }
        if (-not $DryRun) {
            if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
            Save-JsonReport -Path (Join-Path $OutputPath "docker-audit.json") -Data $noDockerData
            $md = "# Docker Audit`n`nGenerated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`n**Docker is not installed.**`n`nDocker is planned for a future phase (n8n deployment). No action needed at this time."
            Save-MarkdownReport -Path (Join-Path $OutputPath "docker-audit.md") -Content $md
            Write-Log "Saved no-docker report to $OutputPath" -Level INFO
        }
        Write-Log "=== Docker Audit Complete (Docker not present) ===" -Level SUCCESS
        exit 0
    }

    Write-Log "Docker is installed. Checking daemon status..." -Level INFO

    if (-not (Test-DockerRunning)) {
        Write-Log "Docker daemon is not running." -Level WARNING
        Write-Host "`n  Docker is installed but the daemon is NOT running." -ForegroundColor Yellow
        Write-Host "  Start Docker Desktop or run 'dockerd' to enable full audit." -ForegroundColor DarkGray

        $notRunningData = @{
            GeneratedAt    = (Get-Date -Format "o")
            DockerInstalled = $true
            DockerRunning   = $false
            Message        = "Docker installed but daemon not running."
        }
        if (-not $DryRun) {
            if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
            Save-JsonReport -Path (Join-Path $OutputPath "docker-audit.json") -Data $notRunningData
            $md = "# Docker Audit`n`nGenerated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`n**Docker is installed but not running.**`n`nStart Docker Desktop and re-run this script for a full audit."
            Save-MarkdownReport -Path (Join-Path $OutputPath "docker-audit.md") -Content $md
        }
        Write-Log "=== Docker Audit Complete (daemon not running) ===" -Level WARNING
        exit 2
    }

    Write-Log "Docker daemon is running. Collecting audit data..." -Level INFO
    $audit = Get-DockerAudit

    # Console summary
    Write-Host "`n=== DOCKER AUDIT ===" -ForegroundColor Cyan
    Write-Host "  Docker Version : $($audit.Version)"
    Write-Host "  Containers     : $($audit.Containers.Running) running / $($audit.Containers.Stopped) stopped"
    Write-Host "  Images         : $($audit.Images.Total) total ($($audit.Images.Dangling) dangling)"
    Write-Host "  Volumes        : $($audit.Volumes.Total) total ($($audit.Volumes.Unused) unused)"
    Write-Host "  Networks       : $($audit.Networks)"
    Write-Host "`n  Disk Usage:" -ForegroundColor Yellow
    if ($audit.DiskUsage) {
        Write-Host "    $($audit.DiskUsage | Out-String)"
    }

    if (-not $DryRun) {
        if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
        $auditData = $audit + @{ GeneratedAt = (Get-Date -Format "o"); DockerInstalled = $true; DockerRunning = $true }
        Save-JsonReport -Path (Join-Path $OutputPath "docker-audit.json") -Data $auditData
        $md = Format-DockerAuditMarkdown -Audit $audit
        Save-MarkdownReport -Path (Join-Path $OutputPath "docker-audit.md") -Content $md
        Write-Log "Reports saved to $OutputPath" -Level SUCCESS
    } else {
        Write-Log "DryRun: reports not saved." -Level WARNING
    }

    Write-Log "=== Docker Audit Complete ===" -Level SUCCESS
    exit 0
}
catch {
    Write-Log "ERROR: $_" -Level ERROR
    exit 1
}
finally {
    Close-Log
}
