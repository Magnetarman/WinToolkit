#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
    $script:BuildScript = Join-Path $script:RepoRoot '.github\scripts\Invoke-Build-Start.ps1'
    $script:TestScript = Join-Path $script:RepoRoot '.github\scripts\Test-CompiledStartScript.ps1'
    $script:VersionScript = Join-Path $script:RepoRoot '.github\scripts\Update-Version.ps1'
    $script:SourceDir = Join-Path $script:RepoRoot 'start-modules'
}

Describe 'Invoke-Build-Start.ps1 contract' {
    It 'exists and parses successfully' {
        $script:BuildScript | Should -Exist
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:BuildScript, [ref]$null, [ref]$errors) | Out-Null
        $errors.Count | Should -Be 0
    }

    It 'declares the required build parameters' {
        $content = Get-Content -Raw -LiteralPath $script:BuildScript
        $content | Should -Match '\[Parameter\(Mandatory\s*=\s*\$true\)\]\s*\[string\]\$Version'
        $content | Should -Match '\$SourceDir\s*=\s*''start-modules'''
        $content | Should -Match '\$OutputPath\s*=\s*''start-core\.ps1'''
    }
}

Describe 'Test-CompiledStartScript.ps1 contract' {
    It 'exists and parses successfully' {
        $script:TestScript | Should -Exist
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:TestScript, [ref]$null, [ref]$errors) | Out-Null
        $errors.Count | Should -Be 0
    }

    It 'declares ScriptPath as mandatory' {
        $content = Get-Content -Raw -LiteralPath $script:TestScript
        $content | Should -Match '\[Parameter\(Mandatory\s*=\s*\$true\)\]\[string\]\$ScriptPath'
    }
}

Describe 'Update-Version.ps1 source alignment' {
    It 'exposes aligned_sources and aligns the Start header' {
        $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "version-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $testRoot | Out-Null
        $template = Join-Path $testRoot '00-Skeleton.Header.ps1'
        $header = Join-Path $testRoot '00-Skeleton.Header.ps1'
        $output = Join-Path $testRoot 'github-output.txt'
        try {
            Copy-Item (Join-Path $script:RepoRoot 'wintoolkit-modules\00-Skeleton.Header.ps1') $template
            Copy-Item (Join-Path $script:RepoRoot 'start-modules\00-Skeleton.Header.ps1') $header
            $env:GITHUB_OUTPUT = $output
            & $script:VersionScript -TemplatePath $template -StartHeaderPath $header
            $LASTEXITCODE | Should -Be 0
            (Get-Content -Raw -LiteralPath $output) | Should -Match 'aligned_sources='
            $templateVersion = [regex]::Match((Get-Content -Raw -LiteralPath $template), '\$ToolkitVersion\s*=\s*"([^"]+)"').Groups[1].Value
            $headerVersion = [regex]::Match((Get-Content -Raw -LiteralPath $header), '\$ToolkitVersion\s*=\s*"([^"]+)"').Groups[1].Value
            $headerVersion | Should -Be $templateVersion
        }
        finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'End-to-end start-core build' {
    It 'produces a valid compiled artifact' -Tag 'Slow' {
        $output = Join-Path ([System.IO.Path]::GetTempPath()) "start-core-$([guid]::NewGuid()).ps1"
        try {
            & $script:BuildScript -Version 'Test (Build 0)' -SourceDir $script:SourceDir -OutputPath $output
            $LASTEXITCODE | Should -Be 0
            & $script:TestScript -ScriptPath $output -SourceDir $script:SourceDir
            $LASTEXITCODE | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $output -Force -ErrorAction SilentlyContinue
        }
    }
}
