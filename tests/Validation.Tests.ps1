#Requires -Modules Pester
<#
.SYNOPSIS
    Pester tests for modules/Validation.psm1
#>

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Import-Module "$ProjectRoot\modules\Validation.psm1" -Force

Describe "New-ValidationResult" {
    It "returns a hashtable with required keys" {
        $r = New-ValidationResult -Component "Git" -Status "PASS" -Message "v2.45.0"
        $r | Should -BeOfType [hashtable]
        $r.Component | Should -Be "Git"
        $r.Status    | Should -Be "PASS"
        $r.Message   | Should -Be "v2.45.0"
        $r.Detail    | Should -Be ""
        $r.Timestamp | Should -Not -BeNullOrEmpty
    }

    It "accepts optional Detail parameter" {
        $r = New-ValidationResult -Component "Ollama" -Status "FAIL" -Message "Not found" -Detail "Run 04-Install-Ollama.ps1"
        $r.Detail | Should -Be "Run 04-Install-Ollama.ps1"
    }

    It "rejects invalid Status values" {
        { New-ValidationResult -Component "X" -Status "UNKNOWN" -Message "x" } | Should -Throw
    }

    It "accepts all valid Status values" {
        foreach ($s in @("PASS","WARNING","FAIL")) {
            { New-ValidationResult -Component "X" -Status $s -Message "x" } | Should -Not -Throw
        }
    }
}

Describe "Format-ValidationTable" {
    BeforeAll {
        $results = @(
            (New-ValidationResult -Component "Git"    -Status "PASS"    -Message "v2.45.0"),
            (New-ValidationResult -Component "Python" -Status "WARNING" -Message "3.10 (need 3.11+)"),
            (New-ValidationResult -Component "Ollama" -Status "FAIL"    -Message "Not installed")
        )
        $table = Format-ValidationTable -Results $results
    }

    It "returns a non-empty string" {
        $table | Should -Not -BeNullOrEmpty
    }

    It "contains markdown table header" {
        $table | Should -BeLike "*| Component | Status | Message |*"
    }

    It "includes all component names" {
        $table | Should -BeLike "*Git*"
        $table | Should -BeLike "*Python*"
        $table | Should -BeLike "*Ollama*"
    }

    It "includes summary line with correct counts" {
        $table | Should -BeLike "*1 PASS*"
        $table | Should -BeLike "*1 WARNING*"
        $table | Should -BeLike "*1 FAIL*"
    }
}

Describe "Test-HttpEndpoint" {
    It "returns hashtable with Success=false for unreachable host" {
        $result = Test-HttpEndpoint -Url "http://localhost:19999" -TimeoutSecs 2
        $result | Should -BeOfType [hashtable]
        $result.Success | Should -Be $false
    }

    It "result has expected keys" {
        $result = Test-HttpEndpoint -Url "http://localhost:19999" -TimeoutSecs 2
        $result.ContainsKey("Success")    | Should -Be $true
        $result.ContainsKey("StatusCode") | Should -Be $true
        $result.ContainsKey("Error")      | Should -Be $true
    }
}
