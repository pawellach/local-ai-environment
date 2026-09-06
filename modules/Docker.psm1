#Requires -Version 5.1
Set-StrictMode -Version Latest

function Test-DockerAvailable {
    <#
    .SYNOPSIS
        Returns $true if the docker CLI is present on PATH.
    #>
    [CmdletBinding()]
    param()
    return [bool](Get-Command docker -ErrorAction SilentlyContinue)
}

function Test-DockerRunning {
    <#
    .SYNOPSIS
        Returns $true if the Docker daemon is responsive (docker ps succeeds).
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-DockerAvailable)) { return $false }
    try {
        $null = docker ps 2>&1
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Get-DockerAudit {
    <#
    .SYNOPSIS
        Collects a full snapshot of the local Docker environment.
    .OUTPUTS
        [hashtable] Keys: Available, Running, Version, Containers, Images, Volumes, Networks, BuildCache, DiskUsage, Error
    #>
    [CmdletBinding()]
    param()

    $audit = @{
        Available  = Test-DockerAvailable
        Running    = $false
        Version    = $null
        Containers = @{ Running = 0; Stopped = 0; All = @() }
        Images     = @{ Total = 0; Dangling = 0; All = @() }
        Volumes    = @{ Total = 0; Unused = 0; All = @() }
        Networks   = @{ Total = 0; All = @() }
        BuildCache = @{ Size = "0B"; Count = 0 }
        DiskUsage  = @{ Raw = $null }
        Error      = $null
    }

    if (-not $audit.Available) { return $audit }

    try {
        $audit.Running = Test-DockerRunning
        if (-not $audit.Running) { return $audit }

        # Version
        $versionRaw = docker version --format '{{json .}}' 2>&1
        if ($LASTEXITCODE -eq 0) {
            $v = $versionRaw | ConvertFrom-Json -ErrorAction SilentlyContinue
            $audit.Version = @{
                Client = $v.Client.Version
                Server = $v.Server.Components[0].Version
            }
        }

        # Containers
        $containersRaw = docker ps -a --format '{{json .}}' 2>&1
        if ($LASTEXITCODE -eq 0 -and $containersRaw) {
            $containers = $containersRaw | ForEach-Object {
                $_ | ConvertFrom-Json -ErrorAction SilentlyContinue
            } | Where-Object { $_ }
            $audit.Containers.All     = $containers
            $audit.Containers.Running = ($containers | Where-Object { $_.State -eq "running" }).Count
            $audit.Containers.Stopped = ($containers | Where-Object { $_.State -ne "running" }).Count
        }

        # Images
        $imagesRaw = docker images --format '{{json .}}' 2>&1
        if ($LASTEXITCODE -eq 0 -and $imagesRaw) {
            $images = $imagesRaw | ForEach-Object {
                $_ | ConvertFrom-Json -ErrorAction SilentlyContinue
            } | Where-Object { $_ }
            $audit.Images.All      = $images
            $audit.Images.Total    = $images.Count
            $audit.Images.Dangling = ($images | Where-Object { $_.Repository -eq "<none>" }).Count
        }

        # Volumes
        $volumesRaw = docker volume ls --format '{{json .}}' 2>&1
        if ($LASTEXITCODE -eq 0 -and $volumesRaw) {
            $volumes = $volumesRaw | ForEach-Object {
                $_ | ConvertFrom-Json -ErrorAction SilentlyContinue
            } | Where-Object { $_ }
            $audit.Volumes.All   = $volumes
            $audit.Volumes.Total = $volumes.Count

            # Identify unused volumes
            $unusedRaw = docker volume ls -f dangling=true --format '{{json .}}' 2>&1
            if ($LASTEXITCODE -eq 0 -and $unusedRaw) {
                $unused = $unusedRaw | ForEach-Object {
                    $_ | ConvertFrom-Json -ErrorAction SilentlyContinue
                } | Where-Object { $_ }
                $audit.Volumes.Unused = $unused.Count
            }
        }

        # Networks
        $networksRaw = docker network ls --format '{{json .}}' 2>&1
        if ($LASTEXITCODE -eq 0 -and $networksRaw) {
            $networks = $networksRaw | ForEach-Object {
                $_ | ConvertFrom-Json -ErrorAction SilentlyContinue
            } | Where-Object { $_ }
            $audit.Networks.All   = $networks
            $audit.Networks.Total = $networks.Count
        }

        # Disk usage
        $dfRaw = docker system df --format '{{json .}}' 2>&1
        if ($LASTEXITCODE -eq 0 -and $dfRaw) {
            $audit.DiskUsage.Raw = $dfRaw | ForEach-Object {
                $_ | ConvertFrom-Json -ErrorAction SilentlyContinue
            } | Where-Object { $_ }
        }

    } catch {
        $audit.Error = $_.Exception.Message
    }

    return $audit
}

function Format-DockerAuditMarkdown {
    <#
    .SYNOPSIS
        Converts a Docker audit hashtable into a human-readable markdown report string.
    .PARAMETER Audit
        Hashtable returned by Get-DockerAudit.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Audit)

    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $sb = [System.Text.StringBuilder]::new()

    $null = $sb.AppendLine("# Docker Audit Report")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("**Generated:** $ts")
    $null = $sb.AppendLine("")

    if (-not $Audit.Available) {
        $null = $sb.AppendLine("## Status: Docker Not Installed")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("Docker CLI was not found on PATH. No audit data available.")
        return $sb.ToString()
    }

    if (-not $Audit.Running) {
        $null = $sb.AppendLine("## Status: Docker Installed but Not Running")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("Docker CLI is present but the daemon did not respond to `docker ps`.")
        $null = $sb.AppendLine("Start Docker Desktop and re-run this script.")
        return $sb.ToString()
    }

    # Version
    $null = $sb.AppendLine("## Docker Version")
    $null = $sb.AppendLine("")
    if ($Audit.Version) {
        $null = $sb.AppendLine("| Component | Version |")
        $null = $sb.AppendLine("|-----------|---------|")
        $null = $sb.AppendLine("| Client    | $($Audit.Version.Client) |")
        $null = $sb.AppendLine("| Server    | $($Audit.Version.Server) |")
    } else {
        $null = $sb.AppendLine("_Version information unavailable._")
    }
    $null = $sb.AppendLine("")

    # Containers
    $null = $sb.AppendLine("## Containers")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| State   | Count |")
    $null = $sb.AppendLine("|---------|-------|")
    $null = $sb.AppendLine("| Running | $($Audit.Containers.Running) |")
    $null = $sb.AppendLine("| Stopped | $($Audit.Containers.Stopped) |")
    $null = $sb.AppendLine("| **Total**   | **$($Audit.Containers.Running + $Audit.Containers.Stopped)** |")
    $null = $sb.AppendLine("")

    # Images
    $null = $sb.AppendLine("## Images")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Type     | Count |")
    $null = $sb.AppendLine("|----------|-------|")
    $null = $sb.AppendLine("| Total    | $($Audit.Images.Total) |")
    $null = $sb.AppendLine("| Dangling | $($Audit.Images.Dangling) |")
    $null = $sb.AppendLine("")

    # Volumes
    $null = $sb.AppendLine("## Volumes")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Type   | Count |")
    $null = $sb.AppendLine("|--------|-------|")
    $null = $sb.AppendLine("| Total  | $($Audit.Volumes.Total) |")
    $null = $sb.AppendLine("| Unused | $($Audit.Volumes.Unused) |")
    $null = $sb.AppendLine("")

    # Networks
    $null = $sb.AppendLine("## Networks")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("Total networks: $($Audit.Networks.Total)")
    $null = $sb.AppendLine("")

    if ($Audit.Error) {
        $null = $sb.AppendLine("## Errors")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("``$($Audit.Error)``")
    }

    return $sb.ToString()
}

Export-ModuleMember -Function Test-DockerAvailable, Test-DockerRunning, Get-DockerAudit, Format-DockerAuditMarkdown
