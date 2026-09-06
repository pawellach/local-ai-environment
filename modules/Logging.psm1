#Requires -Version 5.1
Set-StrictMode -Version Latest

$script:LogStartTime = $null

function Initialize-Log {
    <#
    .SYNOPSIS
        Creates a new log file for the current script run and sets $Global:LogFile.
    .PARAMETER ScriptName
        Name of the calling script (used in log header and filename).
    .PARAMETER LogDir
        Directory where log files are stored. Created if it does not exist.
    .OUTPUTS
        [string] Absolute path to the created log file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ScriptName,
        [string]$LogDir = ".\logs"
    )

    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logFile = Join-Path (Resolve-Path $LogDir) "$($ScriptName)_$timestamp.log"

    $script:LogStartTime = Get-Date
    $Global:LogFile = $logFile

    $header = @(
        "=" * 72
        "  Script  : $ScriptName"
        "  Started : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        "  Host    : $env:COMPUTERNAME"
        "  User    : $env:USERNAME"
        "=" * 72
    ) -join "`r`n"

    Set-Content -Path $logFile -Value $header -Encoding UTF8
    return $logFile
}

function Write-Log {
    <#
    .SYNOPSIS
        Writes a message to the console (with color) and to the log file.
        Do NOT pass passwords, API tokens, or secrets as $Message.
    .PARAMETER Message
        The message text. Avoid including secrets.
    .PARAMETER Level
        INFO | WARNING | ERROR | SUCCESS | DEBUG
    .PARAMETER LogFile
        Path to the log file. Defaults to $Global:LogFile.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO",
        [string]$LogFile = $Global:LogFile
    )

    $colors = @{
        INFO    = "Cyan"
        WARNING = "Yellow"
        ERROR   = "Red"
        SUCCESS = "Green"
        DEBUG   = "DarkGray"
    }

    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$ts] [$($Level.PadRight(7))] $Message"

    Write-Host $logLine -ForegroundColor $colors[$Level]

    if ($LogFile -and (Test-Path (Split-Path $LogFile -Parent) -ErrorAction SilentlyContinue)) {
        Add-Content -Path $LogFile -Value $logLine -Encoding UTF8
    }
}

function Close-Log {
    <#
    .SYNOPSIS
        Writes a footer line with elapsed time to the log file.
    .PARAMETER LogFile
        Path to the log file. Defaults to $Global:LogFile.
    #>
    [CmdletBinding()]
    param(
        [string]$LogFile = $Global:LogFile
    )

    $elapsed = if ($script:LogStartTime) {
        $span = (Get-Date) - $script:LogStartTime
        "{0:D2}h {1:D2}m {2:D2}s" -f $span.Hours, $span.Minutes, $span.Seconds
    } else { "unknown" }

    $footer = @(
        "=" * 72
        "  Finished : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        "  Elapsed  : $elapsed"
        "=" * 72
    ) -join "`r`n"

    Write-Host $footer -ForegroundColor DarkGray

    if ($LogFile -and (Test-Path $LogFile -ErrorAction SilentlyContinue)) {
        Add-Content -Path $LogFile -Value $footer -Encoding UTF8
    }
}

Export-ModuleMember -Function Initialize-Log, Write-Log, Close-Log
