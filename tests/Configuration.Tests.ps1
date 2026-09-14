#Requires -Modules Pester
<#
.SYNOPSIS
    Pester tests for modules/Configuration.psm1
#>

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Import-Module "$ProjectRoot\modules\Configuration.psm1" -Force

Describe "Get-ProjectConfig" {
    It "loads environment.psd1 and returns a hashtable" {
        $cfg = Get-ProjectConfig -ConfigPath "$ProjectRoot\config\environment.psd1"
        $cfg | Should -BeOfType [hashtable]
    }

    It "throws when config file does not exist" {
        { Get-ProjectConfig -ConfigPath "C:\nonexistent\missing.psd1" } | Should -Throw
    }

    It "returned config contains expected keys" {
        $cfg = Get-ProjectConfig -ConfigPath "$ProjectRoot\config\environment.psd1"
        $cfg.Keys.Count | Should -BeGreaterThan 0
    }
}

Describe "Save-JsonReport" {
    BeforeAll {
        $tmpDir  = Join-Path $env:TEMP "pester-local-ai-$(Get-Random)"
        $tmpFile = Join-Path $tmpDir "test-report.json"
    }
    AfterAll {
        if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
    }

    It "creates parent directory if it does not exist" {
        Save-JsonReport -Path $tmpFile -Data @{ key = "value" }
        Test-Path $tmpDir | Should -Be $true
    }

    It "writes valid JSON" {
        Save-JsonReport -Path $tmpFile -Data @{ answer = 42 }
        $content = Get-Content $tmpFile -Raw | ConvertFrom-Json
        $content.answer | Should -Be 42
    }

    It "serialises nested objects" {
        $data = @{ outer = @{ inner = "deep" }; list = @(1, 2, 3) }
        Save-JsonReport -Path $tmpFile -Data $data
        $json = Get-Content $tmpFile -Raw | ConvertFrom-Json
        $json.outer.inner | Should -Be "deep"
    }
}

Describe "Save-MarkdownReport" {
    BeforeAll {
        $tmpDir  = Join-Path $env:TEMP "pester-local-ai-md-$(Get-Random)"
        $tmpFile = Join-Path $tmpDir "test.md"
    }
    AfterAll {
        if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
    }

    It "creates file with expected content" {
        Save-MarkdownReport -Path $tmpFile -Content "# Test`n`nHello"
        (Get-Content $tmpFile -Raw).Trim() | Should -BeLike "*Test*"
    }

    It "creates parent directory automatically" {
        Save-MarkdownReport -Path $tmpFile -Content "x"
        Test-Path $tmpDir | Should -Be $true
    }
}
