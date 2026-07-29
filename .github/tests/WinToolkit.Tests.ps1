#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Pester 5 test suite for WinToolkit core functions.
.NOTES
    Scope: Write-StyledMessage, Get-WingetExecutable, Invoke-ExternalCommandWithLog,
           Read-ValidatedChoice, Write-ToolkitLog
    Strategy: functions are dot-sourced from the template with -ImportOnly
    (the template checks `if (-not $ImportOnly)` at line ~1801 before the menu).
    Where possible, Pester 5 Mock is used to isolate behavior without
    side effects on console, filesystem, or system processes.
#>

# =============================================================================
# GLOBAL SETUP
# =============================================================================
BeforeAll {
    $script:TemplatePath = Resolve-Path (Join-Path $PSScriptRoot '..\..\WinToolkit-template.ps1')

    try {
        . $script:TemplatePath -ImportOnly
    }
    catch {
        throw "Unable to load WinToolkit-template.ps1: $_"
    }

    # Initialize globals in case the template skipped them
    if (-not $Global:MsgStyles) {
        $Global:MsgStyles = @{
            Success  = @{ Icon = '[OK]';   Color = 'Green'   }
            Warning  = @{ Icon = '[WARN]'; Color = 'Yellow'  }
            Error    = @{ Icon = '[ERR]';  Color = 'Red'     }
            Info     = @{ Icon = '[INFO]'; Color = 'Cyan'    }
            Progress = @{ Icon = '[...]';  Color = 'Blue'    }
            Question = @{ Icon = '[?]';    Color = 'Magenta' }
        }
    }
    if (-not $Global:Spinners) {
        $Global:Spinners = '/-\|'.ToCharArray()
    }

    $Global:CurrentLogFile   = $null
    $Global:CurrentToolName  = 'PesterTest'
    $Global:GuiSessionActive = $false

    # Global mock to prevent hangs in CI if a function unexpectedly calls Read-Host
    Mock Read-Host { throw "Input required in CI (Headless) environment! Make sure to pass RawInput or mock the call." }
}

# =============================================================================
# Write-StyledMessage — behavior + icons + colors
# =============================================================================
Describe 'Write-StyledMessage' {

    BeforeEach {
        $Global:CurrentLogFile = $null   # Write-ToolkitLog becomes a no-op
    }

    # ── Smoke tests: no exception for any type ──────────────────────────
    It 'Must not throw an exception for type <Type>' -ForEach @(
        @{ Type = 'Success'  }
        @{ Type = 'Warning'  }
        @{ Type = 'Error'    }
        @{ Type = 'Info'     }
        @{ Type = 'Progress' }
        @{ Type = 'Question' }
    ) {
        { Write-StyledMessage -Type $Type -Text 'Smoke test' } | Should -Not -Throw
    }

    It 'Must not throw with -NoNewline' {
        { Write-StyledMessage -Type 'Question' -Text 'Prompt?' -NoNewline } | Should -Not -Throw
    }

    # ── Verify icon in console output ──────────────────────────────────
    # Mock Write-Host to capture the actual text written.
    # Write-StyledMessage output format: "[HH:mm:ss] <Icon> <Text>"
    It 'Must include the correct icon for type <Type>' -ForEach @(
        @{ Type = 'Success'  }
        @{ Type = 'Warning'  }
        @{ Type = 'Error'    }
        @{ Type = 'Info'     }
        @{ Type = 'Progress' }
        @{ Type = 'Question' }
    ) {
        $captured = $null
        Mock Write-Host { $script:captured = $Object } -Verifiable

        Write-StyledMessage -Type $Type -Text 'IconTest'

        $expectedIcon = $Global:MsgStyles[$Type].Icon
        $script:captured | Should -Match ([regex]::Escape($expectedIcon))
    }

    # ── Verify ForegroundColor ─────────────────────────────────────────
    It 'Must use the correct ForegroundColor for type <Type>' -ForEach @(
        @{ Type = 'Success'; ExpectedColor = 'Green'   }
        @{ Type = 'Warning'; ExpectedColor = 'Yellow'  }
        @{ Type = 'Error';   ExpectedColor = 'Red'     }
        @{ Type = 'Info';    ExpectedColor = 'Cyan'    }
    ) {
        $capturedColor = $null
        Mock Write-Host { $script:capturedColor = $ForegroundColor }

        Write-StyledMessage -Type $Type -Text 'ColorTest'

        $script:capturedColor | Should -Be $ExpectedColor
    }

    # ── Log bridge: verify file write ───────────────────────────────────────
    It 'Must write to the log file when CurrentLogFile is set' {
        $tmpLog = [System.IO.Path]::GetTempFileName()
        $Global:CurrentLogFile = $tmpLog
        try {
            Write-StyledMessage -Type 'Success' -Text 'LogBridgeTest'
            $content = Get-Content -Path $tmpLog -Raw -ErrorAction Stop
            $content | Should -Match 'LogBridgeTest'
        }
        finally {
            $Global:CurrentLogFile = $null
            Remove-Item $tmpLog -ErrorAction SilentlyContinue
        }
    }

    # ── Level mapping: Success → SUCCESS, Warning → WARNING, Error → ERROR
    It 'Must map type <Type> to log level <ExpectedLevel>' -ForEach @(
        @{ Type = 'Success';  ExpectedLevel = 'SUCCESS' }
        @{ Type = 'Warning';  ExpectedLevel = 'WARNING' }
        @{ Type = 'Error';    ExpectedLevel = 'ERROR'   }
        @{ Type = 'Info';     ExpectedLevel = 'INFO'    }
        @{ Type = 'Progress'; ExpectedLevel = 'INFO'    }
    ) {
        $tmpLog = [System.IO.Path]::GetTempFileName()
        $Global:CurrentLogFile = $tmpLog
        try {
            Write-StyledMessage -Type $Type -Text 'LevelMappingTest'
            $content = Get-Content -Path $tmpLog -Raw
            $content | Should -Match "\[$ExpectedLevel\]"
        }
        finally {
            $Global:CurrentLogFile = $null
            Remove-Item $tmpLog -ErrorAction SilentlyContinue
        }
    }
}

