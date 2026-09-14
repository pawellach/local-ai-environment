#Requires -Modules Pester
<#
.SYNOPSIS
    Pester tests for config/models.psd1 — verifies structure and required fields.
#>

$ProjectRoot  = Split-Path -Parent $PSScriptRoot
$ModelsConfig = "$ProjectRoot\config\models.psd1"

Describe "models.psd1 structure" {
    BeforeAll {
        $cfg = Import-PowerShellDataFile -Path $ModelsConfig
    }

    It "file exists" {
        Test-Path $ModelsConfig | Should -Be $true
    }

    It "contains Low, Medium, High tiers" {
        $cfg.ContainsKey("Low")    | Should -Be $true
        $cfg.ContainsKey("Medium") | Should -Be $true
        $cfg.ContainsKey("High")   | Should -Be $true
    }

    It "each tier has at least one model" {
        $cfg.Low.Count    | Should -BeGreaterThan 0
        $cfg.Medium.Count | Should -BeGreaterThan 0
        $cfg.High.Count   | Should -BeGreaterThan 0
    }

    It "every model entry has required fields" {
        $requiredFields = @("Name","OllamaTag","ApproximateSizeGB","MinRAMGB","Description")
        foreach ($tier in @("Low","Medium","High")) {
            foreach ($model in $cfg[$tier]) {
                foreach ($field in $requiredFields) {
                    $model.ContainsKey($field) | Should -Be $true -Because "$($model.Name) in $tier is missing '$field'"
                }
            }
        }
    }

    It "OllamaTag values follow name:tag format" {
        foreach ($tier in @("Low","Medium","High")) {
            foreach ($model in $cfg[$tier]) {
                $model.OllamaTag | Should -BeLike "*:*" -Because "$($model.Name) OllamaTag should be 'name:tag'"
            }
        }
    }

    It "High tier does not reference llama3.1 (deprecated)" {
        foreach ($model in $cfg.High) {
            $model.OllamaTag | Should -Not -BeLike "llama3.1*"
        }
    }

    It "Default key exists and is a non-empty string" {
        $cfg.ContainsKey("Default") | Should -Be $true
        $cfg.Default | Should -Not -BeNullOrEmpty
    }
}
