#Requires -Version 5.1
Set-StrictMode -Version Latest

function Get-OSInfo {
    <#
    .SYNOPSIS
        Returns operating system details via CIM.
    .OUTPUTS
        [hashtable] Keys: Name, Version, Build, Architecture, Edition
    #>
    [CmdletBinding()]
    param()

    $os = Get-CimInstance Win32_OperatingSystem
    return @{
        Name         = $os.Caption
        Version      = $os.Version
        Build        = $os.BuildNumber
        Architecture = $os.OSArchitecture
        Edition      = $os.OperatingSystemSKU
    }
}

function Get-CPUInfo {
    <#
    .SYNOPSIS
        Returns processor details.
    .OUTPUTS
        [hashtable] Keys: Name, PhysicalCores, LogicalCores
    #>
    [CmdletBinding()]
    param()

    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    return @{
        Name          = $cpu.Name.Trim()
        PhysicalCores = $cpu.NumberOfCores
        LogicalCores  = $cpu.NumberOfLogicalProcessors
    }
}

function Get-MemoryInfo {
    <#
    .SYNOPSIS
        Returns RAM totals (summed across all DIMMs).
    .OUTPUTS
        [hashtable] Keys: TotalGB, AvailableGB, TotalMB, AvailableMB
    #>
    [CmdletBinding()]
    param()

    $os       = Get-CimInstance Win32_OperatingSystem
    $totalMB  = [math]::Round($os.TotalVisibleMemorySize / 1KB, 2)
    $availMB  = [math]::Round($os.FreePhysicalMemory / 1KB, 2)

    return @{
        TotalMB     = $totalMB
        AvailableMB = $availMB
        TotalGB     = [math]::Round($totalMB / 1024, 2)
        AvailableGB = [math]::Round($availMB / 1024, 2)
    }
}

function Get-GPUInfo {
    <#
    .SYNOPSIS
        Returns GPU information. Prefers discrete GPUs over integrated.
    .OUTPUTS
        [array of hashtable] Keys: Name, VRAMBytes, VRAMDisplay
    #>
    [CmdletBinding()]
    param()

    $gpus = Get-CimInstance Win32_VideoController |
        Where-Object { $_.AdapterRAM -gt 0 -or $_.AdapterDACType -ne "Internal" } |
        Sort-Object AdapterRAM -Descending

    if (-not $gpus) {
        $gpus = Get-CimInstance Win32_VideoController
    }

    $result = @()
    foreach ($gpu in $gpus) {
        $vramBytes = [long]$gpu.AdapterRAM
        $vramDisplay = if ($vramBytes -gt 0) {
            "$([math]::Round($vramBytes / 1GB, 1)) GB"
        } else { "Unknown" }

        $result += @{
            Name        = $gpu.Name
            VRAMBytes   = $vramBytes
            VRAMDisplay = $vramDisplay
        }
    }
    return $result
}

function Get-DiskInfo {
    <#
    .SYNOPSIS
        Returns free/total space for all fixed local drives.
    .OUTPUTS
        [array of hashtable] Keys: Drive, TotalGB, FreeGB
    #>
    [CmdletBinding()]
    param()

    $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    $result = @()
    foreach ($d in $disks) {
        $result += @{
            Drive   = $d.DeviceID
            TotalGB = [math]::Round($d.Size / 1GB, 2)
            FreeGB  = [math]::Round($d.FreeSpace / 1GB, 2)
        }
    }
    return $result
}

function Get-HardwareTier {
    <#
    .SYNOPSIS
        Returns a hardware tier classification for LLM model selection.
    .OUTPUTS
        [string] "Low" | "Medium" | "High"
    #>
    [CmdletBinding()]
    param()

    $mem  = Get-MemoryInfo
    $gpus = Get-GPUInfo
    $maxVramGB = ($gpus | ForEach-Object { $_.VRAMBytes / 1GB } | Measure-Object -Maximum).Maximum
    $maxVramGB = if ($maxVramGB) { [math]::Round($maxVramGB, 1) } else { 0 }

    if ($mem.TotalGB -ge 32 -or $maxVramGB -ge 16) { return "High" }
    if ($mem.TotalGB -ge 16 -or $maxVramGB -ge 8)  { return "Medium" }
    return "Low"
}

function Test-CommandExists {
    <#
    .SYNOPSIS
        Returns $true if the named command is available in the current session.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Command)

    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-CommandVersion {
    <#
    .SYNOPSIS
        Runs `<command> --version` and returns the first non-empty output line.
    .OUTPUTS
        [string] Version string, or $null if command not found or fails.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Command)

    if (-not (Test-CommandExists $Command)) { return $null }

    try {
        $output = & $Command --version 2>&1
        return ($output | Where-Object { $_ -match '\S' } | Select-Object -First 1) -as [string]
    } catch {
        return $null
    }
}

Export-ModuleMember -Function Get-OSInfo, Get-CPUInfo, Get-MemoryInfo, Get-GPUInfo,
    Get-DiskInfo, Get-HardwareTier, Test-CommandExists, Get-CommandVersion