# =============================================================================
# Get-WingetExecutable — mocking Test-Path to isolate resolution logic
# =============================================================================
Describe 'Get-WingetExecutable' {

    It 'Must return a non-empty string value' {
        $result = Get-WingetExecutable
        $result | Should -BeOfType [string]
        $result | Should -Not -BeNullOrEmpty
    }

    Context 'When the App Execution alias exists' {
        BeforeEach {
            # Mock Test-Path to return $true ONLY for the alias path
            $script:AliasPath = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
            Mock Test-Path {
                param([Parameter(ValueFromPipeline)]$Path)
                $Path -eq $script:AliasPath
            }
        }

        It 'Must return the alias path' {
            $result = Get-WingetExecutable
            $result | Should -Be $script:AliasPath
        }

        It 'Must not search WindowsApps when the alias is available' {
            Mock Get-ChildItem { }   # must not be called
            $null = Get-WingetExecutable
            Should -Invoke Get-ChildItem -Times 0
        }
    }

    Context 'When no resolved path exists (fallback)' {
        BeforeEach {
            Mock Test-Path { $false }
            Mock Get-ChildItem { $null }
        }

        It 'Must return the string "winget" as fallback' {
            $result = Get-WingetExecutable
            $result | Should -Be 'winget'
        }
    }

    Context 'Real behavior on the runner (without mocks)' {

        It 'Returns the alias path if it exists on the runner' {
            $aliasPath = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
            if (Test-Path $aliasPath) {
                Get-WingetExecutable | Should -Be $aliasPath
            } else {
                Set-ItResult -Skipped -Because 'winget alias not present on this runner'
            }
        }

        It 'Returns "winget" if no resolved path exists on the runner' {
            $aliasPath = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
            $hasDirs   = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" `
                -Filter 'Microsoft.DesktopAppInstaller_*' -ErrorAction SilentlyContinue |
                Where-Object { Test-Path (Join-Path $_.FullName 'winget.exe') }
            if (-not (Test-Path $aliasPath) -and -not $hasDirs) {
                Get-WingetExecutable | Should -Be 'winget'
            } else {
                Set-ItResult -Skipped -Because 'Winget resolvable — fallback not reached'
            }
        }
    }
}

