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
            @{ Path = $toolPath; Name = 'Test-ProtectedLocalAccount' },
            @{ Path = $toolPath; Name = 'Get-ProtectedLocalAccountSids' },
            @{ Path = $toolPath; Name = 'Get-RemovableLocalAccounts' },
            @{ Path = $toolPath; Name = 'Remove-LocalUserAccounts' },
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

        $script:StyledMessageImplementation = ${function:Write-StyledMessage}
        $entryPath = if ($CompiledScriptPath) { $CompiledScriptPath } else { $toolPath }
        $entryAst = [System.Management.Automation.Language.Parser]::ParseFile($entryPath, [ref]$null, [ref]$null)
        $entry = $entryAst.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'WinDeleteUserProfiles'
        }, $true)
        . ([scriptblock]::Create($entry.Extent.Text))
        $sessionTry = $entry.Body.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.TryStatementAst] }
        $finallyText = $sessionTry.Finally.Extent.Text
        $script:SessionFinallyImplementation = [scriptblock]::Create($finallyText.Substring(1, $finallyText.Length - 2))

        # Accept synthetic profiles without binding them to the real CIM provider.
        function Remove-CimInstance {
            [CmdletBinding(SupportsShouldProcess = $true)]
            param([object]$InputObject)
            throw 'CIM deletion must be mocked in regression tests'
        }

        # Never bind account regression tests to the machine's account database.
        function Get-LocalUser {
            [CmdletBinding()]
            param([string[]]$SID)
            throw 'Account enumeration must be mocked in regression tests'
        }
        function Remove-LocalUser {
            [CmdletBinding(SupportsShouldProcess = $true)]
            param([string[]]$SID)
            throw 'Account deletion must be mocked in regression tests'
        }
        function Start-ToolkitSession { param($ToolName, $SubTitle) }
        function Invoke-ToolkitReboot { param($Message, $Seconds, [switch]$SuppressIndividualReboot) }
        function Write-ToolkitError { param($Record, $ToolName) }

        Import-LocalizedData -BindingVariable italianData -BaseDirectory (Join-Path $script:RepoRoot 'languages') -FileName 'WinToolkit.psd1' -UICulture 'it-IT'
        Import-LocalizedData -BindingVariable englishData -BaseDirectory (Join-Path $script:RepoRoot 'languages') -FileName 'WinToolkit.psd1' -UICulture 'en-US'
        $script:ItalianData = $italianData
        $script:EnglishData = $englishData
        $script:SavedGlobals = @{}
        foreach ($name in @(
            'SourceTextLanguageData', 'SourceTextDefaultLanguageData', 'SourceTextKeyAliases',
            'CurrentLogFile', 'CurrentToolName', 'Spinners', 'GuiSessionActive', 'MsgStyles'
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
        Mock Get-LocalUser { throw 'Unexpected account enumeration in regression test' }
        Mock Remove-LocalUser { throw 'Unexpected account deletion in regression test' }
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

    Context 'Local account cleanup orchestration' {
        BeforeEach {
            $script:AccountUsersRoot = Join-Path $TestDrive 'Users'
            [void][System.IO.Directory]::CreateDirectory($script:AccountUsersRoot)
            $script:LocalAccounts = @(
                [pscustomobject]@{ Name = 'Leftover'; SID = 'S-1-5-21-100-200-300-1101'; LastLogon = $null }
            )
            Mock Get-LocalUser {
                if ($SID) { $script:LocalAccounts | Where-Object { [string]$_.SID -eq [string]$SID[0] } }
                else { $script:LocalAccounts }
            }
            Mock Remove-LocalUser {
                $script:LocalAccounts = @($script:LocalAccounts | Where-Object { [string]$_.SID -ne [string]$SID[0] })
            }
            Mock Get-CimInstance {}
            Mock Get-ChildItem {} -ParameterFilter { $Path -like 'HKLM:*' -or $LiteralPath -like 'HKLM:*' }
            Mock Get-ItemPropertyValue { $script:AccountUsersRoot } -ParameterFilter { $Name -eq 'ProfilesDirectory' }
            Mock Write-Host {}
            Mock Start-ToolkitSession {}
            Mock Invoke-ToolkitReboot {}
            Mock Write-ToolkitError {}
        }

        It 'removes leftover local accounts even when profile folders and registry entries are already gone' {
            WinDeleteUserProfiles -UsersRoot $script:AccountUsersRoot -SkipResidualFolderCleanup -SuppressIndividualReboot

            Should -Invoke Remove-LocalUser -Times 1 -Exactly -ParameterFilter {
                [string]$SID[0] -eq 'S-1-5-21-100-200-300-1101' -and $ErrorAction -eq 'Stop' -and -not $Confirm
            }
            $script:LocalAccounts.Count | Should -Be 0
            Should -Invoke Remove-CimInstance -Times 0 -Exactly
            Should -Invoke Remove-Item -Times 0 -Exactly
        }

        It 'removes the account by SID after cleaning a differently named profile folder' {
            $script:AccountProfiles = @([pscustomobject]@{
                LocalPath = (Join-Path $script:AccountUsersRoot 'DifferentFolder')
                SID = $script:LocalAccounts[0].SID; Loaded = $false; Special = $false
            })
            $script:AccountEvents = [System.Collections.Generic.List[string]]::new()
            Mock Get-CimInstance { if ($ClassName -eq 'Win32_UserProfile') { $script:AccountProfiles } }
            Mock Test-Path { [System.IO.Directory]::Exists($LiteralPath) }
            Mock Test-Path { $false } -ParameterFilter { $LiteralPath -like 'HKLM:*' }
            Mock Remove-CimInstance {
                $script:AccountEvents.Add('Profile')
                $script:AccountProfiles = @()
            }
            Mock Remove-LocalUser {
                $script:AccountEvents.Add("Account:$($SID[0])")
                $script:LocalAccounts = @()
            }

            WinDeleteUserProfiles -UsersRoot $script:AccountUsersRoot -SkipResidualFolderCleanup -SuppressIndividualReboot

            ($script:AccountEvents -join ',') | Should -Be 'Profile,Account:S-1-5-21-100-200-300-1101'
        }

        It 'preserves a renamed built-in account and its differently named profile' {
            $script:LocalAccounts = @([pscustomobject]@{ Name = 'RenamedAdmin'; SID = 'S-1-5-21-100-200-300-500' })
            Mock Get-CimInstance {
                if ($ClassName -eq 'Win32_UserProfile') {
                    [pscustomobject]@{
                        LocalPath = (Join-Path $script:AccountUsersRoot 'FormerAdminFolder')
                        SID = 'S-1-5-21-100-200-300-500'; Loaded = $false; Special = $false
                    }
                }
            }

            WinDeleteUserProfiles -UsersRoot $script:AccountUsersRoot -SkipResidualFolderCleanup -SuppressIndividualReboot

            Should -Invoke Remove-CimInstance -Times 0 -Exactly
            Should -Invoke Remove-LocalUser -Times 0 -Exactly
        }

        It 'includes an account deletion failure in the summary and restart handling' {
            Mock Remove-LocalUser { throw 'Synthetic account access denied' }

            WinDeleteUserProfiles -UsersRoot $script:AccountUsersRoot -SkipResidualFolderCleanup -SuppressIndividualReboot

            Get-Content -LiteralPath $Global:CurrentLogFile -Raw | Should -Match '\[ERROR\].*Synthetic account access denied'
            $message = Get-SourceTextLoc 'toolText.itemsNotRemoved0' -Args @(1)
            Should -Invoke Write-StyledMessage -Times 1 -Exactly -ParameterFilter { $Text -eq $message }
            Should -Invoke Invoke-ToolkitReboot -Times 1 -Exactly -ParameterFilter { $SuppressIndividualReboot }
        }

        It 'reports failure when account deletion returns without actually removing the account' {
            Mock Remove-LocalUser {}

            WinDeleteUserProfiles -UsersRoot $script:AccountUsersRoot -SkipResidualFolderCleanup -SuppressIndividualReboot

            $message = Get-SourceTextLoc 'toolText.localAccountStillExists0' -Args @($script:LocalAccounts[0].SID)
            Get-Content -LiteralPath $Global:CurrentLogFile -Raw | Should -Match ([regex]::Escape($message))
            Should -Invoke Invoke-ToolkitReboot -Times 1 -Exactly
        }

        It 'stops before deleting profile data when local account discovery fails' {
            Mock Get-LocalUser { throw 'Synthetic account discovery failure' }

            { WinDeleteUserProfiles -UsersRoot $script:AccountUsersRoot -SkipResidualFolderCleanup } | Should -Throw '*Synthetic account discovery failure*'

            Should -Invoke Remove-CimInstance -Times 0 -Exactly
            Should -Invoke Remove-Item -Times 0 -Exactly
            Should -Invoke Remove-LocalUser -Times 0 -Exactly
        }

        It 'preserves accounts that become active between candidate discovery and account deletion' {
            $script:LogonScans = 0
            Mock Get-CimInstance {
                if ($ClassName -eq 'Win32_LoggedOnUser') {
                    $script:LogonScans++
                    if ($script:LogonScans -ge 3) {
                        [pscustomobject]@{ Antecedent = [pscustomobject]@{ Domain = $env:COMPUTERNAME; Name = 'Leftover' } }
                    }
                }
            }

            WinDeleteUserProfiles -UsersRoot $script:AccountUsersRoot -SkipResidualFolderCleanup -SuppressIndividualReboot

            Should -Invoke Remove-LocalUser -Times 0 -Exactly
            $message = Get-SourceTextLoc 'toolText.localAccountProtected0' -Args @('Leftover')
            Get-Content -LiteralPath $Global:CurrentLogFile -Raw | Should -Match ([regex]::Escape($message))
        }

        It 'stops before deleting data when independent logon discovery fails' {
            Mock Get-CimInstance { throw 'Synthetic logon discovery failure' } -ParameterFilter { $ClassName -eq 'Win32_LoggedOnUser' }

            { WinDeleteUserProfiles -UsersRoot $script:AccountUsersRoot -SkipResidualFolderCleanup } | Should -Throw '*Synthetic logon discovery failure*'

            Should -Invoke Remove-CimInstance -Times 0 -Exactly
            Should -Invoke Remove-Item -Times 0 -Exactly
            Should -Invoke Remove-LocalUser -Times 0 -Exactly
        }
    }

    Context 'Local account selection protections' {
        BeforeEach {
            $usersRoot = [System.IO.Path]::GetFullPath((Join-Path $TestDrive ([guid]::NewGuid().ToString())) + '\')
            $profilesDirectory = $usersRoot
            $computerName = 'ProfileTestMachine'
            $currentUserSid = 'S-1-5-21-100-200-300-1100'
            $protectedProfileNames = @('Public', 'Default', 'DefaultAccount', 'WDAGUtilityAccount', 'WSIAccount', 'CurrentAccount')
            $minimumLastUseDate = $null
            $script:CandidateAccount = [pscustomobject]@{
                Name = 'Leftover'; SID = 'S-1-5-21-100-200-300-1101'; LastLogon = (Get-Date).AddDays(-90)
            }
            Mock Get-CimInstance {}
            Mock Get-ChildItem {} -ParameterFilter { $LiteralPath -like 'HKLM:*' }
        }

        It 'protects <Name> independently of profile folder names' -ForEach @(
            @{ Name = 'RenamedAdministrator'; SID = 'S-1-5-21-100-200-300-500' },
            @{ Name = 'RenamedGuest'; SID = 'S-1-5-21-100-200-300-501' },
            @{ Name = 'RenamedDefaultAccount'; SID = 'S-1-5-21-100-200-300-503' },
            @{ Name = 'RenamedWDAGAccount'; SID = 'S-1-5-21-100-200-300-504' },
            @{ Name = 'WSIAccount'; SID = 'S-1-5-21-100-200-300-1001' },
            @{ Name = 'CurrentRenamed'; SID = 'S-1-5-21-100-200-300-1100' },
            @{ Name = 'CURRENTACCOUNT'; SID = 'S-1-5-21-100-200-300-1102' },
            @{ Name = 'System'; SID = 'S-1-5-18' },
            @{ Name = 'Unknown'; SID = '' }
        ) {
            $account = [pscustomobject]@{ Name = $Name; SID = $SID }

            @(Get-RemovableLocalAccounts -Accounts @($account)).Count | Should -Be 0
            @(Remove-LocalUserAccounts -Accounts @($account)).Count | Should -Be 0

            Should -Invoke Remove-LocalUser -Times 0 -Exactly
        }

        It 'preserves every account with a remaining profile, including loaded or outside-root profiles' {
            Mock Get-CimInstance {
                [pscustomobject]@{ SID = $script:CandidateAccount.SID; LocalPath = 'D:\OtherProfiles\Leftover'; Loaded = $true }
            }

            @(Get-RemovableLocalAccounts -Accounts @($script:CandidateAccount)).Count | Should -Be 0
        }

        It 'preserves active local logons even without a loaded or registered profile' {
            Mock Get-CimInstance {
                [pscustomobject]@{ Antecedent = [pscustomobject]@{ Domain = 'ProfileTestMachine'; Name = 'Leftover' } }
            } -ParameterFilter { $ClassName -eq 'Win32_LoggedOnUser' }

            @(Get-RemovableLocalAccounts -Accounts @($script:CandidateAccount)).Count | Should -Be 0
        }

        It 'preserves accounts configured for services using <StartName>' -ForEach @(
            @{ StartName = 'Leftover' },
            @{ StartName = '.\Leftover' },
            @{ StartName = 'ProfileTestMachine\Leftover' },
            @{ StartName = 'Leftover@ProfileTestMachine' }
        ) {
            Mock Get-CimInstance { [pscustomobject]@{ StartName = $StartName; State = 'Stopped' } } -ParameterFilter { $ClassName -eq 'Win32_Service' }

            @(Get-RemovableLocalAccounts -Accounts @($script:CandidateAccount)).Count | Should -Be 0
        }

        It 'preserves accounts whose ProfileList entry remains<Backup>' -ForEach @(
            @{ Backup = '' }, @{ Backup = '.bak' }
        ) {
            Mock Get-ChildItem { [pscustomobject]@{ PSChildName = ($script:CandidateAccount.SID + $Backup) } } -ParameterFilter { $LiteralPath -like 'HKLM:*' }

            @(Get-RemovableLocalAccounts -Accounts @($script:CandidateAccount)).Count | Should -Be 0
        }

        It 'preserves the account after profile cleanup failed even when CIM and registry entries are gone' {
            $result = [pscustomobject]@{ Sid = $script:CandidateAccount.SID; Success = $false }

            @(Get-RemovableLocalAccounts -Accounts @($script:CandidateAccount) -ProfileResults @($result)).Count | Should -Be 0
        }

        It 'preserves accounts with residual profile folders that were not removed' {
            [void][System.IO.Directory]::CreateDirectory((Join-Path $usersRoot $script:CandidateAccount.Name))

            @(Get-RemovableLocalAccounts -Accounts @($script:CandidateAccount)).Count | Should -Be 0
        }

        It 'does not select unrelated profile-less accounts under a custom users root' {
            $profilesDirectory = [System.IO.Path]::GetFullPath((Join-Path $TestDrive 'OtherUsers') + '\')

            @(Get-RemovableLocalAccounts -Accounts @($script:CandidateAccount)).Count | Should -Be 0

            $result = [pscustomobject]@{ Sid = $script:CandidateAccount.SID; Success = $true }
            @(Get-RemovableLocalAccounts -Accounts @($script:CandidateAccount) -ProfileResults @($result)).Count | Should -Be 1
        }

        It 'requires a known old logon for profile-less accounts when an age limit is requested' {
            $minimumLastUseDate = (Get-Date).AddDays(-30)
            $accounts = @(
                $script:CandidateAccount,
                [pscustomobject]@{ Name = 'Recent'; SID = 'S-1-5-21-100-200-300-1102'; LastLogon = (Get-Date).AddDays(-1) },
                [pscustomobject]@{ Name = 'NeverUsed'; SID = 'S-1-5-21-100-200-300-1103'; LastLogon = $null }
            )

            $targets = @(Get-RemovableLocalAccounts -Accounts $accounts)

            $targets.Count | Should -Be 1
            $targets[0].Name | Should -Be 'Leftover'
        }

        It 'does not delete accounts when profile discovery fails in <Provider>' -ForEach @(
            @{ Provider = 'CIM' }, @{ Provider = 'Registry' }
        ) {
            if ($Provider -eq 'CIM') { Mock Get-CimInstance { throw 'Synthetic profile discovery failure' } }
            else { Mock Get-ChildItem { throw 'Synthetic profile discovery failure' } -ParameterFilter { $LiteralPath -like 'HKLM:*' } }

            { Get-RemovableLocalAccounts -Accounts @($script:CandidateAccount) } | Should -Throw '*Synthetic profile discovery failure*'

            Should -Invoke Remove-LocalUser -Times 0 -Exactly
        }

        It 'continues with the next account after a deletion failure' {
            $accounts = @($script:CandidateAccount, [pscustomobject]@{ Name = 'Next'; SID = 'S-1-5-21-100-200-300-1102' })
            $script:RemainingAccounts = $accounts
            Mock Remove-LocalUser {
                if ([string]$SID[0] -eq $script:CandidateAccount.SID) { throw 'Synthetic account failure' }
                $script:RemainingAccounts = @($script:RemainingAccounts | Where-Object { [string]$_.SID -ne [string]$SID[0] })
            }
            Mock Get-LocalUser {
                if ($SID) { $script:RemainingAccounts | Where-Object { [string]$_.SID -eq [string]$SID[0] } }
                else { $script:RemainingAccounts }
            }

            $results = @(Remove-LocalUserAccounts -Accounts $accounts)

            $results.Count | Should -Be 2
            $results[0].Success | Should -BeFalse
            $results[1].Success | Should -BeTrue
            $results[1].Type | Should -Be 'LocalAccount'
            Should -Invoke Remove-LocalUser -Times 2 -Exactly
        }

        It 'does not count failed account verification as successful deletion' {
            Mock Remove-LocalUser {}
            Mock Get-LocalUser {
                if ($SID) { $script:CandidateAccount }
                else { throw 'Synthetic verification failure' }
            }

            $result = Remove-LocalUserAccounts -Accounts @($script:CandidateAccount)

            $result.Success | Should -BeFalse
            Get-Content -LiteralPath $Global:CurrentLogFile -Raw | Should -Match '\[ERROR\].*Synthetic verification failure'
            Should -Invoke Remove-LocalUser -Times 1 -Exactly
        }

        It 'does not delete accounts if activity discovery fails immediately before removal' {
            Mock Get-LocalUser { $script:CandidateAccount }
            Mock Get-CimInstance { throw 'Synthetic activity discovery failure' } -ParameterFilter { $ClassName -eq 'Win32_LoggedOnUser' }

            $result = Remove-LocalUserAccounts -Accounts @($script:CandidateAccount)

            $result.Success | Should -BeFalse
            Should -Invoke Remove-LocalUser -Times 0 -Exactly
        }

        It 'refreshes renamed accounts by SID before checking whether they are active' {
            Mock Get-LocalUser { [pscustomobject]@{ Name = 'RenamedActive'; SID = $script:CandidateAccount.SID } }
            Mock Get-CimInstance {
                [pscustomobject]@{ Antecedent = [pscustomobject]@{ Domain = 'ProfileTestMachine'; Name = 'RenamedActive' } }
            } -ParameterFilter { $ClassName -eq 'Win32_LoggedOnUser' }

            $result = Remove-LocalUserAccounts -Accounts @($script:CandidateAccount)

            $result.Success | Should -BeFalse
            Should -Invoke Get-LocalUser -Times 1 -Exactly -ParameterFilter { [string]$SID[0] -eq $script:CandidateAccount.SID }
            Should -Invoke Remove-LocalUser -Times 0 -Exactly
        }

        It 'preserves accounts whose profile<RestoredState> reappears after candidate selection' -ForEach @(
            @{ RestoredState = ' registration' }, @{ RestoredState = ' folder' }
        ) {
            $targets = @(Get-RemovableLocalAccounts -Accounts @($script:CandidateAccount))
            $targets.Count | Should -Be 1
            Mock Get-LocalUser { $script:CandidateAccount }
            if ($RestoredState -eq ' registration') {
                Mock Get-CimInstance { [pscustomobject]@{ SID = $script:CandidateAccount.SID } } -ParameterFilter { $ClassName -eq 'Win32_UserProfile' }
            }
            else {
                [void][System.IO.Directory]::CreateDirectory((Join-Path $usersRoot $script:CandidateAccount.Name))
            }

            $result = Remove-LocalUserAccounts -Accounts $targets

            $result.Success | Should -BeFalse
            Should -Invoke Remove-LocalUser -Times 0 -Exactly
        }
    }

    Context 'Styled messages written once to the tool log' {
        BeforeEach {
            $usersRoot = [System.IO.Path]::GetFullPath((Join-Path $TestDrive 'Users') + '\')
            $protectedProfileNames = @('Public', 'Default')
            $Global:MsgStyles = @{
                Info = @{ Icon = '[INFO]'; Color = 'Cyan' }
                Warning = @{ Icon = '[WARNING]'; Color = 'Yellow' }
            }
            Mock Write-Host {}
            Mock Write-StyledMessage { & $script:StyledMessageImplementation -Type $Type -Text $Text }
            Mock Get-CimInstance {}
            Mock Get-ChildItem {} -ParameterFilter { $Path -eq $usersRoot -or $Path -like 'HKLM:*' }
        }

        It 'logs the registered-profile scan once per invocation' {
            $message = Get-SourceTextLoc 'toolText.scanningRegisteredLocalProfiles'
            $pattern = '\[INFO\].*' + [regex]::Escape($message) + '$'

            Get-RemovableUserProfiles

            @(Get-Content -LiteralPath $Global:CurrentLogFile | Where-Object { $_ -match $pattern }).Count | Should -Be 1

            Get-RemovableUserProfiles

            @(Get-Content -LiteralPath $Global:CurrentLogFile | Where-Object { $_ -match $pattern }).Count | Should -Be 2
        }

        It 'logs a CIM detection failure once with its warning level and error text' {
            Mock Get-CimInstance { throw 'Synthetic CIM detection failure' }
            $message = Get-SourceTextLoc 'toolText.cimProfileDetectionFailed0' -Args @('Synthetic CIM detection failure')
            $pattern = '\[WARNING\]\s+' + [regex]::Escape($message) + '$'

            $profiles = @(Get-RemovableUserProfiles)

            $profiles.Count | Should -Be 0
            @(Get-Content -LiteralPath $Global:CurrentLogFile | Where-Object { $_ -match $pattern }).Count | Should -Be 1
            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like '*Synthetic CIM detection failure*' }
        }

        It 'logs the residual-folder scan once' {
            $message = Get-SourceTextLoc 'toolText.checkResidualFoldersInTheUsersDirectory'
            $pattern = '\[INFO\].*' + [regex]::Escape($message) + '$'

            $folders = @(Get-ResidualUserFolders)

            $folders.Count | Should -Be 0
            @(Get-Content -LiteralPath $Global:CurrentLogFile | Where-Object { $_ -match $pattern }).Count | Should -Be 1
        }

        It 'logs session completion once after a <Name> exit' -ForEach @(
            @{ Name = 'normal'; Fail = $false },
            @{ Name = 'failed'; Fail = $true }
        ) {
            $message = Get-SourceTextLoc 'toolText.winDeleteUserProfilesSessionEnded'
            $pattern = '\[INFO\].*' + [regex]::Escape($message) + '$'
            $failure = $null

            try {
                try {
                    if ($Fail) { throw 'Synthetic session failure' }
                }
                finally {
                    & $script:SessionFinallyImplementation
                }
            }
            catch {
                $failure = $_.Exception.Message
            }

            if ($Fail) { $failure | Should -Be 'Synthetic session failure' }
            else { $failure | Should -BeNullOrEmpty }
            @(Get-Content -LiteralPath $Global:CurrentLogFile | Where-Object { $_ -match $pattern }).Count | Should -Be 1
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
