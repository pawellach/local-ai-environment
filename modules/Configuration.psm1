#Requires -Version 5.1
Set-StrictMode -Version Latest

function Get-ProjectConfig {
    <#
    .SYNOPSIS
        Loads and returns the project environment configuration from a .psd1 file.
    .PARAMETER ConfigPath
        Path to environment.psd1. Defaults to .\config\environment.psd1.
    .OUTPUTS
        [hashtable] Configuration values.
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath = ".\config\environment.psd1"
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    return Import-PowerShellDataFile -Path $ConfigPath
}

function Save-JsonReport {
    <#
    .SYNOPSIS
        Serialises $Data to JSON and writes it to $Path, creating parent directories as needed.
    .PARAMETER Path
        Destination file path.
    .PARAMETER Data
        Object to serialise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Data
    )

    $parent = Split-Path $Path -Parent
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
}

function Save-MarkdownReport {
    <#
    .SYNOPSIS
        Writes a markdown string to $Path, creating parent directories as needed.
    .PARAMETER Path
        Destination file path.
    .PARAMETER Content
        Markdown string content.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $parent = Split-Path $Path -Parent
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Set-Content -Path $Path -Value $Content -Encoding UTF8
}

function Confirm-DestructiveOperation {
    <#
    .SYNOPSIS
        Prints a warning and requires the user to type an exact confirmation phrase.
        Returns $true only if the user types the phrase correctly.
    .PARAMETER ConfirmPhrase
        The exact string the user must type to proceed.
    .PARAMETER Prompt
        Descriptive message explaining what will be destroyed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ConfirmPhrase,
        [Parameter(Mandatory)][string]$Prompt
    )

    Write-Host ""
    Write-Host ("=" * 72) -ForegroundColor Red
    Write-Host "  DESTRUCTIVE OPERATION WARNING" -ForegroundColor Red
    Write-Host ("=" * 72) -ForegroundColor Red
    Write-Host ""
    Write-Host $Prompt -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To confirm, type exactly: " -NoNewline -ForegroundColor Yellow
    Write-Host $ConfirmPhrase -ForegroundColor Cyan
    Write-Host ""

    $input = Read-Host "Type confirmation phrase"
    $confirmed = ($input -ceq $ConfirmPhrase)

    if (-not $confirmed) {
        Write-Host "Confirmation phrase did not match. Operation cancelled." -ForegroundColor Green
    }

    return $confirmed
}

function Get-UserConfirmation {
    <#
    .SYNOPSIS
        Prompts the user with a Y/N question. Returns $true for Y, $false otherwise (default N).
    .PARAMETER Prompt
        The question to display.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Prompt)

    $answer = Read-Host "$Prompt [y/N]"
    return ($answer -match '^[Yy]$')
}

Export-ModuleMember -Function Get-ProjectConfig, Save-JsonReport, Save-MarkdownReport,
    Confirm-DestructiveOperation, Get-UserConfirmation