# =============================================================================
# Write-ToolkitLog — writing, formatting, Mutex and concurrency
# =============================================================================
Describe 'Write-ToolkitLog' {

    Context 'When CurrentLogFile is null (no-op)' {

        BeforeEach { $Global:CurrentLogFile = $null }

        It 'Must not throw an exception' {
            { Write-ToolkitLog -Level 'INFO' -Message 'No-op test' } | Should -Not -Throw
        }
    }

    Context 'Correct file writing' {

        BeforeEach {
            $script:tmpLog         = [System.IO.Path]::GetTempFileName()
            $Global:CurrentLogFile = $script:tmpLog
        }
        AfterEach {
            $Global:CurrentLogFile = $null
            Remove-Item $script:tmpLog -ErrorAction SilentlyContinue
        }

        It 'Must write level and message in the expected format' {
            Write-ToolkitLog -Level 'INFO' -Message 'PesterLogEntry'
            $content = Get-Content -Path $script:tmpLog -Raw
            $content | Should -Match '\[INFO\]'
            $content | Should -Match 'PesterLogEntry'
        }

        It 'The line must contain a timestamp in [HH:mm:ss] format' {
            Write-ToolkitLog -Level 'INFO' -Message 'TimestampTest'
            (Get-Content -Path $script:tmpLog -Raw) | Should -Match '\[\d{2}:\d{2}:\d{2}\]'
        }

        It 'Must strip ANSI escape codes from the message' {
            Write-ToolkitLog -Level 'INFO' -Message "`e[32mColoredText`e[0m"
            $content = Get-Content -Path $script:tmpLog -Raw
            $content | Should -Match 'ColoredText'
            $content | Should -Not -Match '\x1B'
        }

        It 'Must append context as JSON when provided' {
            Write-ToolkitLog -Level 'DEBUG' -Message 'ContextTest' -Context @{ Tool = 'Pester'; Step = 'Unit' }
            $content = Get-Content -Path $script:tmpLog -Raw
            $content | Should -Match 'Context:'
            $content | Should -Match '"Tool"'
        }

        It 'Must support all valid levels without errors' {
            foreach ($level in @('DEBUG', 'INFO', 'WARNING', 'ERROR', 'SUCCESS')) {
                { Write-ToolkitLog -Level $level -Message "Level-$level" } | Should -Not -Throw
            }
            $content = Get-Content -Path $script:tmpLog -Raw
            foreach ($level in @('DEBUG', 'WARNING', 'SUCCESS')) {
                $content | Should -Match "\[$level\]"
            }
        }
    }

    Context 'Mutex protection — concurrent writes' {

        It 'Must preserve all entries under concurrent write (5 runspaces x 5 entries = 25)' {
            $tmpLog = [System.IO.Path]::GetTempFileName()

            # Capture the function definition to pass to runspaces
            $writeToolkitLogDef = (Get-Command Write-ToolkitLog).Definition
            $writeHostMockDef = "function Write-Host { }" 

            $jobs = 1..5 | ForEach-Object {
                $idx = $_
                $rs  = [powershell]::Create()
                # Pass only the bare minimum to the runspace
                $null = $rs.AddScript(@"
                    function Write-ToolkitLog { $writeToolkitLogDef }
                    $writeHostMockDef
                    `$Global:CurrentLogFile = '$($tmpLog -replace '\\', '\\\\')'
                    for (`$i = 0; `$i -lt 5; `$i++) {
                        Write-ToolkitLog -Level 'INFO' -Message "THREAD-$idx-ENTRY-`$i"
                    }
"@)
                [PSCustomObject]@{ PS = $rs; Handle = $rs.BeginInvoke() }
            }

            foreach ($j in $jobs) {
                try { $null = $j.PS.EndInvoke($j.Handle) } catch {}
                $j.PS.Dispose()
            }

            $lines = Get-Content -Path $tmpLog | Where-Object { $_ -match 'THREAD-\d+-ENTRY-\d+' }

            # Without mutex there may be missing or corrupted entries
            $lines.Count | Should -Be 25

            Remove-Item $tmpLog -ErrorAction SilentlyContinue
        }
    }
}

