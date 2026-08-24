#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
Contract-level unit coverage for tool modules without dedicated suites.
Inspects and parses each module without executing destructive Windows operations.
Runtime behavior remains covered by the dedicated GamingToolkit and WinCleaner suites.
#>

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
    $script:ToolRoot = Join-Path $script:RepoRoot 'tools'
    $script:Modules = @(
        'AutoVideoDriverInstall', 'DisableBitlocker', 'Install-Office',
        'Repair-Office', 'Uninstall-Office', 'VideoDriverReinstall',
        'WinBackupDriver', 'WinDebloat', 'WinDeleteUserProfiles',
        'WinExportLog', 'WinReinstallStore', 'WinRepairToolkit', 'WinUpdateReset'
    ) | ForEach-Object { Get-Item -LiteralPath (Join-Path $script:ToolRoot "$_`.ps1") }
}

Describe 'tools modules — structural unit contracts' {
    It '<Name> exists and has valid PowerShell syntax' -ForEach $script:Modules {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($FullName, [ref]$null, [ref]$errors) | Out-Null
        $errors.Count | Should -Be 0 -Because "$Name.ps1 must parse without syntax errors"
    }

    It '<Name> exposes one public entry function matching the file name' -ForEach $script:Modules {
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($FullName, [ref]$null, [ref]$errors)
        $functions = @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))
        @($functions | Where-Object Name -eq $BaseName).Count | Should -Be 1 -Because "$Name.ps1 must expose one public entry point"
    }

    It '<Name> does not import local modules' -ForEach $script:Modules {
        $source = Get-Content -Raw -LiteralPath $FullName
        $source | Should -Not -Match '(?m)^\s*Import-Module\s+[./\\]'
    }

    It '<Name> contains an executable function body' -ForEach $script:Modules {
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($FullName, [ref]$null, [ref]$errors)
        $entry = @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) | Where-Object Name -eq $BaseName)
        $entry[0].Body.Extent.Text.Trim().Length | Should -BeGreaterThan 2
    }
}
