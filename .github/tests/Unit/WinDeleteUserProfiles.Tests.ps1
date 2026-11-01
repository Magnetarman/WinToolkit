# WinToolkit CI/CD V4.2.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
Regression coverage for sequential profile cleanup without deleting Windows profiles.
Loads individual function definitions from the AST, never the tool or toolkit scripts.
Deletion commands are mocked; folder removal tests use empty TestDrive directories.
#>
param([string]$CompiledScriptPath)

Describe 'WinDeleteUserProfiles safe regressions' {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        $toolPath = Join-Path $script:RepoRoot 'tools\WinDeleteUserProfiles.ps1'
        $localizationPath = Join-Path $script:RepoRoot 'wintoolkit-modules\10-Module.Localization.ps1'
        $loggingPath = Join-Path $script:RepoRoot 'wintoolkit-modules\30-Module.Logging.ps1'
        $processesPath = Join-Path $script:RepoRoot 'wintoolkit-modules\60-Module.Processes.ps1'
        $uiPath = Join-Path $script:RepoRoot 'wintoolkit-modules\20-Module.UI.ps1'

        $definitions = @(
            @{ Path = $toolPath; Name = 'New-ProtectedNameSet' },
            @{ Path = $toolPath; Name = 'Get-RemovableUserProfiles' },
            @{ Path = $toolPath; Name = 'Get-RegisteredProfilePathSet' },
            @{ Path = $toolPath; Name = 'Get-ResidualUserFolders' },
            @{ Path = $toolPath; Name = 'Remove-UserProfile' },
            @{ Path = $toolPath; Name = 'Invoke-ProfileRemovalBatch' },
            @{ Path = $toolPath; Name = 'Remove-ProfileRegistryEntries' },
            @{ Path = $toolPath; Name = 'Remove-ResidualUserFolders' },
            @{ Path = $localizationPath; Name = 'Get-SourceTextLoc' },
            @{ Path = $loggingPath; Name = 'Write-ToolkitLog' },
            @{ Path = $processesPath; Name = 'Invoke-ExternalCommandWithLog' },
            @{ Path = $processesPath; Name = 'Remove-ItemSafely' },
            @{ Path = $uiPath; Name = 'Write-StyledMessage' },
            @{ Path = $uiPath; Name = 'Clear-ProgressLine' },
            @{ Path = $uiPath; Name = 'Write-ProgressUpdate' }
        )
        foreach ($definition in $definitions) {
            $path = if ($CompiledScriptPath) { $CompiledScriptPath } else { $definition.Path }
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors)
            if ($errors) { throw "Invalid PowerShell syntax in $path" }
            $function = $ast.Find({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $definition.Name
            }, $true)
            if (-not $function) { throw "Missing helper $($definition.Name) in $path" }
            . ([scriptblock]::Create($function.Extent.Text))
        }

        # Accept synthetic profiles without binding them to the real CIM provider.
        function Remove-CimInstance {
            [CmdletBinding(SupportsShouldProcess = $true)]
            param([object]$InputObject)
            throw 'CIM deletion must be mocked in regression tests'
        }

        Import-LocalizedData -BindingVariable italianData -BaseDirectory (Join-Path $script:RepoRoot 'languages') -FileName 'WinToolkit.psd1' -UICulture 'it-IT'
        Import-LocalizedData -BindingVariable englishData -BaseDirectory (Join-Path $script:RepoRoot 'languages') -FileName 'WinToolkit.psd1' -UICulture 'en-US'
        $script:ItalianData = $italianData
        $script:EnglishData = $englishData
        $script:SavedGlobals = @{}
        foreach ($name in @(
            'SourceTextLanguageData', 'SourceTextDefaultLanguageData', 'SourceTextKeyAliases',
            'CurrentLogFile', 'CurrentToolName', 'Spinners', 'GuiSessionActive'
        )) {
            $variable = Get-Variable -Name $name -Scope Global -ErrorAction SilentlyContinue
            $script:SavedGlobals[$name] = @{ Exists = $null -ne $variable; Value = if ($variable) { $variable.Value } else { $null } }
        }
    }

    BeforeEach {
        $Global:SourceTextLanguageData = $script:ItalianData.Clone()
        $Global:SourceTextDefaultLanguageData = $script:EnglishData.Clone()
        $Global:SourceTextKeyAliases = @{}
        $Global:CurrentLogFile = Join-Path $TestDrive 'profile-cleanup.log'
        $Global:CurrentToolName = 'ProfileCleanupProbe'
        $Global:Spinners = '|/-\'.ToCharArray()
        $Global:GuiSessionActive = $false
        Set-Content -LiteralPath $Global:CurrentLogFile -Value '' -Encoding UTF8
        Mock Write-ProgressUpdate {}
        Mock Clear-ProgressLine {}
        Mock Write-StyledMessage {}
        Mock Remove-CimInstance { throw 'Unexpected CIM deletion in regression test' }
        Mock Remove-Item { throw 'Unexpected deletion target in regression test' }
        Mock Invoke-ExternalCommandWithLog { throw 'Unexpected external command in regression test' }
    }

    AfterAll {
        foreach ($name in $script:SavedGlobals.Keys) {
            $saved = $script:SavedGlobals[$name]
            if ($saved.Exists) {
                Set-Variable -Name $name -Scope Global -Value $saved.Value
            }
            else {
                Remove-Variable -Name $name -Scope Global -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Sequential registered-profile removal' {
        BeforeEach {
            $script:SequenceEvents = [System.Collections.Generic.List[string]]::new()
            $script:BatchProgress = [System.Collections.Generic.List[int]]::new()
            Mock Write-ProgressUpdate { $script:BatchProgress.Add($Percent) }
            $script:SequentialProfiles = @('First', 'Second', 'Third') | ForEach-Object {
                [pscustomobject]@{ LocalPath = (Join-Path $TestDrive $_); SID = "S-1-5-21-189-$_" }
            }
        }

        It 'finishes CIM and registry cleanup for each profile before starting the next' {
            Mock Remove-CimInstance {
                $script:SequenceEvents.Add("CIM:$([System.IO.Path]::GetFileName($InputObject.LocalPath))")
            }
            Mock Remove-ProfileRegistryEntries {
                $script:SequenceEvents.Add("Registry:$UserName")
                $true
            }

            $results = @(Invoke-ProfileRemovalBatch -Profiles $script:SequentialProfiles)

            ($script:SequenceEvents -join ',') | Should -Be 'CIM:First,Registry:First,CIM:Second,Registry:Second,CIM:Third,Registry:Third'
            ($results.UserName -join ',') | Should -Be 'First,Second,Third'
            $results.Count | Should -Be 3
            @($results | Where-Object { -not $_.Success }).Count | Should -Be 0
            $script:BatchProgress[-1] | Should -Be 100
            Should -Invoke Clear-ProgressLine -Times 1 -Exactly
            Should -Invoke Remove-Item -Times 0 -Exactly
            Should -Invoke Invoke-ExternalCommandWithLog -Times 0 -Exactly
        }

        It 'keeps one failed result and continues after an unexpected profile exception' {
            Mock Remove-UserProfile {
                $name = [System.IO.Path]::GetFileName($ProfileItem.LocalPath)
                $script:SequenceEvents.Add($name)
                if ($name -eq 'Second') { throw 'Synthetic profile failure' }
                [pscustomobject]@{
                    Type = 'Profile'; UserName = $name; Path = $ProfileItem.LocalPath
                    Sid = $ProfileItem.SID; Success = $true; Duration = [TimeSpan]::Zero
                }
            }

            $results = @(Invoke-ProfileRemovalBatch -Profiles $script:SequentialProfiles)

            ($script:SequenceEvents -join ',') | Should -Be 'First,Second,Third'
            $results.Count | Should -Be 3
            $results[0].Success | Should -BeTrue
            $results[1].Success | Should -BeFalse
            $results[1].Type | Should -Be 'Profile'
            $results[1].UserName | Should -Be 'Second'
            $results[1].Path | Should -Be $script:SequentialProfiles[1].LocalPath
            $results[1].Sid | Should -Be $script:SequentialProfiles[1].SID
            $results[2].Success | Should -BeTrue
            Get-Content -LiteralPath $Global:CurrentLogFile -Raw | Should -Match '\[ERROR\].*Synthetic profile failure'
            $script:BatchProgress[-1] | Should -Be 100
        }

        It 'uses the current localization and logging context without copying state' {
            Mock Remove-CimInstance {}
            Mock Remove-ProfileRegistryEntries { $true }
            $Global:SourceTextKeyAliases['toolText.cimProfileRemoved0'] = 'test.alias'
            $Global:SourceTextDefaultLanguageData['test.alias'] = 'Current context: {0}'

            $results = @(Invoke-ProfileRemovalBatch -Profiles @($script:SequentialProfiles[0]))

            $results.Count | Should -Be 1
            $results[0].Success | Should -BeTrue
            Get-Content -LiteralPath $Global:CurrentLogFile -Raw | Should -Match 'Current context: First'
            $Global:GuiSessionActive | Should -BeFalse
        }

        It 'clears the progress line when progress reporting fails' {
            Mock Write-ProgressUpdate { throw 'Synthetic progress failure' }
            Mock Remove-UserProfile { throw 'Profile removal must not start' }

            { Invoke-ProfileRemovalBatch -Profiles $script:SequentialProfiles } | Should -Throw '*Synthetic progress failure*'

            Should -Invoke Clear-ProgressLine -Times 1 -Exactly
            Should -Invoke Remove-UserProfile -Times 0 -Exactly
        }
    }

    Context 'Folder removal failures with mocked Windows operations' {
        BeforeEach {
            $script:ProbeFolderPath = Join-Path $TestDrive 'Issue189[Probe]'
            [void][System.IO.Directory]::CreateDirectory($script:ProbeFolderPath)
            $script:ProbeProfile = [pscustomobject]@{
                LocalPath = $script:ProbeFolderPath
                SID = 'S-1-5-21-189-1'
            }
            $script:RemovalAttempts = 0
            Mock Remove-CimInstance { throw 'Synthetic CIM removal failure' }
            Mock Remove-ProfileRegistryEntries { $true }
            Mock Invoke-ExternalCommandWithLog { [pscustomobject]@{ Success = $true; ExitCode = 0 } }
            Mock Remove-ItemSafely { $false }
            Mock Test-Path { $true } -ParameterFilter { $Path -eq (Join-Path $env:TEMP 'EmptyFolder') }
            Mock Clear-ProgressLine {}
            Mock Write-ProgressUpdate {}
        }

        It 'recovers with ACL reset when the first literal folder removal fails' {
            Mock Remove-Item {
                $script:RemovalAttempts++
                if ($script:RemovalAttempts -eq 1) { throw 'Synthetic access denied' }
                if ($LiteralPath -ne $script:ProbeFolderPath) { throw 'Unexpected deletion target' }
                [System.IO.Directory]::Delete($LiteralPath)
            }

            $result = Remove-UserProfile -ProfileItem $script:ProbeProfile

            $result.Success | Should -BeTrue
            [System.IO.Directory]::Exists($script:ProbeFolderPath) | Should -BeFalse
            Should -Invoke Remove-Item -Times 2 -Exactly -ParameterFilter {
                $LiteralPath -eq $script:ProbeFolderPath -and $Recurse -and $Force -and $ErrorAction -eq 'Stop'
            }
            Should -Invoke Invoke-ExternalCommandWithLog -Times 1 -Exactly -ParameterFilter { $Command -eq 'takeown.exe' }
            Should -Invoke Invoke-ExternalCommandWithLog -Times 1 -Exactly -ParameterFilter {
                $Command -eq 'robocopy.exe' -and $Arguments -contains '/XJ'
            }
            Should -Invoke Invoke-ExternalCommandWithLog -Times 1 -Exactly -ParameterFilter {
                $Command -eq 'icacls.exe' -and $Arguments -contains '*S-1-5-32-544:F'
            }
            Should -Invoke Remove-ProfileRegistryEntries -Times 1 -Exactly -ParameterFilter { $Sid -eq $script:ProbeProfile.SID }
            Should -Invoke Remove-ItemSafely -Times 0 -Exactly
        }

        It 'reports failure and preserves the registry when both folder removal attempts fail' {
            Mock Remove-Item { throw 'Synthetic access denied' }

            $result = Remove-UserProfile -ProfileItem $script:ProbeProfile

            $result.Success | Should -BeFalse
            [System.IO.Directory]::Exists($script:ProbeFolderPath) | Should -BeTrue
            Should -Invoke Remove-Item -Times 2 -Exactly
            Should -Invoke Remove-ProfileRegistryEntries -Times 0 -Exactly
            Get-Content -LiteralPath $Global:CurrentLogFile -Raw | Should -Match '\[ERROR\].*Synthetic access denied'
        }

        It 'checks the remaining registry entry even when CIM reported success' {
            Mock Remove-CimInstance {}
            Mock Remove-ProfileRegistryEntries { $false }
            Mock Remove-Item {
                if ($LiteralPath -ne $script:ProbeFolderPath) { throw 'Unexpected deletion target' }
                [System.IO.Directory]::Delete($LiteralPath)
            }

            $result = Remove-UserProfile -ProfileItem $script:ProbeProfile

            $result.Success | Should -BeFalse
            [System.IO.Directory]::Exists($script:ProbeFolderPath) | Should -BeFalse
            Should -Invoke Remove-ProfileRegistryEntries -Times 1 -Exactly
        }

        It 'retries a residual folder using its literal path after ACL reset' {
            Mock Remove-Item {
                $script:RemovalAttempts++
                if ($script:RemovalAttempts -eq 1) { throw 'Synthetic access denied' }
                if ($LiteralPath -ne $script:ProbeFolderPath) { throw 'Unexpected deletion target' }
                [System.IO.Directory]::Delete($LiteralPath)
            }
            $folder = [pscustomobject]@{ Name = 'Issue189[Probe]'; Path = $script:ProbeFolderPath }

            $result = Remove-ResidualUserFolders -Folders @($folder)

            $result.Success | Should -BeTrue
            Should -Invoke Remove-Item -Times 2 -Exactly -ParameterFilter {
                $LiteralPath -eq $script:ProbeFolderPath -and $Recurse -and $Force -and $ErrorAction -eq 'Stop'
            }
            Should -Invoke Invoke-ExternalCommandWithLog -Times 1 -Exactly -ParameterFilter {
                $Command -eq 'icacls.exe' -and $Arguments -contains '*S-1-5-32-544:F'
            }
        }

        It 'reports a residual folder failure when ACL recovery cannot remove it' {
            Mock Remove-Item { throw 'Synthetic access denied' }
            $folder = [pscustomobject]@{ Name = 'Issue189[Probe]'; Path = $script:ProbeFolderPath }

            $result = Remove-ResidualUserFolders -Folders @($folder)

            $result.Success | Should -BeFalse
            [System.IO.Directory]::Exists($script:ProbeFolderPath) | Should -BeTrue
            Should -Invoke Remove-Item -Times 2 -Exactly
            Get-Content -LiteralPath $Global:CurrentLogFile -Raw | Should -Match '\[ERROR\].*Synthetic access denied'
        }
    }

    Context 'Localized arguments with zero or empty values' {
        It 'formats the <Name> argument' -ForEach @(
            @{ Name = 'zero'; Value = 0; Expected = 'Value: 0' },
            @{ Name = 'false'; Value = $false; Expected = 'Value: False' },
            @{ Name = 'empty string'; Value = ''; Expected = 'Value: ' },
            @{ Name = 'null'; Value = $null; Expected = 'Value: ' },
            @{ Name = 'nonzero'; Value = 2; Expected = 'Value: 2' }
        ) {
            $Global:SourceTextLanguageData['test.argument'] = 'Value: {0}'
            Get-SourceTextLoc 'test.argument' -Args @($Value) | Should -Be $Expected
        }

        It 'leaves the template intact when no arguments are supplied' {
            $Global:SourceTextLanguageData['test.argument'] = 'Value: {0}'
            Get-SourceTextLoc 'test.argument' | Should -Be 'Value: {0}'
        }

        It 'prints both Italian zero counts in the cleanup summary' {
            Get-SourceTextLoc 'toolText.registeredProfilesRemoved0' -Args @(0) | Should -Be 'Profili registrati rimossi: 0'
            Get-SourceTextLoc 'toolText.residualFoldersRemoved0' -Args @(0) | Should -Be 'Cartelle residue rimosse: 0'
        }
    }

    Context 'Protected profile and residual-folder selection' {
        BeforeEach {
            $usersRoot = [System.IO.Path]::GetFullPath((Join-Path $TestDrive 'Users') + '\')
            $currentUserSid = 'S-1-5-21-current'
            $protectedProfileNames = @('Public', 'Default', 'Administrator', 'CurrentAccount', 'CurrentFolder')
            $minimumLastUseDate = (Get-Date).AddDays(-30)
        }

        It 'excludes loaded, special, protected, current, outside-root, and recently used profiles' {
            $script:SelectionProfiles = @(
                [pscustomobject]@{ LocalPath = ($usersRoot + 'Old'); SID = 'old'; Loaded = $false; Special = $false; LastUseTime = (Get-Date).AddDays(-90) },
                [pscustomobject]@{ LocalPath = ($usersRoot + 'Loaded'); SID = 'loaded'; Loaded = $true; Special = $false },
                [pscustomobject]@{ LocalPath = ($usersRoot + 'Special'); SID = 'special'; Loaded = $false; Special = $true },
                [pscustomobject]@{ LocalPath = ($usersRoot + 'pUbLiC'); SID = 'public'; Loaded = $false; Special = $false },
                [pscustomobject]@{ LocalPath = ($usersRoot + 'CurrentFolder'); SID = 'folder'; Loaded = $false; Special = $false },
                [pscustomobject]@{ LocalPath = ($usersRoot + 'DifferentFolder'); SID = $currentUserSid; Loaded = $false; Special = $false },
                [pscustomobject]@{ LocalPath = ($usersRoot.TrimEnd('\') + '-other\Outside'); SID = 'outside'; Loaded = $false; Special = $false },
                [pscustomobject]@{ LocalPath = ($usersRoot + 'Recent'); SID = 'recent'; Loaded = $false; Special = $false; LastUseTime = (Get-Date).AddDays(-1) },
                [pscustomobject]@{ LocalPath = $null; SID = 'missing'; Loaded = $false; Special = $false }
            )
            Mock Get-CimInstance { $script:SelectionProfiles }

            $targets = @(Get-RemovableUserProfiles)

            $targets.Count | Should -Be 1
            $targets[0].SID | Should -Be 'old'
            Should -Invoke Remove-CimInstance -Times 0 -Exactly
        }

        It 'preserves registered paths and SID folders, protected names, and reparse points' {
            $script:SelectionProfiles = @([pscustomobject]@{ LocalPath = ($usersRoot + 'StillRegistered') })
            Mock Get-CimInstance { $script:SelectionProfiles }
            $script:ResidualCandidates = @(
                [pscustomobject]@{ Name = 'Orphan'; FullName = ($usersRoot + 'Orphan'); Attributes = [IO.FileAttributes]::Directory },
                [pscustomobject]@{ Name = 'pUbLiC'; FullName = ($usersRoot + 'pUbLiC'); Attributes = [IO.FileAttributes]::Directory },
                [pscustomobject]@{ Name = 'StillRegistered'; FullName = ($usersRoot + 'StillRegistered'); Attributes = [IO.FileAttributes]::Directory },
                [pscustomobject]@{ Name = 'S-1-5-21-registered'; FullName = ($usersRoot + 'S-1-5-21-registered'); Attributes = [IO.FileAttributes]::Directory },
                [pscustomobject]@{ Name = 'Junction'; FullName = ($usersRoot + 'Junction'); Attributes = ([IO.FileAttributes]::Directory -bor [IO.FileAttributes]::ReparsePoint) }
            )
            Mock Get-ChildItem { $script:ResidualCandidates } -ParameterFilter { $Path -eq $usersRoot }
            Mock Get-ChildItem { [pscustomobject]@{ PSChildName = 'S-1-5-21-registered' } } -ParameterFilter { $Path -like 'HKLM:*' }

            $folders = @(Get-ResidualUserFolders)

            $folders.Count | Should -Be 1
            $folders[0].Name | Should -Be 'Orphan'
            $folders[0].Path | Should -Be ($usersRoot + 'Orphan')
            Should -Invoke Remove-Item -Times 0 -Exactly
        }
    }

    Context 'Registry cleanup without registry changes' {
        It 'accepts a registry entry already removed by CIM' {
            Mock Test-Path { $false } -ParameterFilter { $LiteralPath -like 'HKLM:*' }

            Remove-ProfileRegistryEntries -Sid 'S-1-5-21-189-1' -UserName 'Probe' | Should -BeTrue

            Should -Invoke Remove-Item -Times 0 -Exactly
        }

        It 'reports a failed registry removal' {
            Mock Test-Path { $true } -ParameterFilter { $LiteralPath -like 'HKLM:*' }
            Mock Remove-Item { throw 'Synthetic registry failure' }

            Remove-ProfileRegistryEntries -Sid 'S-1-5-21-189-1' -UserName 'Probe' | Should -BeFalse

            Should -Invoke Remove-Item -Times 1 -Exactly -ParameterFilter {
                $LiteralPath -eq 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\S-1-5-21-189-1' -and $Recurse -and $Force
            }
        }
    }
}