# =============================================================================
# Invoke-ExternalCommandWithLog — return structure, exit codes, StdOut, timeout
# =============================================================================
Describe 'Invoke-ExternalCommandWithLog' {

    BeforeAll {
        $Global:CurrentLogFile  = $null
        $Global:CurrentToolName = 'PesterTest'
    }

    It 'Must return a PSCustomObject with all expected properties' {
        $result = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'echo probe')
        $result                                  | Should -Not -BeNull
        $result.PSObject.Properties.Name         | Should -Contain 'Success'
        $result.PSObject.Properties.Name         | Should -Contain 'ExitCode'
        $result.PSObject.Properties.Name         | Should -Contain 'StdOut'
        $result.PSObject.Properties.Name         | Should -Contain 'StdErr'
        $result.PSObject.Properties.Name         | Should -Contain 'Elapsed'
        $result.PSObject.Properties.Name         | Should -Contain 'TimedOut'
    }

    It 'Must return Success=true and ExitCode=0 for exit 0' {
        $result = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'exit 0')
        $result.Success  | Should -Be $true
        $result.ExitCode | Should -Be 0
    }

    It 'Must return Success=false for non-zero exit code (42)' {
        $result = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'exit 42')
        $result.Success  | Should -Be $false
        $result.ExitCode | Should -Be 42
    }

    It 'Must capture the process StdOut' {
        $result = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'echo PesterMarker')
        $result.StdOut | Should -Match 'PesterMarker'
    }

    It 'Must return TimedOut=true when the process exceeds the timeout' {
        # ping -n 10 takes ~9 seconds; timeout set to 1 second
        $result = Invoke-ExternalCommandWithLog `
            -Command 'cmd.exe' `
            -Arguments @('/c', 'ping -n 10 127.0.0.1 > nul') `
            -TimeoutSeconds 1
        $result.TimedOut | Should -Be $true
    }

    It 'Must return TimedOut=false for a fast command with generous timeout' {
        $result = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'exit 0') -TimeoutSeconds 30
        $result.TimedOut | Should -Be $false
    }

    It 'The Elapsed field must be a valid TimeSpan greater than zero' {
        $result = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'exit 0')
        $result.Elapsed               | Should -BeOfType [System.TimeSpan]
        $result.Elapsed.TotalSeconds  | Should -BeGreaterThan 0
    }
}

# =============================================================================
# Read-ValidatedChoice — input validation via RawInput (no console interaction)
# =============================================================================
Describe 'Read-ValidatedChoice' {

    BeforeEach {
        $Global:CurrentLogFile = $null
        # Mute Write-StyledMessage to avoid console output in tests
        Mock Write-StyledMessage { }
    }

    Context 'With ValidRange parameter' {

        It 'Must return the valid choice from ValidRange' {
            Read-ValidatedChoice -ValidRange @(1, 2, 3) -RawInput '2' | Should -Be 2
        }

        It 'Must return multiple choices separated by comma' {
            $result = Read-ValidatedChoice -ValidRange @(1, 2, 3) -RawInput '1,3'
            $result | Should -HaveCount 2
            $result | Should -Contain 1
            $result | Should -Contain 3
        }

        It 'Must return multiple choices separated by space' {
            $result = Read-ValidatedChoice -ValidRange @(1, 2, 3) -RawInput '2 3'
            $result | Should -HaveCount 2
            $result | Should -Contain 2
            $result | Should -Contain 3
        }

        It 'Must accept the minimum value of the range' {
            Read-ValidatedChoice -ValidRange @(1, 2, 3) -RawInput '1' | Should -Be 1
        }

        It 'Must accept the maximum value of the range' {
            Read-ValidatedChoice -ValidRange @(1, 2, 3) -RawInput '3' | Should -Be 3
        }
    }

    Context 'With Min and Max parameters' {

        It 'Must return a choice within the limits' {
            Read-ValidatedChoice -Min 1 -Max 10 -RawInput '7' | Should -Be 7
        }

        It 'Must accept the exact Min value' {
            Read-ValidatedChoice -Min 1 -Max 5 -RawInput '1' | Should -Be 1
        }

        It 'Must accept the exact Max value' {
            Read-ValidatedChoice -Min 1 -Max 5 -RawInput '5' | Should -Be 5
        }
    }

    Context 'With AllowZero' {

        It 'Must accept 0 when AllowZero is enabled' {
            Read-ValidatedChoice -Min 0 -Max 5 -AllowZero -RawInput '0' | Should -Be 0
        }
    }
}