#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Suite di test Pester 5 per le funzioni core di WinToolkit.
.NOTES
    Scope: Write-StyledMessage, Get-WingetExecutable, Invoke-ExternalCommandWithLog,
           Read-ValidatedChoice, Write-ToolkitLog
    Strategia: le funzioni vengono dot-sourced dal template con -ImportOnly
    (il template controlla `if (-not $ImportOnly)` a riga ~1801 prima del menu).
    Dove possibile si usa Mock Pester 5 per isolare il comportamento senza
    effetti collaterali su console, filesystem o processi di sistema.
#>

# =============================================================================
# SETUP GLOBALE
# =============================================================================
BeforeAll {
    $script:TemplatePath = Resolve-Path (Join-Path $PSScriptRoot '..\..\WinToolkit-template.ps1')

    try {
        . $script:TemplatePath -ImportOnly
    }
    catch {
        throw "Impossibile caricare WinToolkit-template.ps1: $_"
    }

    # Inizializza i globals nel caso il template li abbia saltati
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

    # Mock globale di Read-Host per evitare hang in CI
    Mock Read-Host { return '' }
}

# =============================================================================
# Write-StyledMessage — comportamento + icone + colori
# =============================================================================
Describe 'Write-StyledMessage' {

    BeforeEach {
        $Global:CurrentLogFile = $null   # Write-ToolkitLog diventa no-op
    }

    # ── Smoke tests: nessuna eccezione per tutti i tipi ─────────────────────
    It 'Non deve lanciare eccezione per il tipo <Type>' -ForEach @(
        @{ Type = 'Success'  }
        @{ Type = 'Warning'  }
        @{ Type = 'Error'    }
        @{ Type = 'Info'     }
        @{ Type = 'Progress' }
        @{ Type = 'Question' }
    ) {
        { Write-StyledMessage -Type $Type -Text 'Smoke test' } | Should -Not -Throw
    }

    It 'Non deve lanciare eccezione con -NoNewline' {
        { Write-StyledMessage -Type 'Question' -Text 'Prompt?' -NoNewline } | Should -Not -Throw
    }

    # ── Verifica icona nell'output console ──────────────────────────────────
    # Mock Write-Host per catturare il testo effettivamente scritto.
    # L'output di Write-StyledMessage ha forma: "[HH:mm:ss] <Icon> <Text>"
    It 'Deve includere l icona corretta per il tipo <Type>' -ForEach @(
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

    # ── Verifica colore ForegroundColor ─────────────────────────────────────
    It 'Deve usare il colore ForegroundColor corretto per il tipo <Type>' -ForEach @(
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

    # ── Bridge log: verifica scrittura su file ───────────────────────────────
    It 'Deve scrivere sul file di log quando CurrentLogFile e impostato' {
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

    # ── Mapping livelli: Success → SUCCESS, Warning → WARNING, Error → ERROR
    It 'Deve mappare il tipo <Type> al livello log <ExpectedLevel>' -ForEach @(
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
# Get-WingetExecutable — mocking Test-Path per isolare la logica di risoluzione
# =============================================================================
Describe 'Get-WingetExecutable' {

    It 'Deve restituire un valore di tipo stringa non vuoto' {
        $result = Get-WingetExecutable
        $result | Should -BeOfType [string]
        $result | Should -Not -BeNullOrEmpty
    }

    Context 'Quando l alias App Execution esiste' {
        BeforeEach {
            # Mock Test-Path in modo che restituisca $true SOLO per il percorso alias
            $script:AliasPath = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
            Mock Test-Path {
                param([Parameter(ValueFromPipeline)]$Path)
                $Path -eq $script:AliasPath
            }
        }

        It 'Deve restituire il percorso alias' {
            $result = Get-WingetExecutable
            $result | Should -Be $script:AliasPath
        }

        It 'Non deve cercare in WindowsApps quando l alias e disponibile' {
            Mock Get-ChildItem { }   # non deve essere chiamata
            $null = Get-WingetExecutable
            Should -Invoke Get-ChildItem -Times 0
        }
    }

    Context 'Quando nessun percorso risolto esiste (fallback)' {
        BeforeEach {
            Mock Test-Path { $false }
            Mock Get-ChildItem { $null }
        }

        It 'Deve restituire la stringa "winget" come fallback' {
            $result = Get-WingetExecutable
            $result | Should -Be 'winget'
        }
    }

    Context 'Comportamento reale sul runner (senza mock)' {

        It 'Restituisce il percorso alias se esiste sul runner' {
            $aliasPath = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
            if (Test-Path $aliasPath) {
                Get-WingetExecutable | Should -Be $aliasPath
            } else {
                Set-ItResult -Skipped -Because 'Alias winget non presente su questo runner'
            }
        }

        It 'Restituisce "winget" se nessun percorso risolto esiste sul runner' {
            $aliasPath = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
            $hasDirs   = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" `
                -Filter 'Microsoft.DesktopAppInstaller_*' -ErrorAction SilentlyContinue |
                Where-Object { Test-Path (Join-Path $_.FullName 'winget.exe') }
            if (-not (Test-Path $aliasPath) -and -not $hasDirs) {
                Get-WingetExecutable | Should -Be 'winget'
            } else {
                Set-ItResult -Skipped -Because 'Winget risolvibile — fallback non raggiungibile'
            }
        }
    }
}

# =============================================================================
# Write-ToolkitLog — scrittura, formattazione, Mutex e concorrenza
# =============================================================================
Describe 'Write-ToolkitLog' {

    Context 'Quando CurrentLogFile e nullo (no-op)' {

        BeforeEach { $Global:CurrentLogFile = $null }

        It 'Non deve lanciare eccezione' {
            { Write-ToolkitLog -Level 'INFO' -Message 'No-op test' } | Should -Not -Throw
        }
    }

    Context 'Scrittura corretta su file' {

        BeforeEach {
            $script:tmpLog         = [System.IO.Path]::GetTempFileName()
            $Global:CurrentLogFile = $script:tmpLog
        }
        AfterEach {
            $Global:CurrentLogFile = $null
            Remove-Item $script:tmpLog -ErrorAction SilentlyContinue
        }

        It 'Deve scrivere livello e messaggio nel formato atteso' {
            Write-ToolkitLog -Level 'INFO' -Message 'PesterLogEntry'
            $content = Get-Content -Path $script:tmpLog -Raw
            $content | Should -Match '\[INFO\]'
            $content | Should -Match 'PesterLogEntry'
        }

        It 'La riga deve contenere un timestamp nel formato [HH:mm:ss]' {
            Write-ToolkitLog -Level 'INFO' -Message 'TimestampTest'
            (Get-Content -Path $script:tmpLog -Raw) | Should -Match '\[\d{2}:\d{2}:\d{2}\]'
        }

        It 'Deve rimuovere i codici ANSI escape dal messaggio' {
            Write-ToolkitLog -Level 'INFO' -Message "`e[32mColoredText`e[0m"
            $content = Get-Content -Path $script:tmpLog -Raw
            $content | Should -Match 'ColoredText'
            $content | Should -Not -Match '\x1B'
        }

        It 'Deve appendere il contesto come JSON quando fornito' {
            Write-ToolkitLog -Level 'DEBUG' -Message 'ContextTest' -Context @{ Tool = 'Pester'; Step = 'Unit' }
            $content = Get-Content -Path $script:tmpLog -Raw
            $content | Should -Match 'Context:'
            $content | Should -Match '"Tool"'
        }

        It 'Deve supportare tutti i livelli validi senza errori' {
            foreach ($level in @('DEBUG', 'INFO', 'WARNING', 'ERROR', 'SUCCESS')) {
                { Write-ToolkitLog -Level $level -Message "Level-$level" } | Should -Not -Throw
            }
            $content = Get-Content -Path $script:tmpLog -Raw
            foreach ($level in @('DEBUG', 'WARNING', 'SUCCESS')) {
                $content | Should -Match "\[$level\]"
            }
        }
    }

    Context 'Protezione Mutex — scritture concorrenti' {

        It 'Deve preservare tutte le entry sotto scrittura concorrente (5 runspace x 10 entry = 50)' {
            $tmpLog = [System.IO.Path]::GetTempFileName()

            # Estraiamo le definizioni delle funzioni necessarie per evitare di ricaricare tutto il template
            $writeToolkitLogDef = Get-Command Write-ToolkitLog | Select-Object -ExpandProperty Definition
            $writeHostMockDef = "function Write-Host { param([Object]`$Object, [switch]`$NoNewline, [string]`$ForegroundColor) }" # Mock minimalista

            $jobs = 1..5 | ForEach-Object {
                $idx = $_
                $rs  = [powershell]::Create()
                # Passiamo solo lo stretto necessario al runspace
                $null = $rs.AddScript(@"
                    function Write-ToolkitLog { $writeToolkitLogDef }
                    $writeHostMockDef
                    `$Global:CurrentLogFile = '$($tmpLog -replace '\\', '\\\\')'
                    for (`$i = 0; `$i -lt 10; `$i++) {
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
            $lines.Count | Should -Be 50
            Remove-Item $tmpLog -ErrorAction SilentlyContinue
        }
    }
}

# =============================================================================
# Invoke-ExternalCommandWithLog — struttura ritorno, exit codes, StdOut, timeout
# =============================================================================
Describe 'Invoke-ExternalCommandWithLog' {

    BeforeAll {
        $Global:CurrentLogFile  = $null
        $Global:CurrentToolName = 'PesterTest'
    }

    It 'Deve restituire un PSCustomObject con tutte le proprieta attese' {
        $result = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'echo probe')
        $result                                  | Should -Not -BeNull
        $result.PSObject.Properties.Name         | Should -Contain 'Success'
        $result.PSObject.Properties.Name         | Should -Contain 'ExitCode'
        $result.PSObject.Properties.Name         | Should -Contain 'StdOut'
        $result.PSObject.Properties.Name         | Should -Contain 'StdErr'
        $result.PSObject.Properties.Name         | Should -Contain 'Elapsed'
        $result.PSObject.Properties.Name         | Should -Contain 'TimedOut'
    }

    It 'Deve restituire Success=true ed ExitCode=0 per exit 0' {
        $result = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'exit 0')
        $result.Success  | Should -Be $true
        $result.ExitCode | Should -Be 0
    }

    It 'Deve restituire Success=false per exit code non-zero (42)' {
        $result = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'exit 42')
        $result.Success  | Should -Be $false
        $result.ExitCode | Should -Be 42
    }

    It 'Deve catturare lo StdOut del processo' {
        $result = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'echo PesterMarker')
        $result.StdOut | Should -Match 'PesterMarker'
    }

    It 'Deve restituire TimedOut=true quando il processo supera il timeout' {
        # ping -n 10 richiede ~9 secondi; timeout fissato a 1 secondo
        $result = Invoke-ExternalCommandWithLog `
            -Command 'cmd.exe' `
            -Arguments @('/c', 'ping -n 10 127.0.0.1 > nul') `
            -TimeoutSeconds 1
        $result.TimedOut | Should -Be $true
    }

    It 'Deve restituire TimedOut=false per un comando rapido con timeout generoso' {
        $result = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'exit 0') -TimeoutSeconds 30
        $result.TimedOut | Should -Be $false
    }

    It 'Il campo Elapsed deve essere un TimeSpan valido maggiore di zero' {
        $result = Invoke-ExternalCommandWithLog -Command 'cmd.exe' -Arguments @('/c', 'exit 0')
        $result.Elapsed               | Should -BeOfType [System.TimeSpan]
        $result.Elapsed.TotalSeconds  | Should -BeGreaterThan 0
    }
}

# =============================================================================
# Read-ValidatedChoice — validazione input via RawInput (no interazione console)
# =============================================================================
Describe 'Read-ValidatedChoice' {

    BeforeEach {
        $Global:CurrentLogFile = $null
        # Mute Write-StyledMessage per evitare output console nei test
        Mock Write-StyledMessage { }
    }

    Context 'Con parametro ValidRange' {

        It 'Deve restituire la scelta valida da ValidRange' {
            Read-ValidatedChoice -ValidRange @(1, 2, 3) -RawInput '2' | Should -Be 2
        }

        It 'Deve restituire scelte multiple separate da virgola' {
            $result = Read-ValidatedChoice -ValidRange @(1, 2, 3) -RawInput '1,3'
            $result | Should -HaveCount 2
            $result | Should -Contain 1
            $result | Should -Contain 3
        }

        It 'Deve restituire scelte multiple separate da spazio' {
            $result = Read-ValidatedChoice -ValidRange @(1, 2, 3) -RawInput '2 3'
            $result | Should -HaveCount 2
            $result | Should -Contain 2
            $result | Should -Contain 3
        }

        It 'Deve accettare il valore minimo del range' {
            Read-ValidatedChoice -ValidRange @(1, 2, 3) -RawInput '1' | Should -Be 1
        }

        It 'Deve accettare il valore massimo del range' {
            Read-ValidatedChoice -ValidRange @(1, 2, 3) -RawInput '3' | Should -Be 3
        }
    }

    Context 'Con parametri Min e Max' {

        It 'Deve restituire una scelta interna ai limiti' {
            Read-ValidatedChoice -Min 1 -Max 10 -RawInput '7' | Should -Be 7
        }

        It 'Deve accettare il valore esatto di Min' {
            Read-ValidatedChoice -Min 1 -Max 5 -RawInput '1' | Should -Be 1
        }

        It 'Deve accettare il valore esatto di Max' {
            Read-ValidatedChoice -Min 1 -Max 5 -RawInput '5' | Should -Be 5
        }
    }

    Context 'Con AllowZero' {

        It 'Deve accettare 0 quando AllowZero e attivo' {
            Read-ValidatedChoice -Min 0 -Max 5 -AllowZero -RawInput '0' | Should -Be 0
        }
    }
}
