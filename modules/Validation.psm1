#Requires -Version 5.1
Set-StrictMode -Version Latest

function Test-PortListening {
    <#
    .SYNOPSIS
        Returns $true if a TCP port is open on the specified host.
    .PARAMETER Port
        TCP port number to test.
    .PARAMETER Host
        Hostname or IP. Defaults to localhost.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$Port,
        [string]$Host = "localhost"
    )

    try {
        $result = Test-NetConnection -ComputerName $Host -Port $Port `
            -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        return [bool]$result
    } catch {
        return $false
    }
}

function Test-HttpEndpoint {
    <#
    .SYNOPSIS
        Sends a GET request to $Url and returns result details.
    .PARAMETER Url
        The HTTP/HTTPS URL to test.
    .PARAMETER TimeoutSecs
        Request timeout in seconds.
    .OUTPUTS
        [hashtable] Keys: Success, StatusCode, Body, Error
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Url,
        [int]$TimeoutSecs = 10
    )

    $result = @{ Success = $false; StatusCode = $null; Body = $null; Error = $null }

    try {
        $response = Invoke-RestMethod -Uri $Url -Method Get `
            -TimeoutSec $TimeoutSecs -ErrorAction Stop
        $result.Success    = $true
        $result.StatusCode = 200
        $result.Body       = $response
    } catch {
        # Compatible with PS 5.1 (System.Net.WebException) and PS 7+ (HttpRequestException / HttpResponseException)
        if ($null -ne $_.Exception.Response) {
            $result.StatusCode = [int]$_.Exception.Response.StatusCode
        }
        $result.Error = $_.Exception.Message
    }

    return $result
}

function New-ValidationResult {
    <#
    .SYNOPSIS
        Creates a standardised validation result hashtable.
    .PARAMETER Component
        Name of the component being validated.
    .PARAMETER Status
        PASS | WARNING | FAIL
    .PARAMETER Message
        Short description of the result.
    .PARAMETER Detail
        Optional additional detail.
    .OUTPUTS
        [hashtable] Keys: Component, Status, Message, Detail, Timestamp
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Component,
        [Parameter(Mandatory)][ValidateSet("PASS","WARNING","FAIL")][string]$Status,
        [Parameter(Mandatory)][string]$Message,
        [string]$Detail = ""
    )

    return @{
        Component = $Component
        Status    = $Status
        Message   = $Message
        Detail    = $Detail
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
}

function Format-ValidationTable {
    <#
    .SYNOPSIS
        Formats an array of validation results as a markdown table string.
    .PARAMETER Results
        Array of hashtables returned by New-ValidationResult.
    .OUTPUTS
        [string] Markdown table.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][array]$Results)

    $icons = @{
        PASS    = "✅ PASS"
        WARNING = "⚠️ WARNING"
        FAIL    = "❌ FAIL"
    }

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("| Component | Status | Message |")
    $null = $sb.AppendLine("|-----------|--------|---------|")

    foreach ($r in $Results) {
        $icon = $icons[$r.Status]
        $null = $sb.AppendLine("| $($r.Component) | $icon | $($r.Message) |")
    }

    $pass    = ($Results | Where-Object { $_.Status -eq "PASS" }).Count
    $warning = ($Results | Where-Object { $_.Status -eq "WARNING" }).Count
    $fail    = ($Results | Where-Object { $_.Status -eq "FAIL" }).Count

    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("**Summary:** ✅ $pass PASS &nbsp;|&nbsp; ⚠️ $warning WARNING &nbsp;|&nbsp; ❌ $fail FAIL")

    return $sb.ToString()
}

Export-ModuleMember -Function Test-PortListening, Test-HttpEndpoint, New-ValidationResult, Format-ValidationTable
