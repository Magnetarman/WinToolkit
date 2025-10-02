<#
.SYNOPSIS
    WinToolkit - Strumenti di manutenzione Windows
.DESCRIPTION
    Menu principale per strumenti di gestione e riparazione Windows
.NOTES
  Versione 2.2.2 (Build 15) - 2025-10-01
#>

param([int]$CountdownSeconds = 10)
$Host.UI.RawUI.WindowTitle = "WinToolkit by MagnetarMan"
$ErrorActionPreference = 'Stop'

# Setup logging
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logdir = "$env:localappdata\WinToolkit\logs"
try {
    [System.IO.Directory]::CreateDirectory("$logdir") | Out-Null
    Start-Transcript -Path "$logdir\WinToolkit_$dateTime.log" -Append -Force | Out-Null
}
catch { }

function Write-StyledMessage {
    param([ValidateSet('Success', 'Warning', 'Error', 'Info')][string]$type, [string]$text)
    $icons = @{ Success = '✅'; Warning = '⚠️'; Error = '❌'; Info = '💎' }
    $colors = @{ Success = 'Green'; Warning = 'Yellow'; Error = 'Red'; Info = 'Cyan' }
    Write-Host "$($icons[$type]) $text" -ForegroundColor $colors[$type]
}

function Center-Text {
    param([string]$text, [int]$width = $Host.UI.RawUI.BufferSize.Width)
    if ($text.Length -ge $width) { $text } else { ' ' * [Math]::Floor(($width - $text.Length) / 2) + $text }
}

function Show-Header {
    Clear-Host
    $width = $Host.UI.RawUI.BufferSize.Width
    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    foreach ($line in $asciiArt) {
        Write-Host (Center-Text $line $width) -ForegroundColor White
    }
    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    Write-Host ''
}

function winver {
    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem
        $computerInfo = Get-CimInstance Win32_ComputerSystem
        $diskInfo = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

        $productName = $osInfo.Caption -replace 'Microsoft ', ''
        $buildNumber = [int]$osInfo.BuildNumber
        $totalRAM = [Math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
        $totalDiskSpace = [Math]::Round($diskInfo.Size / 1GB, 0)
        $freePercentage = [Math]::Round(($diskInfo.FreeSpace / $diskInfo.Size) * 100, 0)

        # Version mapping
        $versionMap = @{
            26100 = "24H2"; 22631 = "23H2"; 22621 = "22H2"; 22000 = "21H2"
            19045 = "22H2"; 19044 = "21H2"; 19043 = "21H1"; 19042 = "20H2"
            19041 = "2004"; 18363 = "1909"; 18362 = "1903"; 17763 = "1809"
            17134 = "1803"; 16299 = "1709"; 15063 = "1703"; 14393 = "1607"
            10586 = "1511"; 10240 = "1507"
        }

        $windowsVersion = "N/A"
        foreach ($build in ($versionMap.Keys | Sort-Object -Descending)) {
            if ($buildNumber -ge $build) { $windowsVersion = $versionMap[$build]; break }
        }

        # Edition detection
        $windowsEdition = switch -Wildcard ($productName) {
            "*Home*" { "🏠 Home" }
            "*Pro*" { "💼 Professional" }
            "*Enterprise*" { "🏢 Enterprise" }
            "*Education*" { "🎓 Education" }
            "*Server*" { "🖥️ Server" }
            default { "💻 $productName" }
        }

        # Display info
        $width = 65
        Write-Host ""
        Write-Host ('*' * $width) -ForegroundColor Red
        Write-Host (Center-Text "🖥️  INFORMAZIONI SISTEMA  🖥️" $width) -ForegroundColor White
        Write-Host ('*' * $width) -ForegroundColor Red
        Write-Host ""

        $info = @(
            @("💻 Edizione:", $windowsEdition, 'White'),
            @("📊 Versione:", "Ver. $windowsVersion (Build $buildNumber)", 'Green'),
            @("🏗️ Architettura:", $osInfo.OSArchitecture, 'White'),
            @("🏷️ Nome PC:", $computerInfo.Name, 'White'),
            @("🧠 RAM:", "$totalRAM GB", 'White'),
            @("💾 Disco:", "$freePercentage% Libero ($totalDiskSpace GB)", 'Green')
        )

        foreach ($item in $info) {
            Write-Host "  $($item[0])" -ForegroundColor Yellow -NoNewline
            Write-Host " $($item[1])" -ForegroundColor $item[2]
        }

        Write-Host ""
        Write-Host ('*' * $width) -ForegroundColor Red
    }
    catch {
        Write-StyledMessage -type 'Error' -text "Errore nel recupero informazioni: $($_.Exception.Message)"
    }
}

# ASCII Art
$asciiArt = @(
    '      __        __  _  _   _ ',
    '      \ \      / / | || \ | |',
    '       \ \ /\ / /  | ||  \| |',
    '        \ V  V /   | || |\  |',
    '         \_/\_/    |_||_| \_|',
    '',
    '       WinToolkit By MagnetarMan',
    '       Version 2.2.2 (Build 15)'
)

# Placeholder functions (verranno automaticamente popolate dal compilatore)
function WinInstallPSProfile {
    <#
    .SYNOPSIS
        Script per installare il profilo PowerShell di ChrisTitusTech.
    .DESCRIPTION
        Questo script scarica e installa il profilo PowerShell personalizzato di ChrisTitusTech, che include configurazioni per oh-my-posh, font, e altre utilità.
        Lo script verifica se è in esecuzione con privilegi di amministratore e, in caso contrario, si rilancia con i permessi necessari.
        Inoltre, controlla se PowerShell Core è installato e se la versione di PowerShell è 7 o superiore.
        Se il profilo esistente è diverso dalla versione più recente disponibile online, lo aggiorna e crea un backup del profilo precedente.
        Al termine dell'installazione, offre la possibilità di riavviare il sistema per applicare tutte le modifiche.
    #>
    $Host.UI.RawUI.WindowTitle = "InstallPSProfile by MagnetarMan"
    Clear-Host
    $width = 65
    Write-Host ('═' * $width) -ForegroundColor Green

    $asciiArt = @(
        '      __        __  _  _   _ ',
        '      \ \      / / | || \ | |',
        '       \ \ /\ / /  | ||  \| |',
        '        \ V  V /   | || |\  |',
        '         \_/\_/    |_||_| \_|',
        '',
        '   Install PSProfile By MagnetarMan',
        '        Version 2.2 (Build 2)'
    )

    foreach ($line in $asciiArt) {
        Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
    }

    Write-Host ('═' * $width) -ForegroundColor Green
    Write-Host ''

    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-StyledMessage 'Warning' "L'installazione del profilo PowerShell richiede privilegi di amministratore."
        Write-StyledMessage 'Info' "Riavvio come amministratore..."

        try {
            $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { WinInstallPSProfile }`""
            Start-Process PowerShell -Verb RunAs -ArgumentList $arguments
            return
        }
        catch {
            Write-StyledMessage 'Error' "Impossibile elevare i privilegi: $($_.Exception.Message)"
            Write-StyledMessage 'Error' "Esegui PowerShell come amministratore e riprova."
            return
        }
    }
    
    Write-StyledMessage 'Info' "Installazione del profilo PowerShell in corso..."

    try {
        if (-not (Get-Command "pwsh" -ErrorAction SilentlyContinue)) {
            Write-StyledMessage 'Error' "Questo profilo richiede PowerShell Core, che non è attualmente installato!"
            return
        }

        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-StyledMessage 'Warning' "Questo profilo richiede PowerShell 7 o superiore."
            $choice = Read-Host "Vuoi procedere comunque con l'installazione per PowerShell 7? (S/N)"
            if ($choice -notmatch '^[SsYy]') {
                Write-StyledMessage 'Info' "Installazione annullata dall'utente."
                return
            }
        }
        
        $profileUrl = "https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
        $oldHash = $null
        if (Test-Path $PROFILE) {
            $oldHash = Get-FileHash $PROFILE -ErrorAction SilentlyContinue
        }

        Write-StyledMessage 'Info' "Controllo aggiornamenti profilo..."
        $tempProfile = "$env:TEMP\Microsoft.PowerShell_profile.ps1"
        Invoke-RestMethod $profileUrl -OutFile $tempProfile -UseBasicParsing
        $newHash = Get-FileHash $tempProfile

        $profileDir = Split-Path $PROFILE -Parent
        if (!(Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }

        if (!(Test-Path "$PROFILE.hash")) {
            $newHash.Hash | Out-File "$PROFILE.hash"
        }
        
        if ($newHash.Hash -ne $oldHash.Hash) {
            if ((Test-Path $PROFILE) -and (-not (Test-Path "$PROFILE.bak"))) {
                Write-StyledMessage 'Info' "Backup del profilo esistente..."
                Copy-Item -Path $PROFILE -Destination "$PROFILE.bak" -Force
                Write-StyledMessage 'Success' "Backup completato."
            }

            Write-StyledMessage 'Info' "Installazione profilo e dipendenze (oh-my-posh, font, ecc.)..."
            Start-Process -FilePath "pwsh" `
                -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"Invoke-Expression (Invoke-WebRequest 'https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1')`"" `
                -Wait

            Write-StyledMessage 'Success' "Profilo PowerShell installato correttamente!"
            Write-StyledMessage 'Warning' "Riavvia PowerShell per applicare il nuovo profilo."
            Write-StyledMessage 'Info' "Per vedere tutte le modifiche (font, oh-my-posh, ecc.) è consigliato riavviare il sistema."

            Write-Host ""
            $restart = Read-Host "Vuoi riavviare il sistema ora per applicare tutte le modifiche? (Y/N)"

            if ($restart -match '^[YySs]') {
                Write-StyledMessage 'Warning' "Riavvio del sistema in corso..."
                for ($i = 5; $i -gt 0; $i--) {
                    Write-Host "Riavvio tra $i secondi..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                }

                Write-StyledMessage 'Info' "Riavvio del sistema..."
                Restart-Computer -Force
            }
            else {
                Write-StyledMessage 'Info' "Riavvio annullato. Ricorda di riavviare il sistema per vedere tutte le modifiche."
            }
        }
        else {
            Write-StyledMessage 'Info' "Il profilo è già aggiornato alla versione più recente."
        }
        
        Remove-Item $tempProfile -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-StyledMessage 'Error' "Errore durante l'installazione del profilo: $($_.Exception.Message)"
        if (Test-Path "$env:TEMP\Microsoft.PowerShell_profile.ps1") {
            Remove-Item "$env:TEMP\Microsoft.PowerShell_profile.ps1" -Force -ErrorAction SilentlyContinue
        }
    }

}
function WinRepairToolkit {
    <#
    .SYNOPSIS
        Script per la riparazione del sistema Windows con strumenti integrati.
    
    .DESCRIPTION
        Questo script esegue una serie di strumenti di riparazione di Windows (chkdsk, SFC, DISM) in sequenza,
        con monitoraggio del progresso, gestione degli errori e tentativi di riparazione multipli.
        Al termine, offre un'opzione per una riparazione profonda del disco che richiede un riavvio.
        Infine, gestisce il riavvio del sistema con un conto alla rovescia interattivo.
    #>

    param([int]$MaxRetryAttempts = 3, [int]$CountdownSeconds = 30)

    $Host.UI.RawUI.WindowTitle = "Repair Toolkit By MagnetarMan"
    $script:Log = @(); $script:CurrentAttempt = 0
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }
    $RepairTools = @(
        @{ Tool = 'chkdsk'; Args = @('/scan', '/perf'); Name = 'Controllo disco'; Icon = '💽' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (1)'; Icon = '🗂️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/RestoreHealth'); Name = 'Ripristino immagine Windows'; Icon = '🛠️' }
        @{ Tool = 'DISM'; Args = @('/Online', '/Cleanup-Image', '/StartComponentCleanup', '/ResetBase'); Name = 'Pulizia Residui Aggiornamenti'; Icon = '🕸️' }
        @{ Tool = 'sfc'; Args = @('/scannow'); Name = 'Controllo file di sistema (2)'; Icon = '🗂️' }
    )

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon, [string]$Spinner = '', [string]$Color = 'Green') {
        $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
        $filled = '█' * [math]::Floor($safePercent * 30 / 100)
        $empty = '▒' * (30 - $filled.Length)
        $bar = "[$filled$empty] {0,3}%" -f $safePercent
        Write-Host "`r$Spinner $Icon $Activity $bar $Status" -NoNewline -ForegroundColor $Color
        if ($Percent -eq 100) { Write-Host '' }
    }

    function Start-InterruptibleCountdown([int]$Seconds, [string]$Message) {
        Write-StyledMessage Info '💡 Premi un tasto qualsiasi per annullare...'
        Write-Host ''

        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning '⏸️ Riavvio automatico annullato'
                Write-StyledMessage Info "🔄 Puoi riavviare manualmente: 'shutdown /r /t 0' o dal menu Start."
                return $false
            }

            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"

            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Warning '⏰ Tempo scaduto: il sistema verrà riavviato ora.'
        Start-Sleep 1
        return $true
    }

    function Invoke-RepairCommand([hashtable]$Config, [int]$Step, [int]$Total) {
        Write-StyledMessage Info "[$Step/$Total] Avvio $($Config.Name)..."
        $percent = 0; $spinnerIndex = 0; $isChkdsk = ($Config.Tool -ieq 'chkdsk')
        $outFile = [System.IO.Path]::GetTempFileName()
        $errFile = [System.IO.Path]::GetTempFileName()

        try {
            $proc = if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r')) {
                $drive = ($Config.Args | Where-Object { $_ -match '^[A-Za-z]:$' } | Select-Object -First 1) ?? $env:SystemDrive
                $filteredArgs = $Config.Args | Where-Object { $_ -notmatch '^[A-Za-z]:$' }
                Start-Process 'cmd.exe' @('/c', "echo Y| chkdsk $drive $($filteredArgs -join ' ')") -RedirectStandardOutput $outFile -RedirectStandardError $errFile -NoNewWindow -PassThru
            }
            else {
                Start-Process $Config.Tool $Config.Args -RedirectStandardOutput $outFile -RedirectStandardError $errFile -NoNewWindow -PassThru
            }

            while (-not $proc.HasExited) {
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                if ($isChkdsk) {
                    Show-ProgressBar $Config.Name 'Esecuzione in corso ...' 0 $Config.Icon $spinner 'Yellow'
                }
                else {
                    if ($percent -lt 95) { $percent += Get-Random -Minimum 1 -Maximum 3 }
                    Show-ProgressBar $Config.Name 'Esecuzione in corso...' $percent $Config.Icon $spinner
                }
                Start-Sleep -Milliseconds 600
                $proc.Refresh()
            }

            $results = @()
            @($outFile, $errFile) | Where-Object { Test-Path $_ } | ForEach-Object {
                $results += Get-Content $_ -ErrorAction SilentlyContinue
            }

            if ($isChkdsk -and ($Config.Args -contains '/f' -or $Config.Args -contains '/r') -and
                ($results -join ' ').ToLower() -match 'schedule|next time.*restart|volume.*in use') {
                Write-StyledMessage Info "🔧 $($Config.Name): controllo schedulato al prossimo riavvio"
                $script:Log += "[$($Config.Name)] ℹ️ Controllo disco schedulato al prossimo riavvio"
                return @{ Success = $true; ErrorCount = 0 }
            }

            Show-ProgressBar $Config.Name 'Completato con successo' 100 $Config.Icon
            Write-Host ''

            $exitCode = $proc.ExitCode
            $hasDismSuccess = ($Config.Tool -ieq 'DISM') -and ($results -match '(?i)completed successfully')
            $isSuccess = ($exitCode -eq 0) -or $hasDismSuccess

            $errors = $warnings = @()
            if (-not $isSuccess) {
                foreach ($line in ($results | Where-Object { $_ -and ![string]::IsNullOrWhiteSpace($_.Trim()) })) {
                    $trim = $line.Trim()
                    if ($trim -match '^\[=+\s*\d+' -or $trim -match '(?i)version:|deployment image') { continue }

                    if ($trim -match '(?i)(errore|error|failed|impossibile|corrotto|corruption)') { $errors += $trim }
                    elseif ($trim -match '(?i)(warning|avviso|attenzione)') { $warnings += $trim }
                }
            }

            $success = ($errors.Count -eq 0) -or $hasDismSuccess
            $message = "$($Config.Name) completato " + $(if ($success) { 'con successo' } else { "con $($errors.Count) errori" })
            Write-StyledMessage $(if ($success) { 'Success' } else { 'Warning' }) $message

            $logStatus = if ($success) { '✅ Successo' } else { "⚠️ $($errors.Count) errori" }
            if ($warnings.Count -gt 0) { $logStatus += " - $($warnings.Count) avvisi" }
            $script:Log += "[$($Config.Name)] $logStatus"

            return @{ Success = $success; ErrorCount = $errors.Count }

        }
        catch {
            Write-StyledMessage Error "Errore durante $($Config.Name): $_"
            $script:Log += "[$($Config.Name)] ❌ Errore fatale: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
        finally {
            Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
        }
    }

    function Start-RepairCycle([int]$Attempt = 1) {
        $script:CurrentAttempt = $Attempt
        Write-StyledMessage Info "🔄 Tentativo $Attempt/$MaxRetryAttempts - Riparazione sistema ($($RepairTools.Count) strumenti)..."
        Write-Host ''

        $totalErrors = $successCount = 0
        for ($i = 0; $i -lt $RepairTools.Count; $i++) {
            $result = Invoke-RepairCommand $RepairTools[$i] ($i + 1) $RepairTools.Count
            if ($result.Success) { $successCount++ }
            $totalErrors += $result.ErrorCount
            Start-Sleep 1
        }

        Write-StyledMessage Info "🎯 Completati $successCount/$($RepairTools.Count) strumenti (Errori: $totalErrors)."

        if ($totalErrors -gt 0 -and $Attempt -lt $MaxRetryAttempts) {
            Write-Host ''
            Write-StyledMessage Warning "🔄 $totalErrors errori rilevati. Nuovo tentativo..."
            Start-Sleep 3
            Write-Host ''
            return Start-RepairCycle ($Attempt + 1)
        }

        return @{ Success = ($totalErrors -eq 0); TotalErrors = $totalErrors; AttemptsUsed = $Attempt }
    }

    function Start-DeepDiskRepair {
        Write-StyledMessage Warning '🔧 Vuoi eseguire una riparazione profonda del disco C:?'
        Write-StyledMessage Info 'Questa operazione richiederà un riavvio e può richiedere diverse ore.'

        $response = Read-Host 'Procedere con la riparazione profonda? (s/n)'
        if ($response.ToLower() -ne 's') { return $false }

        Write-StyledMessage Warning 'Segno il volume C: come "dirty" (chkdsk al prossimo riavvio) e apro una cmd per output.'
        $script:Log += "[Controllo disco Esteso] ℹ️ Segno volume dirty e apro cmd"

        try {
            Start-Process 'fsutil.exe' @('dirty', 'set', 'C:') -NoNewWindow -Wait
            Start-Process 'cmd.exe' @('/c', 'echo Y | chkdsk C: /f /r /v /x /b') -WindowStyle Hidden -Wait
            Write-StyledMessage Info 'Comando chkdsk inviato (finestra nascosta). Riavvia il sistema per eseguire la scansione profonda.'
            $script:Log += "[Controllo disco Esteso] ✅ chkdsk eseguito in background; riavviare per applicare"
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore eseguendo operazione: $_"
            $script:Log += "[Controllo disco Esteso] ❌ Errore: $_"
            return $false
        }
    }

    function Start-SystemRestart([hashtable]$RepairResult) {
        if ($RepairResult.Success) {
            Write-StyledMessage Info '🎉 Riparazione completata con successo!'
            Write-StyledMessage Info "🎯 Errori risolti in $($RepairResult.AttemptsUsed) tentativo/i."
        }
        else {
            Write-StyledMessage Warning "⚠️ $($RepairResult.TotalErrors) errori persistenti dopo $($RepairResult.AttemptsUsed) tentativo/i."
            Write-StyledMessage Info '📋 Controlla il log sul Desktop. 💡 Il riavvio potrebbe risolvere problemi residui.'
        }

        Write-StyledMessage Info '🔄 Il sistema verrà riavviato per finalizzare le modifiche'

        if (Start-InterruptibleCountdown $CountdownSeconds 'Riavvio automatico') {
            try {
                Write-StyledMessage Info '🔄 Riavvio in corso...'
                Restart-Computer -Force
            }
            catch {
                Write-StyledMessage Error "❌ Errore riavvio: $_"
                Write-StyledMessage Info '🔄 Riavviare manualmente il sistema.'
            }
        }
        else {
            Write-StyledMessage Info '✅ Script completato. Sistema non riavviato.'
            Write-StyledMessage Info '💡 Riavvia quando possibile per applicare le riparazioni.'
        }
    }

    function Center-Text {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Text,
            [Parameter(Mandatory = $false)]
            [int]$Width = $Host.UI.RawUI.BufferSize.Width
        )
    
        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
    
        return (' ' * $padding + $Text)
    }
    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            '    Repair Toolkit By MagnetarMan',
            '       Version 2.2 (Build 5)'
        )

        foreach ($line in $asciiArt) {
            if (-not [string]::IsNullOrEmpty($line)) {
                Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    Show-Header

    for ($i = 5; $i -gt 0; $i--) {
        $spinner = $spinners[$i % $spinners.Length]
        Write-Host "`r$spinner ⏳ Preparazione sistema - $i secondi..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"

    try {
        $repairResult = Start-RepairCycle
        $deepRepairScheduled = Start-DeepDiskRepair

        if ($deepRepairScheduled) {
            Write-StyledMessage Warning 'Il sistema verrà riavviato per eseguire la riparazione profonda...'
        }
        Start-SystemRestart $repairResult

    }
    catch {
        Write-StyledMessage Error "❌ Errore critico: $($_.Exception.Message)"
    }
    finally {
        Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
        Read-Host
    }

}
function SetRustDesk {
    <#
    .SYNOPSIS
        Configura ed installa RustDesk con configurazioni personalizzata su Windows.

    .DESCRIPTION
        Script ottimizzato per fermare servizi, reinstallare RustDesk e applicare configurazioni personalizzate.
        Scarica i file di configurazione da repository GitHub e riavvia il sistema per applicare le modifiche.
    #>

    param([int]$CountdownSeconds = 30)

    # Inizializzazione
    $Host.UI.RawUI.WindowTitle = "RustDesk Setup Toolkit By MagnetarMan"

    # Configurazione globale
    $MsgStyles = @{
        Success  = @{ Color = 'Green'; Icon = '✅' }
        Warning  = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error    = @{ Color = 'Red'; Icon = '❌' }
        Info     = @{ Color = 'Cyan'; Icon = '💎' }
        Progress = @{ Color = 'Magenta'; Icon = '🔄' }
    }

    # Funzione per centrare il testo
    function Center-Text {
        param(
            [Parameter(Mandatory = $true)][string]$Text,
            [Parameter(Mandatory = $false)][int]$Width = $Host.UI.RawUI.BufferSize.Width
        )
        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding + $Text)
    }
    
    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            'RustDesk Setup Toolkit By MagnetarMan',
            '       Version 2.2 (Build 11)'
        )

        foreach ($line in $asciiArt) {
            if ($line -ne '') {
                Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
            }
            else {
                Write-Host ''
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }

    function Stop-RustDeskComponents {
        $servicesFound = $false
        foreach ($service in @("RustDesk", "rustdesk")) {
            $serviceObj = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($serviceObj) {
                Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
                Write-StyledMessage Success "Servizio $service arrestato"
                $servicesFound = $true
            }
        }
        if (-not $servicesFound) {
            Write-StyledMessage Warning "Nessun servizio RustDesk trovato - Proseguo con l'installazione"
        }

        $processesFound = $false
        foreach ($process in @("rustdesk", "RustDesk")) {
            $runningProcesses = Get-Process -Name $process -ErrorAction SilentlyContinue
            if ($runningProcesses) {
                $runningProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
                Write-StyledMessage Success "Processi $process terminati"
                $processesFound = $true
            }
        }
        if (-not $processesFound) {
            Write-StyledMessage Warning "Nessun processo RustDesk trovato"
        }
        Start-Sleep 2
    }

    function Get-LatestRustDeskRelease {
        $apiUrl = "https://api.github.com/repos/rustdesk/rustdesk/releases/latest"
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get
        $msiAsset = $response.assets | Where-Object { $_.name -like "rustdesk-*-x86_64.msi" } | Select-Object -First 1

        if ($msiAsset) {
            return @{
                Version     = $response.tag_name
                DownloadUrl = $msiAsset.browser_download_url
                FileName    = $msiAsset.name
            }
        }

        Write-StyledMessage Error "Nessun installer .msi trovato nella release"
        return $null
    }

    function Download-RustDeskInstaller {
        param([string]$DownloadPath)

        Write-StyledMessage Progress "Download installer RustDesk in corso..."
        $releaseInfo = Get-LatestRustDeskRelease
        if (-not $releaseInfo) { return $false }

        Write-StyledMessage Info "📥 Versione rilevata: $($releaseInfo.Version)"
        $parentDir = Split-Path $DownloadPath -Parent
        $null = New-Item -ItemType Directory -Path $parentDir -Force
        Remove-Item $DownloadPath -Force -ErrorAction SilentlyContinue

        Invoke-WebRequest -Uri $releaseInfo.DownloadUrl -OutFile $DownloadPath -UseBasicParsing
        if (Test-Path $DownloadPath) {
            Write-StyledMessage Success "Installer $($releaseInfo.FileName) scaricato con successo"
            return $true
        }

        Write-StyledMessage Error "Errore nel download dell'installer"
        return $false
    }

    function Install-RustDesk {
        param([string]$InstallerPath, [string]$ServerIP)

        Write-StyledMessage Progress "Installazione RustDesk"
        $installArgs = "/i", "`"$InstallerPath`"", "/quiet", "/norestart"
        $process = Start-Process "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru -WindowStyle Hidden
        Start-Sleep 10

        if ($process.ExitCode -eq 0) {
            Write-StyledMessage Success "RustDesk installato"
            return $true
        }

        Write-StyledMessage Error "Errore installazione (Exit Code: $($process.ExitCode))"
        return $false
    }

    function Clear-RustDeskConfig {
        Write-StyledMessage Progress "Pulizia configurazioni esistenti..."
        $configDir = "$env:APPDATA\RustDesk\config"

        if (Test-Path $configDir) {
            Remove-Item $configDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-StyledMessage Success "Cartella config eliminata"
            Start-Sleep 1
        }
        else {
            Write-StyledMessage Warning "Cartella config non trovata - Potrebbe essere la prima installazione"
        }
    }

    function Download-RustDeskConfigFiles {
        Write-StyledMessage Progress "Download file di configurazione..."
        $configDir = "$env:APPDATA\RustDesk\config"
        $null = New-Item -ItemType Directory -Path $configDir -Force

        $configFiles = @(
            "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/RustDesk.toml",
            "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/RustDesk_local.toml",
            "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/RustDesk2.toml"
        )

        foreach ($url in $configFiles) {
            $fileName = Split-Path $url -Leaf
            $filePath = Join-Path $configDir $fileName
            try {
                Invoke-WebRequest -Uri $url -OutFile $filePath -UseBasicParsing
                Write-StyledMessage Success "$fileName scaricato"
            }
            catch {
                Write-StyledMessage Error "Errore download $fileName`: $($_.Exception.Message)"
            }
        }
    }

    function Start-CountdownRestart([string]$Reason) {
        Write-StyledMessage Info "🔄 $Reason - Il sistema verrà riavviato"
        Write-StyledMessage Info "💡 Premi un tasto qualsiasi per annullare..."

        for ($i = $CountdownSeconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                $null = [Console]::ReadKey($true)
                Write-Host "`n"
                Write-StyledMessage Warning "⏸️ Riavvio annullato dall'utente"
                return $false
            }

            $percent = [Math]::Round((($CountdownSeconds - $i) / $CountdownSeconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"
            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Warning "⏰ Riavvio del sistema..."
        Restart-Computer -Force
        return $true
    }

    # === ESECUZIONE PRINCIPALE ===
    Show-Header
    Write-StyledMessage Info "🚀 AVVIO CONFIGURAZIONE RUSTDESK"

    try {
        $installerPath = "$env:LOCALAPPDATA\WinToolkit\rustdesk\rustdesk-installer.msi"

        # FASE 1: Stop servizi e processi
        Write-StyledMessage Info "📋 FASE 1: Arresto servizi e processi RustDesk"
        Stop-RustDeskComponents

        # FASE 2: Download e installazione
        Write-StyledMessage Info "📋 FASE 2: Download e installazione"
        if (-not (Download-RustDeskInstaller -DownloadPath $installerPath)) {
            Write-StyledMessage Error "Impossibile procedere senza l'installer"
            return
        }
        if (-not (Install-RustDesk -InstallerPath $installerPath -ServerIP $null)) {
            Write-StyledMessage Error "Errore durante l'installazione"
            return
        }

        # FASE 3: Verifica processi e pulizia
        Write-StyledMessage Info "📋 FASE 3: Verifica processi e pulizia"
        Stop-RustDeskComponents

        # FASE 4: Pulizia configurazioni
        Write-StyledMessage Info "📋 FASE 4: Pulizia configurazioni"
        Clear-RustDeskConfig

        # FASE 5: Download configurazioni
        Write-StyledMessage Info "📋 FASE 5: Download configurazioni"
        Download-RustDeskConfigFiles

        Write-Host ""
        Write-StyledMessage Success "🎉 CONFIGURAZIONE RUSTDESK COMPLETATA"
        Write-StyledMessage Info "🔄 Per applicare le modifiche il PC verrà riavviato"
        Start-CountdownRestart -Reason "Per applicare le modifiche è necessario riavviare il sistema"
    }
    catch {
        Write-StyledMessage Error "ERRORE: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Verifica connessione Internet e riprova"
    }

}
function WinUpdateReset {
    <#
    .SYNOPSIS
        Script ottimizzato per reinstallare Winget, Microsoft Store e UniGet UI.
    
    .DESCRIPTION
        Questo script PowerShell è progettato per riparare i problemi comuni di Windows Update, 
        inclusa la reinstallazione di componenti critici come SoftwareDistribution e catroot2. 
        Utilizza un'interfaccia utente migliorata con barre di progresso, messaggi stilizzati e 
        un conto alla rovescia per il riavvio del sistema che può essere interrotto premendo un tasto.
    #>
    param([int]$CountdownSeconds = 15)

    $Host.UI.RawUI.WindowTitle = "Update Reset Toolkit By MagnetarMan"
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon, [string]$Spinner = '', [string]$Color = 'Green') {
        $barLength = 30
        $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
        $filled = '█' * [math]::Floor($safePercent * $barLength / 100)
        $empty = '░' * ($barLength - $filled.Length)
        $bar = "[$filled$empty] {0,3}%" -f $safePercent
        
        $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
        Write-Host $clearLine -NoNewline
        Write-Host "$Spinner $Icon $Activity $bar $Status" -NoNewline -ForegroundColor $Color
        
        if ($Percent -eq 100) { 
            Write-Host ''
            [Console]::Out.Flush()
        }
    }

    function Start-InterruptibleCountdown([int]$Seconds, [string]$Message) {
        Write-StyledMessage Info '💡 Premi qualsiasi tasto per annullare il riavvio automatico...'
        Write-Host ''
        
        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Error '⏸️ Riavvio automatico annullato'
                Write-StyledMessage Info "🔄 Puoi riavviare manualmente con: shutdown /r /t 0"
                return $false
            }
            
            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('░' * $remaining)] $percent%"
            
            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }
        Write-Host "`n"
        Write-StyledMessage Warning '⏰ Tempo scaduto: il sistema verrà riavviato ora.'
        Start-Sleep 1
        return $true
    }

    function Center-Text([string]$text, [int]$width) {
        $padding = [math]::Max(0, [math]::Floor(($width - $text.Length) / 2))
        return (' ' * $padding) + $text
    }

    function Show-ServiceProgress([string]$ServiceName, [string]$Action, [int]$Current, [int]$Total) {
        $percent = [math]::Round(($Current / $Total) * 100)
        $spinnerIndex = ($Current % $spinners.Length)
        $spinner = $spinners[$spinnerIndex]
        Show-ProgressBar "Servizi ($Current/$Total)" "$Action $ServiceName" $percent '⚙️' $spinner 'Cyan'
        Start-Sleep -Milliseconds 200
    }

    function Manage-Service($serviceName, $action, $config, $currentStep, $totalSteps) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
            
            if (-not $service) { 
                Write-StyledMessage Warning "$serviceIcon Servizio $serviceName non trovato nel sistema."
                return
            }

            switch ($action) {
                'Stop' { 
                    Show-ServiceProgress $serviceName "Arresto" $currentStep $totalSteps
                    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                    
                    $timeout = 10
                    do {
                        Start-Sleep -Milliseconds 500
                        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                        $timeout--
                    } while ($service.Status -eq 'Running' -and $timeout -gt 0)
                    
                    Write-Host ''
                    Write-StyledMessage Info "$serviceIcon Servizio $serviceName arrestato."
                }
                'Configure' {
                    Show-ServiceProgress $serviceName "Configurazione" $currentStep $totalSteps
                    Set-Service -Name $serviceName -StartupType $config.Type -ErrorAction Stop
                    Write-Host ''
                    Write-StyledMessage Success "$serviceIcon Servizio $serviceName configurato come $($config.Type)."
                }
                'Start' {
                    Show-ServiceProgress $serviceName "Avvio" $currentStep $totalSteps
                    Write-Host ''
                    Start-Service -Name $serviceName -ErrorAction Stop
                    
                    $timeout = 10; $spinnerIndex = 0
                    do {
                        $clearLine = "`r" + (' ' * 80) + "`r"
                        Write-Host $clearLine -NoNewline
                        Write-Host "$($spinners[$spinnerIndex % $spinners.Length]) 🔄 Attesa avvio $serviceName..." -NoNewline -ForegroundColor Yellow
                        Start-Sleep -Milliseconds 300
                        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                        $timeout--; $spinnerIndex++
                    } while ($service.Status -ne 'Running' -and $timeout -gt 0)
                    
                    $clearLine = "`r" + (' ' * 80) + "`r"
                    Write-Host $clearLine -NoNewline
                    
                    if ($service.Status -eq 'Running') {
                        Write-StyledMessage Success "$serviceIcon Servizio ${serviceName}: avviato correttamente."
                    }
                    else {
                        Write-StyledMessage Warning "$serviceIcon Servizio ${serviceName}: avvio in corso..."
                    }
                }
                'Check' {
                    $status = if ($service.Status -eq 'Running') { '🟢 Attivo' } else { '🔴 Inattivo' }
                    $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
                    Write-StyledMessage Info "$serviceIcon $serviceName - Stato: $status"
                }
            }
        }
        catch {
            Write-Host ''
            $actionText = switch ($action) { 'Configure' { 'configurare' } 'Start' { 'avviare' } 'Check' { 'verificare' } default { $action.ToLower() } }
            $serviceIcon = if ($config) { $config.Icon } else { '⚙️' }
            Write-StyledMessage Warning "$serviceIcon Impossibile $actionText $serviceName - $($_.Exception.Message)"
        }
    }

    function Remove-DirectorySafely([string]$path, [string]$displayName) {
        if (-not (Test-Path $path)) {
            Write-StyledMessage Info "💭 Directory $displayName non presente."
            return $true
        }

        $originalPos = [Console]::CursorTop
        try {
            # Soppressione completa dell'output con redirezione a $null
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'
            
            # Eliminazione con output completamente soppresso
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue *>$null
            
            # Reset completo del cursore alla posizione originale
            [Console]::SetCursorPosition(0, $originalPos)
            $clearLines = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLines -NoNewline
            [Console]::Out.Flush()
            
            Write-StyledMessage Success "🗑️ Directory $displayName eliminata."
            return $true
        }
        catch {
            # Reset cursore in caso di errore
            [Console]::SetCursorPosition(0, $originalPos)
            $clearLines = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLines -NoNewline
            
            Write-StyledMessage Warning "Tentativo fallito, provo con eliminazione forzata..."
        
            try {
                # Metodo alternativo con robocopy per eliminazione forzata
                $tempDir = [System.IO.Path]::GetTempPath() + "empty_" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
                $null = New-Item -ItemType Directory -Path $tempDir -Force
                
                # Usa robocopy per svuotare e poi elimina
                $null = Start-Process "robocopy.exe" -ArgumentList "`"$tempDir`" `"$path`" /MIR /NFL /NDL /NJH /NJS /NP /NC" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                Remove-Item $tempDir -Force -ErrorAction SilentlyContinue
                Remove-Item $path -Force -ErrorAction SilentlyContinue
                
                # Reset cursore finale
                [Console]::SetCursorPosition(0, $originalPos)
                $clearLines = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                Write-Host $clearLines -NoNewline
                [Console]::Out.Flush()
                
                if (-not (Test-Path $path)) {
                    Write-StyledMessage Success "🗑️ Directory $displayName eliminata (metodo forzato)."
                    return $true
                }
                else {
                    Write-StyledMessage Warning "Directory $displayName parzialmente eliminata."
                    return $false
                }
            }
            catch {
                Write-StyledMessage Warning "Impossibile eliminare completamente $displayName - file in uso."
                return $false
            }
            finally {
                # Reset delle preferenze
                $ErrorActionPreference = 'Continue'
                $ProgressPreference = 'Continue'
                $VerbosePreference = 'SilentlyContinue'
            }
        }
    }
 
    # Funzione ausiliaria per centrare il testo.
    function Center-Text {
        param(
            [Parameter(Mandatory = $true)]
            [string]$text,
            [Parameter(Mandatory = $false)]
            [int]$width = $Host.UI.RawUI.BufferSize.Width
        )

        $padding = [Math]::Max(0, [Math]::Floor(($width - $text.Length) / 2))

        return (' ' * $padding + $text)
    }

    #---

    # Main script
    Clear-Host
 
    # Get the actual console width for dynamic centering.
    $width = $Host.UI.RawUI.BufferSize.Width
 
    # Draw the top border line, adjusting for dynamic width.
    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
 
    $asciiArt = @(
        '      __        __  _  _   _ ',
        '      \ \      / / | || \ | |',
        '       \ \ /\ / /  | ||  \| |',
        '        \ V  V /   | || |\  |',
        '         \_/\_/    |_||_| \_|',
        '',
        ' Update Reset Toolkit By MagnetarMan',
        '       Version 2.2 (Build 12)'
    )
 
    foreach ($line in $asciiArt) {
        # Call the Center-Text function, passing the dynamic width.
        if (-not [string]::IsNullOrEmpty($line)) {
            Write-Host (Center-Text -text $line -width $width) -ForegroundColor White
        }
    }
 
    # Draw the bottom border line.
    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    Write-Host ''

    Write-StyledMessage Info '🔧 Inizializzazione dello Script di Reset Windows Update...'
    Start-Sleep -Seconds 2

    Write-Host '⚡ Caricamento moduli... ' -NoNewline -ForegroundColor Yellow
    for ($i = 0; $i -lt 15; $i++) {
        Write-Host $spinners[$i % $spinners.Length] -NoNewline -ForegroundColor Yellow
        Start-Sleep -Milliseconds 160
        Write-Host "`b" -NoNewline
    }
    Write-Host '✅ Completato!' -ForegroundColor Green
    Write-Host ''

    Write-StyledMessage Info '🛠️ Avvio riparazione servizi Windows Update...'
    Write-Host ''

    $serviceConfig = @{
        'wuauserv'         = @{ Type = 'Automatic'; Critical = $true; Icon = '🔄'; DisplayName = 'Windows Update' }
        'bits'             = @{ Type = 'Automatic'; Critical = $true; Icon = '📡'; DisplayName = 'Background Intelligent Transfer' }
        'cryptsvc'         = @{ Type = 'Automatic'; Critical = $true; Icon = '🔐'; DisplayName = 'Cryptographic Services' }
        'trustedinstaller' = @{ Type = 'Manual'; Critical = $true; Icon = '🛡️'; DisplayName = 'Windows Modules Installer' }
        'msiserver'        = @{ Type = 'Manual'; Critical = $false; Icon = '📦'; DisplayName = 'Windows Installer' }
    }
    
    $systemServices = @(
        @{ Name = 'appidsvc'; Icon = '🆔'; Display = 'Application Identity' },
        @{ Name = 'gpsvc'; Icon = '📋'; Display = 'Group Policy Client' },
        @{ Name = 'DcomLaunch'; Icon = '🚀'; Display = 'DCOM Server Process Launcher' },
        @{ Name = 'RpcSs'; Icon = '📞'; Display = 'Remote Procedure Call' },
        @{ Name = 'LanmanServer'; Icon = '🖥️'; Display = 'Server' },
        @{ Name = 'LanmanWorkstation'; Icon = '💻'; Display = 'Workstation' },
        @{ Name = 'EventLog'; Icon = '📄'; Display = 'Windows Event Log' },
        @{ Name = 'mpssvc'; Icon = '🛡️'; Display = 'Windows Defender Firewall' },
        @{ Name = 'WinDefend'; Icon = '🔒'; Display = 'Windows Defender Service' }
    )

    try {
        Write-StyledMessage Info '🛑 Arresto servizi Windows Update...'
        $stopServices = @('wuauserv', 'cryptsvc', 'bits', 'msiserver')
        for ($i = 0; $i -lt $stopServices.Count; $i++) {
            Manage-Service $stopServices[$i] 'Stop' $serviceConfig[$stopServices[$i]] ($i + 1) $stopServices.Count
        }
        
        Write-Host ''
        Write-StyledMessage Info '⏳ Attesa liberazione risorse...'
        Start-Sleep -Seconds 3
        Write-Host ''

        Write-StyledMessage Info '⚙️ Ripristino configurazione servizi Windows Update...'
        $criticalServices = $serviceConfig.Keys | Where-Object { $serviceConfig[$_].Critical }
        for ($i = 0; $i -lt $criticalServices.Count; $i++) {
            $serviceName = $criticalServices[$i]
            Write-StyledMessage Info "$($serviceConfig[$serviceName].Icon) Elaborazione servizio: $serviceName"
            Manage-Service $serviceName 'Configure' $serviceConfig[$serviceName] ($i + 1) $criticalServices.Count
        }
        Write-Host ''

        Write-StyledMessage Info '🔍 Verifica servizi di sistema critici...'
        for ($i = 0; $i -lt $systemServices.Count; $i++) {
            $sysService = $systemServices[$i]
            Manage-Service $sysService.Name 'Check' @{ Icon = $sysService.Icon } ($i + 1) $systemServices.Count
        }
        Write-Host ''

        Write-StyledMessage Info '📋 Ripristino chiavi di registro Windows Update...'
        Write-Host '🔄 Elaborazione registro... ' -NoNewline -ForegroundColor Cyan
        for ($i = 0; $i -lt 10; $i++) {
            Write-Host $spinners[$i % $spinners.Length] -NoNewline -ForegroundColor Cyan
            Start-Sleep -Milliseconds 150
            Write-Host "`b" -NoNewline
        }
        try {
            @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update",
                "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
            ) | Where-Object { Test-Path $_ } | ForEach-Object {
                Remove-Item $_ -Recurse -Force -ErrorAction Stop
                Write-Host 'Completato!' -ForegroundColor Green
                Write-StyledMessage Success "🔑 Chiave rimossa: $_"
            }
            if (-not @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update", "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate") | Where-Object { Test-Path $_ }) {
                Write-Host 'Completato!' -ForegroundColor Green
                Write-StyledMessage Info "🔑 Nessuna chiave di registro da rimuovere."
            }
        }
        catch {
            Write-Host 'Errore!' -ForegroundColor Red
            Write-StyledMessage Warning "Errore durante la modifica del registro - $($_.Exception.Message)"
        }
        Write-Host ''

        Write-StyledMessage Info '🗂️ Eliminazione componenti Windows Update...'
        $directories = @(
            @{ Path = "C:\Windows\SoftwareDistribution"; Name = "SoftwareDistribution" },
            @{ Path = "C:\Windows\System32\catroot2"; Name = "catroot2" }
        )
        
        for ($i = 0; $i -lt $directories.Count; $i++) {
            $dir = $directories[$i]
            $percent = [math]::Round((($i + 1) / $directories.Count) * 100)
            Show-ProgressBar "Directory ($($i + 1)/$($directories.Count))" "Eliminazione $($dir.Name)" $percent '🗑️' '' 'Yellow'
            
            Start-Sleep -Milliseconds 300
            
            $success = Remove-DirectorySafely -path $dir.Path -displayName $dir.Name
            if (-not $success) {
                Write-StyledMessage Info "💡 Suggerimento: Alcuni file potrebbero essere ricreati dopo il riavvio."
            }
            
            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()
            [Console]::SetCursorPosition(0, [Console]::CursorTop)
            Start-Sleep -Milliseconds 500
        }

        Write-Host ''
        [Console]::Out.Flush()
        [Console]::SetCursorPosition(0, [Console]::CursorTop)

        Write-StyledMessage Info '🚀 Avvio servizi essenziali...'
        $essentialServices = @('wuauserv', 'cryptsvc', 'bits')
        for ($i = 0; $i -lt $essentialServices.Count; $i++) {
            Manage-Service $essentialServices[$i] 'Start' $serviceConfig[$essentialServices[$i]] ($i + 1) $essentialServices.Count
        }
        Write-Host ''

        Write-StyledMessage Info '🔄 Reset del client Windows Update...'
        Write-Host '⚡ Esecuzione comando reset... ' -NoNewline -ForegroundColor Magenta
        try {
            Start-Process "cmd.exe" -ArgumentList "/c wuauclt /resetauthorization /detectnow" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
            Write-Host 'Completato!' -ForegroundColor Green
            Write-StyledMessage Success "🔄 Client Windows Update reimpostato."
        }
        catch {
            Write-Host 'Errore!' -ForegroundColor Red
            Write-StyledMessage Warning "Errore durante il reset del client Windows Update."
        }
        Write-Host ''

        Write-Host ('═' * 65) -ForegroundColor Green
        Write-StyledMessage Success '🎉 Riparazione completata con successo!'
        Write-StyledMessage Success '💻 Il sistema necessita di un riavvio per applicare tutte le modifiche.'
        Write-StyledMessage Warning "⚡ Attenzione: il sistema verrà riavviato automaticamente"
        Write-Host ('═' * 65) -ForegroundColor Green
        Write-Host ''
        
        $shouldReboot = Start-InterruptibleCountdown $CountdownSeconds "Preparazione riavvio sistema"
        
        if ($shouldReboot) {
            Write-StyledMessage Info "🔄 Riavvio in corso..."
            try { Stop-Transcript | Out-Null } catch {}
            Restart-Computer -Force
        }
    }
    catch {
        Write-Host ''
        Write-Host ('═' * 65) -ForegroundColor Red
        Write-StyledMessage Error "💥 Errore critico: $($_.Exception.Message)"
        Write-StyledMessage Error '❌ Si è verificato un errore durante la riparazione.'
        Write-StyledMessage Info '🔍 Controlla i messaggi sopra per maggiori dettagli.'
        Write-Host ('═' * 65) -ForegroundColor Red
        Write-StyledMessage Info '⌨️ Premere un tasto per uscire...'
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }

}
function WinReinstallStore {
    <#
    .SYNOPSIS
        Reinstalla automaticamente il Microsoft Store su Windows 10/11 utilizzando Winget.
    
    .DESCRIPTION
        Script ottimizzato per reinstallare Winget, Microsoft Store e UniGet UI senza output bloccanti.
    #>
    
    param([int]$CountdownSeconds = 30)
    
    $Host.UI.RawUI.WindowTitle = "Store Repair Toolkit By MagnetarMan"
    $MsgStyles = @{
        Success  = @{ Color = 'Green'; Icon = '✅' }
        Warning  = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error    = @{ Color = 'Red'; Icon = '❌' }
        Info     = @{ Color = 'Cyan'; Icon = '💎' }
        Progress = @{ Color = 'Magenta'; Icon = '🔄' }
    }
    
    # Funzione per centrare il testo
    function Center-Text {
        param(
            [Parameter(Mandatory = $true)]
            [string]$text,
            [Parameter(Mandatory = $false)]
            [int]$width = $Host.UI.RawUI.BufferSize.Width # Usa la larghezza dinamica di default
        )

        # Calcola il padding necessario
        $padding = [Math]::Max(0, [Math]::Floor(($width - $text.Length) / 2))

        # Restituisce la stringa centrata
        return (' ' * $padding + $text)
    }

    #---

    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            ' Store Repair Toolkit By MagnetarMan',
            '       Version 2.2 (Build 30)'
        )

        foreach ($line in $asciiArt) {
            if (-not [string]::IsNullOrEmpty($line)) {
                Write-Host (Center-Text -text $line -width $width) -ForegroundColor White
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }
    function Write-StyledMessage([string]$type, [string]$text) {
        $style = $MsgStyles[$type]
        Write-Host "$($style.Icon) $text" -ForegroundColor $style.Color
    }
    
    function Clear-Terminal {
        1..50 | ForEach-Object { Write-Host "" }
        Clear-Host
        [Console]::Clear()
        try {
            [System.Console]::SetCursorPosition(0, 0)
            $Host.UI.RawUI.CursorPosition = @{X = 0; Y = 0 }
        }
        catch {}
        Start-Sleep -Milliseconds 200
    }
    
    function Stop-InterferingProcesses {
        @("WinStore.App", "wsappx", "AppInstaller", "Microsoft.WindowsStore",
            "Microsoft.DesktopAppInstaller", "RuntimeBroker", "dllhost") | ForEach-Object {
            Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep 2
    }
    
    function Test-WingetAvailable {
        try {
            $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            $null = & winget --version 2>$null
            return $LASTEXITCODE -eq 0
        }
        catch { return $false }
    }
    
    function Install-WingetSilent {
        Write-StyledMessage Progress "Reinstallazione Winget in corso..."
        Stop-InterferingProcesses

        $originalPos = [Console]::CursorTop
        try {
            # Soppressione completa dell'output
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'
            
            if ([System.Environment]::OSVersion.Version.Build -ge 26100) {
                try {
                    if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                        $null = Repair-WinGetPackageManager -Force -Latest 2>$null *>$null
                        Start-Sleep 5
                        if (Test-WingetAvailable) { return $true }
                    }
                }
                catch {}
            }

            $url = "https://aka.ms/getwinget"
            $temp = "$env:TEMP\WingetInstaller.msixbundle"
            if (Test-Path $temp) { Remove-Item $temp -Force *>$null }

            Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing *>$null
            $process = Start-Process powershell -ArgumentList @(
                "-NoProfile", "-WindowStyle", "Hidden", "-Command",
                "try { Add-AppxPackage -Path '$temp' -ForceApplicationShutdown -ErrorAction Stop } catch { exit 1 }; exit 0"
            ) -Wait -PassThru -WindowStyle Hidden

            Remove-Item $temp -Force -ErrorAction SilentlyContinue *>$null
            
            # Reset cursore e flush output
            [Console]::SetCursorPosition(0, $originalPos)
            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()
            
            Start-Sleep 5
            return (Test-WingetAvailable)
        }
        catch {
            return $false
        }
        finally {
            # Reset delle preferenze
            $ErrorActionPreference = 'Continue'
            $ProgressPreference = 'Continue'
            $VerbosePreference = 'SilentlyContinue'
        }
    }
    
    function Install-MicrosoftStoreSilent {
        Write-StyledMessage Progress "Reinstallazione Microsoft Store in corso..."
        
        $originalPos = [Console]::CursorTop
        try {
            # Soppressione completa dell'output
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'
            
            @("AppXSvc", "ClipSVC", "WSService") | ForEach-Object {
                try { Restart-Service $_ -Force -ErrorAction SilentlyContinue *>$null } catch {}
            }

            @("$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_*\LocalCache",
                "$env:LOCALAPPDATA\Microsoft\Windows\INetCache") | ForEach-Object {
                if (Test-Path $_) { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue *>$null }
            }

            $methods = @(
                {
                    if (Test-WingetAvailable) {
                        $process = Start-Process winget -ArgumentList "install 9WZDNCRFJBMP --accept-source-agreements --accept-package-agreements --silent --disable-interactivity" -Wait -PassThru -WindowStyle Hidden
                        return $process.ExitCode -eq 0
                    }
                    return $false
                },
                {
                    $store = Get-AppxPackage -AllUsers Microsoft.WindowsStore -ErrorAction SilentlyContinue
                    if ($store) {
                        $store | ForEach-Object {
                            $manifest = "$($_.InstallLocation)\AppXManifest.xml"
                            if (Test-Path $manifest) {
                                $process = Start-Process powershell -ArgumentList @(
                                    "-NoProfile", "-WindowStyle", "Hidden", "-Command",
                                    "Add-AppxPackage -DisableDevelopmentMode -Register '$manifest' -ForceApplicationShutdown"
                                ) -Wait -PassThru -WindowStyle Hidden
                            }
                        }
                        return $true
                    }
                    return $false
                },
                {
                    $process = Start-Process DISM -ArgumentList "/Online /Add-Capability /CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0" -Wait -PassThru -WindowStyle Hidden
                    return $process.ExitCode -eq 0
                }
            )

            foreach ($method in $methods) {
                try {
                    if (& $method) {
                        Start-Process wsreset.exe -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue *>$null
                        
                        # Reset cursore e flush output
                        [Console]::SetCursorPosition(0, $originalPos)
                        $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
                        Write-Host $clearLine -NoNewline
                        [Console]::Out.Flush()
                        
                        return $true
                    }
                }
                catch { continue }
            }
            return $false
        }
        finally {
            # Reset delle preferenze
            $ErrorActionPreference = 'Continue'
            $ProgressPreference = 'Continue'
            $VerbosePreference = 'SilentlyContinue'
        }
    }
    
    function Install-UniGetUISilent {
        Write-StyledMessage Progress "Reinstallazione UniGet UI in corso..."
        if (-not (Test-WingetAvailable)) { return $false }

        $originalPos = [Console]::CursorTop
        try {
            # Soppressione completa dell'output
            $ErrorActionPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'
            
            $null = Start-Process winget -ArgumentList "uninstall --exact --id MartiCliment.UniGetUI --silent --disable-interactivity" -Wait -PassThru -WindowStyle Hidden
            Start-Sleep 2
            $process = Start-Process winget -ArgumentList "install --exact --id MartiCliment.UniGetUI --source winget --accept-source-agreements --accept-package-agreements --silent --disable-interactivity --force" -Wait -PassThru -WindowStyle Hidden
            
            # Reset cursore e flush output
            [Console]::SetCursorPosition(0, $originalPos)
            $clearLine = "`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r"
            Write-Host $clearLine -NoNewline
            [Console]::Out.Flush()
            
            return $process.ExitCode -eq 0
        }
        catch {
            return $false
        }
        finally {
            # Reset delle preferenze
            $ErrorActionPreference = 'Continue'
            $ProgressPreference = 'Continue'
            $VerbosePreference = 'SilentlyContinue'
        }
    }
    
    function Start-CountdownReboot([int]$Seconds) {
        Write-StyledMessage Warning "Riavvio necessario per applicare le modifiche"
        Write-StyledMessage Info '💡 Premi un tasto qualsiasi per annullare...'

        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning "⏸️ Riavvio automatico annullato"
                Write-StyledMessage Error 'Riavvia manualmente: shutdown /r /t 0'
                return $false
            }

            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"

            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Warning "⏰ Riavvio del sistema..."

        try {
            shutdown /r /t 0
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore riavvio: $_"
            return $false
        }
    }
    
    Show-Header
    Write-StyledMessage Info "🚀 AVVIO REINSTALLAZIONE STORE"

    try {
        $wingetResult = Install-WingetSilent
        Clear-Terminal
        Show-Header
        Write-StyledMessage $(if ($wingetResult) { 'Success' }else { 'Warning' }) "$(if($wingetResult){'✅'}else{'⚠️'}) Winget $(if($wingetResult){'installato'}else{'processato'})"

        $storeResult = Install-MicrosoftStoreSilent
        if (-not $storeResult) {
            Write-StyledMessage Error "❌ Errore installazione Microsoft Store"
            Write-StyledMessage Info "💡 Verifica: Internet, Admin, Windows Update"
            return
        }
        Write-StyledMessage Success "✅ Microsoft Store installato"

        $unigetResult = Install-UniGetUISilent
        Write-StyledMessage $(if ($unigetResult) { 'Success' }else { 'Warning' }) "$(if($unigetResult){'✅'}else{'⚠️'}) UniGet UI $(if($unigetResult){'installato'}else{'processato'})"

        Write-Host ""
        Write-StyledMessage Success "🎉 OPERAZIONE COMPLETATA"

        if (Start-CountdownReboot -Seconds $CountdownSeconds) {
            Write-StyledMessage Info "🔄 Riavvio in corso..."
        }
    }
    catch {
        Clear-Terminal
        Show-Header
        Write-StyledMessage Error "❌ ERRORE: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Esegui come Admin, verifica Internet e Windows Update"
    }

}
function WinDriverInstall {
    Write-StyledMessage 'Warning' "Sviluppo funzione in corso"
    Write-Host "
Premi un tasto per tornare al menu principale..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
function WinBackupDriver {
    <#
    .SYNOPSIS
        Strumento di backup completo per i driver di sistema Windows.

    .DESCRIPTION
        Script PowerShell per eseguire il backup completo di tutti i driver di terze parti
        installati sul sistema. Il processo include l'esportazione tramite DISM, compressione
        in formato ZIP e spostamento automatico sul desktop con nomenclatura data-based.
        Ideale per il backup pre-format o per la migrazione dei driver su un nuovo sistema.
    #>

    param([int]$CountdownSeconds = 10)

    $Host.UI.RawUI.WindowTitle = "Driver Backup Toolkit By MagnetarMan"
    # Configurazione
    $BackupDir = "$env:LOCALAPPDATA\WinToolkit\Driver Backup"
    $ZipName = "DriverBackup_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
    $DesktopPath = [Environment]::GetFolderPath('Desktop')
    $FinalZipPath = Join-Path $DesktopPath "$ZipName.zip"

    $MsgStyles = @{
        Success  = @{ Color = 'Green'; Icon = '✅' }
        Warning  = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error    = @{ Color = 'Red'; Icon = '❌' }
        Info     = @{ Color = 'Cyan'; Icon = '💎' }
        Progress = @{ Color = 'Magenta'; Icon = '🔄' }
    }

    # Funzione per centrare il testo
    function Center-Text {
        param(
            [Parameter(Mandatory = $true)][string]$Text,
            [Parameter(Mandatory = $false)][int]$Width = $Host.UI.RawUI.BufferSize.Width
        )
        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
        return (' ' * $padding + $Text)
    }

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent) {
        $safePercent = [Math]::Max(0, [Math]::Min(100, $Percent))
        $filled = [Math]::Floor($safePercent * 30 / 100)
        $bar = "[$('█' * $filled)$('▒' * (30 - $filled))] $safePercent%"
        Write-Host "`r🔄 $Activity $bar $Status" -NoNewline -ForegroundColor Magenta
        if ($Percent -eq 100) { Write-Host '' }
    }

    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            '   Driver Backup Toolkit By MagnetarMan',
            '       Version 2.2 (Build 5)'
        )

        foreach ($line in $asciiArt) {
            if ($line -ne '') {
                Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
            }
            else {
                Write-Host ''
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    function Test-Administrator {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    function Start-DriverExport {
        Write-StyledMessage Info "💾 Avvio esportazione driver di terze parti..."

        try {
            # Verifica se la cartella esiste già
            if (Test-Path $BackupDir) {
                Write-StyledMessage Warning "Cartella backup esistente trovata, rimozione in corso..."
                Remove-Item $BackupDir -Recurse -Force -ErrorAction Stop
                Start-Sleep 1
            }

            # Crea la cartella di backup
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
            Write-StyledMessage Success "Cartella backup creata: $BackupDir"

            # Esegue l'esportazione DISM
            Write-StyledMessage Info "🔧 Esecuzione DISM per esportazione driver..."
            Write-StyledMessage Info "💡 Questa operazione può richiedere diversi minuti..."

            $dismArgs = @('/online', '/export-driver', "/destination:`"$BackupDir`"")

            $process = Start-Process 'dism.exe' -ArgumentList $dismArgs -NoNewWindow -PassThru -Wait

            if ($process.ExitCode -eq 0) {
                # Verifica se sono stati esportati dei driver
                $exportedDrivers = Get-ChildItem -Path $BackupDir -Recurse -File -ErrorAction SilentlyContinue

                if ($exportedDrivers -and $exportedDrivers.Count -gt 0) {
                    Write-StyledMessage Success "Driver esportati con successo!"
                    Write-StyledMessage Info "Driver trovati: $($exportedDrivers.Count)"
                    return $true
                }
                else {
                    Write-StyledMessage Warning "Nessun driver di terze parti trovato da esportare"
                    Write-StyledMessage Info "💡 I driver integrati di Windows non vengono esportati"
                    return $true
                }
            }
            else {
                Write-StyledMessage Error "Errore durante esportazione DISM (Exit code: $($process.ExitCode))"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante esportazione driver: $_"
            return $false
        }
    }

    function Start-DriverCompression {
        Write-StyledMessage Info "📦 Compressione cartella backup..."

        try {
            # Verifica che la cartella esista e contenga file
            if (-not (Test-Path $BackupDir)) {
                Write-StyledMessage Error "Cartella backup non trovata"
                return $false
            }

            $files = Get-ChildItem -Path $BackupDir -Recurse -File -ErrorAction SilentlyContinue
            if (-not $files -or $files.Count -eq 0) {
                Write-StyledMessage Warning "Nessun file da comprimere nella cartella backup"
                return $false
            }

            # Calcola dimensione totale per la progress bar
            $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
            $totalSizeMB = [Math]::Round($totalSize / 1MB, 2)

            Write-StyledMessage Info "Dimensione totale: $totalSizeMB MB"

            # Crea il file ZIP
            $tempZipPath = Join-Path $env:TEMP "$ZipName.zip"

            # Rimuovi file ZIP esistente se presente
            if (Test-Path $tempZipPath) {
                Remove-Item $tempZipPath -Force -ErrorAction SilentlyContinue
            }

            # Comprime la cartella
            Write-StyledMessage Info "🔄 Compressione in corso..."

            $progress = 0
            $compressAction = {
                param($backupDir, $tempZipPath)
                Compress-Archive -Path $backupDir -DestinationPath $tempZipPath -CompressionLevel Optimal -Force
            }

            $job = Start-Job -ScriptBlock $compressAction -ArgumentList $BackupDir, $tempZipPath

            while ($job.State -eq 'Running') {
                $progress += Get-Random -Minimum 1 -Maximum 5
                if ($progress -gt 95) { $progress = 95 }

                Show-ProgressBar "Compressione" "Elaborazione file..." $progress
                Start-Sleep -Milliseconds 500
            }

            $compressResult = Receive-Job $job -Wait
            Remove-Job $job

            Show-ProgressBar "Compressione" "Completato!" 100
            Write-Host ''

            # Verifica che il file ZIP sia stato creato
            if (Test-Path $tempZipPath) {
                $zipSize = (Get-Item $tempZipPath).Length
                $zipSizeMB = [Math]::Round($zipSize / 1MB, 2)

                Write-StyledMessage Success "Compressione completata!"
                Write-StyledMessage Info "Archivio creato: $tempZipPath ($zipSizeMB MB)"

                return $tempZipPath
            }
            else {
                Write-StyledMessage Error "File ZIP non creato"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante compressione: $_"
            return $false
        }
    }

    function Move-ZipToDesktop {
        param([string]$ZipPath)

        Write-StyledMessage Info "📂 Spostamento archivio sul desktop..."

        try {
            # Verifica che il file ZIP esista
            if (-not (Test-Path $ZipPath)) {
                Write-StyledMessage Error "File ZIP non trovato: $ZipPath"
                return $false
            }

            # Sposta il file sul desktop
            Move-Item -Path $ZipPath -Destination $FinalZipPath -Force -ErrorAction Stop

            # Verifica che il file sia stato spostato
            if (Test-Path $FinalZipPath) {
                Write-StyledMessage Success "Archivio spostato sul desktop!"
                Write-StyledMessage Info "Posizione: $FinalZipPath"
                return $true
            }
            else {
                Write-StyledMessage Error "Errore durante spostamento sul desktop"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore spostamento: $_"
            return $false
        }
    }

    function Show-BackupSummary {
        param([string]$ZipPath)

        Write-Host ''
        Write-StyledMessage Success "🎉 Backup driver completato con successo!"
        Write-Host ''

        Write-StyledMessage Info "📁 Posizione archivio:"
        Write-Host "  $FinalZipPath" -ForegroundColor Cyan
        Write-Host ''

        Write-StyledMessage Info "💡 IMPORTANTE:"
        Write-StyledMessage Info "  🔄 Salva questo archivio in un luogo sicuro!"
        Write-StyledMessage Info "  💾 Potrai utilizzarlo per reinstallare tutti i driver"
        Write-StyledMessage Info "  🔧 Senza doverli riscaricare singolarmente"
        Write-Host ''
    }

    # MAIN EXECUTION
    Show-Header

    # Verifica privilegi amministrativi
    if (-not (Test-Administrator)) {
        Write-StyledMessage Error " Questo script richiede privilegi amministrativi!"
        Write-StyledMessage Info "💡 Riavvia PowerShell come Amministratore e riprova"
        Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
        Read-Host | Out-Null
        return
    }

    Write-Host "⏳ Inizializzazione sistema..." -ForegroundColor Yellow
    Start-Sleep 2
    Write-Host Success "✅ Sistema pronto`n" -ForegroundColor Green

    try {
        # Passo 1: Esportazione driver
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-StyledMessage Info "📋 FASE 1: ESPORTAZIONE DRIVER"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''

        if (-not (Start-DriverExport)) {
            Write-StyledMessage Error "Esportazione driver fallita"
            Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
            Read-Host | Out-Null
            return
        }

        Write-Host ''
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-StyledMessage Info "📋 FASE 2: COMPRESSIONE ARCHIVIO"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''

        # Passo 2: Compressione
        $zipPath = Start-DriverCompression
        if (-not $zipPath) {
            Write-StyledMessage Error "Compressione fallita"
            Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
            Read-Host | Out-Null
            return
        }

        Write-Host ''
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-StyledMessage Info "📋 FASE 3: SPOSTAMENTO DESKTOP"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''

        # Passo 3: Spostamento sul desktop
        if (-not (Move-ZipToDesktop $zipPath)) {
            Write-StyledMessage Error "Spostamento sul desktop fallito"
            Write-StyledMessage Warning "💡 L'archivio potrebbe essere ancora nella cartella temporanea"
            Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
            Read-Host | Out-Null
            return
        }

        # Passo 4: Riepilogo finale
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-StyledMessage Info "📋 BACKUP COMPLETATO"
        Write-Host ('─' * 50) -ForegroundColor Gray
        Write-Host ''

        Show-BackupSummary $FinalZipPath

    }
    catch {
        Write-StyledMessage Error "Errore critico durante il backup: $($_.Exception.Message)"
        Write-StyledMessage Info "💡 Controlla i log per dettagli o contatta il supporto"
    }
    finally {
        # Pulizia cartella temporanea
        Write-StyledMessage Info "🧹 Pulizia cartella temporanea..."
        if (Test-Path $BackupDir) {
            Remove-Item $BackupDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
        Read-Host | Out-Null
        Write-StyledMessage Success "🎯 Driver Backup Toolkit terminato"
    }

}
function OfficeToolkit {
    <#
    .SYNOPSIS
        Strumento di gestione Microsoft Office (installazione, riparazione, rimozione)
    
    .DESCRIPTION
        Script PowerShell per gestire Microsoft Office tramite interfaccia utente semplificata.
        Supporta installazione Office Basic, riparazione Click-to-Run e rimozione completa con SaRA.
    #>
    
    param([int]$CountdownSeconds = 30)

    # Configurazione
    $TempDir = "$env:LOCALAPPDATA\WinToolkit\Office"
    $Spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()

    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💡' }
    }

    # Funzioni Helper
    function Write-StyledMessage([string]$Type, [string]$Message) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Message" -ForegroundColor $style.Color
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent) {
        $safePercent = [Math]::Max(0, [Math]::Min(100, $Percent))
        $filled = [Math]::Floor($safePercent * 30 / 100)
        $bar = "[$('█' * $filled)$('▒' * (30 - $filled))] $safePercent%"
        Write-Host "`r🔄 $Activity $bar $Status" -NoNewline -ForegroundColor Yellow
        if ($Percent -eq 100) { Write-Host '' }
    }

    function Show-Spinner([string]$Activity, [scriptblock]$Action) {
        $spinnerIndex = 0
        $job = Start-Job -ScriptBlock $Action

        while ($job.State -eq 'Running') {
            $spinner = $Spinners[$spinnerIndex++ % $Spinners.Length]
            Write-Host "`r$spinner $Activity..." -NoNewline -ForegroundColor Yellow
            Start-Sleep -Milliseconds 200
        }

        $result = Receive-Job $job -Wait
        Remove-Job $job
        Write-Host ''
        return $result
    }

    function Get-UserConfirmation([string]$Message, [string]$DefaultChoice = 'N') {
        do {
            $response = Read-Host "$Message [Y/N]"
            if ([string]::IsNullOrEmpty($response)) { $response = $DefaultChoice }
            $response = $response.ToUpper()
        } while ($response -notin @('Y', 'N'))
        return $response -eq 'Y'
    }

    function Start-CountdownRestart([string]$Reason) {
        Write-StyledMessage Info "🔄 $Reason - Il sistema verrà riavviato"
        Write-StyledMessage Info "💡 Premi un tasto qualsiasi per annullare..."

        for ($i = $CountdownSeconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning "⏸️ Riavvio annullato dall'utente"
                return $false
            }

            $percent = [Math]::Round((($CountdownSeconds - $i) / $CountdownSeconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"

            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Warning "⏰ Riavvio del sistema..."

        try {
            Restart-Computer -Force
            return $true
        }
        catch {
            Write-StyledMessage Error "Errore riavvio: $_"
            return $false
        }
    }

    function Stop-OfficeProcesses {
        $processes = @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')
        $closed = 0

        Write-StyledMessage Info "📋 Chiusura processi Office..."
        foreach ($processName in $processes) {
            $runningProcesses = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($runningProcesses) {
                try {
                    $runningProcesses | Stop-Process -Force -ErrorAction Stop
                    $closed++
                }
                catch {
                    Write-StyledMessage Warning "Impossibile chiudere: $processName"
                }
            }
        }

        if ($closed -gt 0) {
            Write-StyledMessage Success "$closed processi Office chiusi"
        }
    }

    function Get-OfficeClient {
        $paths = @(
            "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe",
            "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
        )
        return $paths | Where-Object { Test-Path $_ } | Select-Object -First 1
    }

    function Invoke-DownloadFile([string]$Url, [string]$OutputPath, [string]$Description) {
        try {
            Write-StyledMessage Info "📥 Download $Description..."
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($Url, $OutputPath)
            $webClient.Dispose()

            if (Test-Path $OutputPath) {
                Write-StyledMessage Success "Download completato: $Description"
                return $true
            }
            else {
                Write-StyledMessage Error "File non trovato dopo download: $Description"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore download $Description`: $_"
            return $false
        }
    }

    function Start-OfficeInstallation {
        Write-StyledMessage Info "🏢 Avvio installazione Office Basic..."

        try {
            if (-not (Test-Path $TempDir)) {
                New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
            }

            $setupPath = Join-Path $TempDir 'Setup.exe'
            $configPath = Join-Path $TempDir 'Basic.xml'

            $downloads = @(
                @{ Url = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/Setup.exe'; Path = $setupPath; Name = 'Setup Office' },
                @{ Url = 'https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/asset/Basic.xml'; Path = $configPath; Name = 'Configurazione Basic' }
            )

            foreach ($download in $downloads) {
                if (-not (Invoke-DownloadFile $download.Url $download.Path $download.Name)) {
                    return $false
                }
            }

            Write-StyledMessage Info "🚀 Avvio processo installazione..."
            $arguments = "/configure `"$configPath`""
            Start-Process -FilePath $setupPath -ArgumentList $arguments -WorkingDirectory $TempDir

            Write-StyledMessage Info "⏳ Attesa completamento installazione..."
            Write-Host "💡 Premi INVIO quando l'installazione è completata..." -ForegroundColor Yellow
            Read-Host | Out-Null

            if (Get-UserConfirmation "✅ Installazione completata con successo?" 'Y') {
                Write-StyledMessage Success "🎉 Installazione Office completata!"
                return $true
            }
            else {
                Write-StyledMessage Warning "Installazione non completata correttamente"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante installazione: $_"
            return $false
        }
        finally {
            if (Test-Path $TempDir) {
                Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    function Start-OfficeRepair {
        Write-StyledMessage Info "🔧 Avvio riparazione Office..."
        Stop-OfficeProcesses

        Write-StyledMessage Info "🧹 Pulizia cache Office..."
        $caches = @(
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache"
        )

        $cleanedCount = 0
        foreach ($cache in $caches) {
            if (Test-Path $cache) {
                try {
                    Remove-Item $cache -Recurse -Force -ErrorAction Stop
                    $cleanedCount++
                }
                catch {
                    # Ignora errori di cache
                }
            }
        }

        if ($cleanedCount -gt 0) {
            Write-StyledMessage Success "$cleanedCount cache eliminate"
        }

        Write-StyledMessage Info "🎯 Tipo di riparazione:"
        Write-Host "  [1] 🚀 Riparazione rapida (offline)" -ForegroundColor Green
        Write-Host "  [2] 🌐 Riparazione completa (online)" -ForegroundColor Yellow

        do {
            $choice = Read-Host "Scelta [1-2]"
        } while ($choice -notin @('1', '2'))

        try {
            $officeClient = Get-OfficeClient
            if (-not $officeClient) {
                Write-StyledMessage Error "Office Click-to-Run non trovato"
                return $false
            }

            $repairType = if ($choice -eq '1') { 'QuickRepair' } else { 'FullRepair' }
            $repairName = if ($choice -eq '1') { 'rapida' } else { 'completa' }

            Write-StyledMessage Info "🔧 Avvio riparazione $repairName..."
            $arguments = "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=$repairType DisplayLevel=True"
            Start-Process -FilePath $officeClient -ArgumentList $arguments -Wait:$false

            Write-StyledMessage Info "⏳ Attesa completamento riparazione..."
            Write-Host "💡 Premi INVIO quando la riparazione è completata..." -ForegroundColor Yellow
            Read-Host | Out-Null

            if (Get-UserConfirmation "✅ Riparazione completata con successo?" 'Y/N') {
                Write-StyledMessage Success "🎉 Riparazione Office completata!"
                return $true
            }
            else {
                Write-StyledMessage Warning "Riparazione non completata correttamente"
                if ($choice -eq '1') {
                    if (Get-UserConfirmation "🌐 Tentare riparazione completa online?" 'Y') {
                        Write-StyledMessage Info "🌐 Avvio riparazione completa (Riparazione Online)"
                        $arguments = "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=FullRepair DisplayLevel=True"
                        Start-Process -FilePath $officeClient -ArgumentList $arguments -Wait:$false

                        Write-Host "💡 Premi INVIO quando la riparazione completa è terminata..." -ForegroundColor Yellow
                        Read-Host | Out-Null

                        return Get-UserConfirmation "✅ Riparazione completa riuscita?" 'Y/N'
                    }
                }
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante riparazione: $_"
            return $false
        }
    }

    function Start-OfficeUninstall {
        Write-StyledMessage Warning "🗑️ Rimozione completa Microsoft Office, Verrà utilizzato Microsoft Support and Recovery Assistant (SaRA)"

        if (-not (Get-UserConfirmation "❓ Procedere con la rimozione completa?")) {
            Write-StyledMessage Info "❌ Operazione annullata"
            return $false
        }

        Stop-OfficeProcesses

        try {
            if (-not (Test-Path $TempDir)) {
                New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
            }

            $saraUrl = 'https://aka.ms/SaRA_EnterpriseVersionFiles'
            $saraZipPath = Join-Path $TempDir 'SaRA.zip'

            if (-not (Invoke-DownloadFile $saraUrl $saraZipPath 'Microsoft SaRA')) {
                return $false
            }

            Write-StyledMessage Info "📦 Estrazione SaRA..."
            try {
                Expand-Archive -Path $saraZipPath -DestinationPath $TempDir -Force
                Write-StyledMessage Success "Estrazione completata"
            }
            catch {
                Write-StyledMessage Error "Errore estrazione: $_"
                return $false
            }

            $saraExe = Get-ChildItem -Path $TempDir -Name "SaRAcmd.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $saraExe) {
                Write-StyledMessage Error "SaRAcmd.exe non trovato"
                return $false
            }

            $saraPath = Join-Path $TempDir $saraExe
            Write-StyledMessage Info "🚀 Avvio rimozione tramite SaRA..."
            Write-StyledMessage Warning "⏰ Questa operazione può richiedere molto tempo"
            Write-StyledMessage Warning "🚀 Ad operazione avviata, non chiudere la finestra di SaRA, la finestra si chiuderà automaticamente"

            $arguments = '-S OfficeScrubScenario -AcceptEula -OfficeVersion All'
            Start-Process -FilePath $saraPath -ArgumentList $arguments -Verb RunAs

            Write-Host "💡 Premi INVIO quando SaRA ha completato la rimozione..." -ForegroundColor Yellow
            Read-Host | Out-Null

            if (Get-UserConfirmation "✅ Rimozione completata con successo?" 'Y') {
                Write-StyledMessage Success "🎉 Rimozione Office completata!"
                return $true
            }
            else {
                Write-StyledMessage Warning "Rimozione potrebbe essere incompleta"
                return $false
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante rimozione: $_"
            return $false
        }
        finally {
            if (Test-Path $TempDir) {
                Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    function Show-Header {
        $Host.UI.RawUI.WindowTitle = "Office Toolkit By MagnetarMan"
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            '      Office Toolkit By MagnetarMan',
            '        Version 2.2 (Build 4)'
        )

        foreach ($line in $asciiArt) {
            $padding = [Math]::Max(0, [Math]::Floor(($width - $line.Length) / 2))
            Write-Host (' ' * $padding + $line) -ForegroundColor White
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }
    # MAIN EXECUTION
    Show-Header
    Write-Host "⏳ Inizializzazione sistema..." -ForegroundColor Yellow
    Start-Sleep 2
    Write-Host "✅ Sistema pronto`n" -ForegroundColor Green

    try {
        do {
            Write-StyledMessage Info "🎯 Seleziona un'opzione:"
            Write-Host ''
            Write-Host '  [1]  🏢 Installazione Office (Basic Version)' -ForegroundColor White
            Write-Host '  [2]  🔧 Ripara Office' -ForegroundColor White
            Write-Host '  [3]  🗑️ Rimozione completa Office' -ForegroundColor Yellow
            Write-Host '  [0]  ❌ Esci' -ForegroundColor Red
            Write-Host ''

            $choice = Read-Host 'Scelta [0-3]'
            Write-Host ''

            $success = $false
            $operation = ''

            switch ($choice) {
                '1' {
                    $operation = 'Installazione'
                    $success = Start-OfficeInstallation
                }
                '2' {
                    $operation = 'Riparazione'
                    $success = Start-OfficeRepair
                }
                '3' {
                    $operation = 'Rimozione'
                    $success = Start-OfficeUninstall
                }
                '0' {
                    Write-StyledMessage Info "👋 Uscita dal toolkit..."
                    return
                }
                default {
                    Write-StyledMessage Warning "Opzione non valida. Seleziona 0-3."
                    continue
                }
            }

            if ($choice -in @('1', '2', '3')) {
                if ($success) {
                    Write-StyledMessage Success "🎉 $operation completata!"
                    if (Get-UserConfirmation "🔄 Riavviare ora per finalizzare?" 'Y') {
                        Start-CountdownRestart "$operation completata"
                    }
                    else {
                        Write-StyledMessage Info "💡 Riavvia manualmente quando possibile"
                    }
                }
                else {
                    Write-StyledMessage Error "$operation non riuscita"
                    Write-StyledMessage Info "💡 Controlla i log per dettagli o contatta il supporto"
                }
                Write-Host "`n" + ('─' * 50) + "`n"
            }

        } while ($choice -ne '0')
    }
    catch {
        Write-StyledMessage Error "Errore critico: $($_.Exception.Message)"
    }
    finally {
        Write-StyledMessage Success "🧹 Pulizia finale..."
        if (Test-Path $TempDir) {
            Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-Host "`nPremi INVIO per uscire..." -ForegroundColor Gray
        Read-Host | Out-Null
        Write-StyledMessage Success "🎯 Office Toolkit terminato"
    }

}
function GamingToolkit {
    Write-StyledMessage 'Warning' "Sviluppo funzione in corso"
    Write-Host "
Premi un tasto per tornare al menu principale..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
function WinCleaner {
    <#
    .SYNOPSIS
        Script automatico per la pulizia completa del sistema Windows.

    .DESCRIPTION
        Questo script esegue una pulizia completa e automatica del sistema Windows,
        utilizzando cleanmgr.exe con configurazione automatica (/sageset e /sagerun)
        e pulendo manualmente tutti i componenti specificati:
        - WinSxS Assemblies sostituiti
        - Rapporti Errori Windows
        - Registro Eventi Windows
        - Cronologia Installazioni Windows Update
        - Punti di Ripristino del sistema
        - Cache Download Windows
        - Cache .NET
        - Prefetch Windows
        - Cache Miniature Explorer
        - Cache web WinInet
        - Cookie Internet
        - Cache DNS
        - File Temporanei Windows
        - File Temporanei Utente
        - Coda di Stampa
        - Log di Sistema
    #>

    param([int]$CountdownSeconds = 30)

    $Host.UI.RawUI.WindowTitle = "Cleaner Toolkit By MagnetarMan"
    $script:Log = @(); $script:CurrentAttempt = 0
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    $CleanupTasks = @(
        @{ Task = 'CleanMgrAuto'; Name = 'Pulizia automatica CleanMgr'; Icon = '🧹'; Auto = $true }
        @{ Task = 'WinSxS'; Name = 'WinSxS - Assembly sostituiti'; Icon = '📦'; Auto = $false }
        @{ Task = 'ErrorReports'; Name = 'Rapporti errori Windows'; Icon = '📋'; Auto = $false }
        @{ Task = 'EventLogs'; Name = 'Registro eventi Windows'; Icon = '📜'; Auto = $false }
        @{ Task = 'UpdateHistory'; Name = 'Cronologia Windows Update'; Icon = '📝'; Auto = $false }
        @{ Task = 'RestorePoints'; Name = 'Punti ripristino sistema'; Icon = '💾'; Auto = $false }
        @{ Task = 'DownloadCache'; Name = 'Cache download Windows'; Icon = '⬇️'; Auto = $false }
        @{ Task = 'DotNetCache'; Name = 'Cache .NET Framework'; Icon = '🔧'; Auto = $false }
        @{ Task = 'Prefetch'; Name = 'Cache Prefetch Windows'; Icon = '⚡'; Auto = $false }
        @{ Task = 'ThumbnailCache'; Name = 'Cache miniature Explorer'; Icon = '🖼️'; Auto = $false }
        @{ Task = 'WinInetCache'; Name = 'Cache web WinInet'; Icon = '🌐'; Auto = $false }
        @{ Task = 'InternetCookies'; Name = 'Cookie Internet'; Icon = '🍪'; Auto = $false }
        @{ Task = 'DNSFlush'; Name = 'Flush cache DNS'; Icon = '🔄'; Auto = $false }
        @{ Task = 'WindowsTemp'; Name = 'File temporanei Windows'; Icon = '🗂️'; Auto = $false }
        @{ Task = 'UserTemp'; Name = 'File temporanei utente'; Icon = '📁'; Auto = $false }
        @{ Task = 'PrintQueue'; Name = 'Coda di stampa'; Icon = '🖨️'; Auto = $false }
        @{ Task = 'SystemLogs'; Name = 'Log di sistema'; Icon = '📄'; Auto = $false }
    )

    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }

    function Show-ProgressBar([string]$Activity, [string]$Status, [int]$Percent, [string]$Icon, [string]$Spinner = '', [string]$Color = 'Green') {
        $safePercent = [math]::Max(0, [math]::Min(100, $Percent))
        $filled = '█' * [math]::Floor($safePercent * 30 / 100)
        $empty = '▒' * (30 - $filled.Length)
        $bar = "[$filled$empty] {0,3}%" -f $safePercent
        Write-Host "`r$Spinner $Icon $Activity $bar $Status" -NoNewline -ForegroundColor $Color
        if ($Percent -eq 100) { Write-Host '' }
    }

    function Start-InterruptibleCountdown([int]$Seconds, [string]$Message) {
        Write-StyledMessage Info '💡 Premi un tasto qualsiasi per annullare...'
        Write-Host ''

        for ($i = $Seconds; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                Write-Host "`n"
                Write-StyledMessage Warning '⏸️ Riavvio automatico annullato'
                Write-StyledMessage Info "🔄 Puoi riavviare manualmente: 'shutdown /r /t 0' o dal menu Start."
                return $false
            }

            $percent = [Math]::Round((($Seconds - $i) / $Seconds) * 100)
            $filled = [Math]::Floor($percent * 20 / 100)
            $remaining = 20 - $filled
            $bar = "[$('█' * $filled)$('▒' * $remaining)] $percent%"

            Write-Host "`r⏰ Riavvio automatico tra $i secondi $bar" -NoNewline -ForegroundColor Red
            Start-Sleep 1
        }

        Write-Host "`n"
        Write-StyledMessage Warning '⏰ Tempo scaduto: il sistema verrà riavviato ora.'
        Start-Sleep 1
        return $true
    }

    function Invoke-CleanMgrAuto {
        Write-StyledMessage Info "🧹 Configurazione pulizia automatica CleanMgr..."
        $percent = 0; $spinnerIndex = 0

        try {
            # Configurazione sageset:1 con tutte le opzioni
            Write-StyledMessage Info "⚙️ Configurazione opzioni pulizia (sageset:1)..."
            Start-Process 'cleanmgr.exe' -ArgumentList '/d C: /sageset:1' -Wait -WindowStyle Hidden

            # Esecuzione sagerun:1
            Write-StyledMessage Info "🚀 Avvio pulizia automatica (sagerun:1)..."
            $proc = Start-Process 'cleanmgr.exe' -ArgumentList '/sagerun:1' -NoNewWindow -PassThru

            while (-not $proc.HasExited) {
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                if ($percent -lt 95) { $percent += Get-Random -Minimum 1 -Maximum 3 }
                Show-ProgressBar "Pulizia CleanMgr" 'Esecuzione in corso...' $percent '🧹' $spinner
                Start-Sleep -Milliseconds 800
                $proc.Refresh()
            }

            Show-ProgressBar "Pulizia CleanMgr" 'Completato con successo' 100 '🧹'
            Write-Host ''
            Write-StyledMessage Success "✅ Pulizia automatica CleanMgr completata"

            $script:Log += "[CleanMgrAuto] ✅ Pulizia automatica completata"
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Write-StyledMessage Error "Errore durante pulizia CleanMgr: $_"
            $script:Log += "[CleanMgrAuto] ❌ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-WinSxSCleanup {
        Write-StyledMessage Info "📦 Pulizia componenti WinSxS sostituiti..."
        $percent = 0; $spinnerIndex = 0

        try {
            $proc = Start-Process 'DISM.exe' -ArgumentList '/Online /Cleanup-Image /StartComponentCleanup /ResetBase' -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\dism_out.txt" -RedirectStandardError "$env:TEMP\dism_err.txt"

            while (-not $proc.HasExited) {
                $spinner = $spinners[$spinnerIndex++ % $spinners.Length]
                if ($percent -lt 95) { $percent += Get-Random -Minimum 1 -Maximum 2 }
                Show-ProgressBar "WinSxS Cleanup" 'Analisi componenti...' $percent '📦' $spinner
                Start-Sleep -Milliseconds 1000
                $proc.Refresh()
            }

            $exitCode = $proc.ExitCode
            Show-ProgressBar "WinSxS Cleanup" 'Completato' 100 '📦'
            Write-Host ''

            if ($exitCode -eq 0) {
                Write-StyledMessage Success "✅ Componenti WinSxS puliti con successo"
                $script:Log += "[WinSxS] ✅ Pulizia completata"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Warning "⚠️ Pulizia WinSxS completata con warnings (Exit code: $exitCode)"
                $script:Log += "[WinSxS] ⚠️ Completato con warnings (Exit code: $exitCode)"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante pulizia WinSxS: $_"
            $script:Log += "[WinSxS] ❌ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
        finally {
            Remove-Item "$env:TEMP\dism_out.txt", "$env:TEMP\dism_err.txt" -ErrorAction SilentlyContinue
        }
    }

    function Invoke-ErrorReportsCleanup {
        Write-StyledMessage Info "📋 Pulizia rapporti errori Windows..."
        $werPaths = @(
            "$env:ProgramData\Microsoft\Windows\WER",
            "$env:ALLUSERSPROFILE\Microsoft\Windows\WER"
        )

        $totalCleaned = 0
        foreach ($path in $werPaths) {
            if (Test-Path $path) {
                try {
                    $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue
                    $files | Remove-Item -Force -ErrorAction SilentlyContinue
                    $totalCleaned += $files.Count
                    Write-StyledMessage Info "🗑️ Rimosso $($files.Count) file da $path"
                }
                catch {
                    Write-StyledMessage Warning "⚠️ Impossibile pulire $path - $_"
                }
            }
        }

        if ($totalCleaned -gt 0) {
            Write-StyledMessage Success "✅ Rapporti errori puliti ($totalCleaned file)"
            $script:Log += "[ErrorReports] ✅ Pulizia completata ($totalCleaned file)"
            return @{ Success = $true; ErrorCount = 0 }
        }
        else {
            Write-StyledMessage Info "💭 Nessun rapporto errori da pulire"
            $script:Log += "[ErrorReports] ℹ️ Nessun file da pulire"
            return @{ Success = $true; ErrorCount = 0 }
        }
    }

    function Invoke-EventLogsCleanup {
        Write-StyledMessage Info "📜 Pulizia registro eventi Windows..."
        try {
            # Backup dei log attuali
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupPath = "$env:TEMP\EventLogs_Backup_$timestamp.evtx"

            wevtutil el | ForEach-Object {
                wevtutil cl $_ 2>$null
            }

            Write-StyledMessage Success "✅ Registro eventi pulito"
            $script:Log += "[EventLogs] ✅ Pulizia completata"
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Write-StyledMessage Warning "⚠️ Errore durante pulizia registro eventi: $_"
            $script:Log += "[EventLogs] ⚠️ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-UpdateHistoryCleanup {
        Write-StyledMessage Info "📝 Pulizia cronologia Windows Update..."
        $updatePaths = @(
            "C:\WINDOWS\SoftwareDistribution\DataStore\DataStore.edb",
            "C:\WINDOWS\SoftwareDistribution\DataStore\DataStore.jfm",
            "C:\WINDOWS\SoftwareDistribution\DataStore\Logs"
        )

        $totalCleaned = 0
        foreach ($path in $updatePaths) {
            try {
                if (Test-Path $path) {
                    if (Test-Path -Path $path -PathType Container) {
                        $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue
                        $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                        $totalCleaned += $files.Count
                        Write-StyledMessage Info "🗑️ Rimossa directory: $path"
                    }
                    else {
                        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
                        $totalCleaned++
                        Write-StyledMessage Info "🗑️ Rimosso file: $path"
                    }
                }
            }
            catch {
                Write-StyledMessage Warning "⚠️ Impossibile rimuovere $path - $_"
            }
        }

        if ($totalCleaned -gt 0) {
            Write-StyledMessage Success "✅ Cronologia Update pulita ($totalCleaned elementi)"
            $script:Log += "[UpdateHistory] ✅ Pulizia completata ($totalCleaned elementi)"
            return @{ Success = $true; ErrorCount = 0 }
        }
        else {
            Write-StyledMessage Info "💭 Nessuna cronologia Update da pulire"
            $script:Log += "[UpdateHistory] ℹ️ Nessun file da pulire"
            return @{ Success = $true; ErrorCount = 0 }
        }
    }

    function Invoke-RestorePointsCleanup {
        Write-StyledMessage Info "💾 Disattivazione punti ripristino sistema..."
        try {
            # Disattiva la protezione del sistema
            vssadmin delete shadows /all /quiet 2>$null

            # Disattiva la protezione del sistema per il disco C:
            Disable-ComputerRestore -Drive "C:" -ErrorAction SilentlyContinue

            Write-StyledMessage Success "✅ Punti ripristino disattivati"
            $script:Log += "[RestorePoints] ✅ Disattivazione completata"
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Write-StyledMessage Warning "⚠️ Errore durante disattivazione punti ripristino: $_"
            $script:Log += "[RestorePoints] ⚠️ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DownloadCacheCleanup {
        Write-StyledMessage Info "⬇️ Pulizia cache download Windows..."
        $downloadPath = "C:\WINDOWS\SoftwareDistribution\Download"

        try {
            if (Test-Path $downloadPath) {
                $files = Get-ChildItem -Path $downloadPath -Recurse -File -ErrorAction SilentlyContinue
                $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

                Write-StyledMessage Success "✅ Cache download pulita ($($files.Count) file)"
                $script:Log += "[DownloadCache] ✅ Pulizia completata ($($files.Count) file)"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Info "💭 Cache download non presente"
                $script:Log += "[DownloadCache] ℹ️ Directory non presente"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Warning "⚠️ Errore durante pulizia cache download: $_"
            $script:Log += "[DownloadCache] ⚠️ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DotNetCacheCleanup {
        Write-StyledMessage Info "🔧 Pulizia cache .NET Framework..."
        $dotnetPaths = @(
            "C:\WINDOWS\assembly",
            "$env:WINDIR\Microsoft.NET"
        )

        $totalCleaned = 0
        foreach ($path in $dotnetPaths) {
            try {
                if (Test-Path $path) {
                    $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue
                    $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                    $totalCleaned += $files.Count
                    Write-StyledMessage Info "🗑️ Pulita cache .NET: $path"
                }
            }
            catch {
                Write-StyledMessage Warning "⚠️ Impossibile pulire $path - $_"
            }
        }

        if ($totalCleaned -gt 0) {
            Write-StyledMessage Success "✅ Cache .NET pulita ($totalCleaned file)"
            $script:Log += "[DotNetCache] ✅ Pulizia completata ($totalCleaned file)"
            return @{ Success = $true; ErrorCount = 0 }
        }
        else {
            Write-StyledMessage Info "💭 Nessuna cache .NET da pulire"
            $script:Log += "[DotNetCache] ℹ️ Nessun file da pulire"
            return @{ Success = $true; ErrorCount = 0 }
        }
    }

    function Invoke-PrefetchCleanup {
        Write-StyledMessage Info "⚡ Pulizia cache Prefetch Windows..."
        $prefetchPath = "C:\WINDOWS\Prefetch"

        try {
            if (Test-Path $prefetchPath) {
                $files = Get-ChildItem -Path $prefetchPath -File -ErrorAction SilentlyContinue
                $files | Remove-Item -Force -ErrorAction SilentlyContinue

                Write-StyledMessage Success "✅ Cache Prefetch pulita ($($files.Count) file)"
                $script:Log += "[Prefetch] ✅ Pulizia completata ($($files.Count) file)"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Info "💭 Cache Prefetch non presente"
                $script:Log += "[Prefetch] ℹ️ Directory non presente"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Warning "⚠️ Errore durante pulizia Prefetch: $_"
            $script:Log += "[Prefetch] ⚠️ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-ThumbnailCacheCleanup {
        Write-StyledMessage Info "🖼️ Pulizia cache miniature Explorer..."
        $thumbnailPaths = @(
            "$env:APPDATA\Microsoft\Windows\Explorer",
            "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
        )

        $totalCleaned = 0
        $thumbnailFiles = @(
            "iconcache_*.db", "thumbcache_*.db", "ExplorerStartupLog*.etl",
            "NotifyIcon", "RecommendationsFilterList.json"
        )

        foreach ($path in $thumbnailPaths) {
            foreach ($pattern in $thumbnailFiles) {
                try {
                    $files = Get-ChildItem -Path $path -Name $pattern -ErrorAction SilentlyContinue
                    $files | ForEach-Object {
                        $fullPath = Join-Path $path $_
                        Remove-Item -Path $fullPath -Force -ErrorAction SilentlyContinue
                        if (-not (Test-Path $fullPath)) { $totalCleaned++ }
                    }
                }
                catch {
                    Write-StyledMessage Warning "⚠️ Impossibile rimuovere alcuni file in $path"
                }
            }
        }

        if ($totalCleaned -gt 0) {
            Write-StyledMessage Success "✅ Cache miniature pulita ($totalCleaned file)"
            $script:Log += "[ThumbnailCache] ✅ Pulizia completata ($totalCleaned file)"
            return @{ Success = $true; ErrorCount = 0 }
        }
        else {
            Write-StyledMessage Info "💭 Nessuna cache miniature da pulire"
            $script:Log += "[ThumbnailCache] ℹ️ Nessun file da pulire"
            return @{ Success = $true; ErrorCount = 0 }
        }
    }

    function Invoke-WinInetCacheCleanup {
        Write-StyledMessage Info "🌐 Pulizia cache web WinInet..."
        try {
            # Pulisce la cache WinInet per tutti gli utenti
            $users = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
            $totalCleaned = 0

            foreach ($user in $users) {
                $localAppData = "$($user.FullName)\AppData\Local\Microsoft\Windows\INetCache"
                if (Test-Path $localAppData) {
                    try {
                        $files = Get-ChildItem -Path $localAppData -Recurse -File -ErrorAction SilentlyContinue
                        $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                        $totalCleaned += $files.Count
                    }
                    catch {
                        Write-StyledMessage Warning "⚠️ Impossibile pulire cache per utente $($user.Name)"
                    }
                }
            }

            # Forza pulizia cache IE
            RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 8 2>$null
            RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 2 2>$null

            Write-StyledMessage Success "✅ Cache WinInet pulita ($totalCleaned file)"
            $script:Log += "[WinInetCache] ✅ Pulizia completata ($totalCleaned file)"
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Write-StyledMessage Warning "⚠️ Errore durante pulizia cache WinInet: $_"
            $script:Log += "[WinInetCache] ⚠️ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-InternetCookiesCleanup {
        Write-StyledMessage Info "🍪 Pulizia cookie Internet..."
        try {
            # Pulisce i cookie per tutti gli utenti
            $users = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
            $totalCleaned = 0

            foreach ($user in $users) {
                $cookiesPaths = @(
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\INetCookies",
                    "$($user.FullName)\AppData\Roaming\Microsoft\Windows\Cookies"
                )

                foreach ($path in $cookiesPaths) {
                    if (Test-Path $path) {
                        try {
                            $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue
                            $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                            $totalCleaned += $files.Count
                        }
                        catch {
                            Write-StyledMessage Warning "⚠️ Impossibile pulire cookie per utente $($user.Name)"
                        }
                    }
                }
            }

            # Forza pulizia cookie IE
            RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 1 2>$null

            Write-StyledMessage Success "✅ Cookie Internet puliti ($totalCleaned file)"
            $script:Log += "[InternetCookies] ✅ Pulizia completata ($totalCleaned file)"
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Write-StyledMessage Warning "⚠️ Errore durante pulizia cookie: $_"
            $script:Log += "[InternetCookies] ⚠️ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DNSFlush {
        Write-StyledMessage Info "🔄 Flush cache DNS..."
        try {
            # Esegue il flush della cache DNS
            $result = ipconfig /flushdns 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-StyledMessage Success "✅ Cache DNS svuotata con successo"
                $script:Log += "[DNSFlush] ✅ Flush completato"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Warning "⚠️ Flush DNS completato con warnings"
                $script:Log += "[DNSFlush] ⚠️ Completato con warnings"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Warning "⚠️ Errore durante flush DNS: $_"
            $script:Log += "[DNSFlush] ⚠️ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-WindowsTempCleanup {
        Write-StyledMessage Info "🗂️ Pulizia file temporanei Windows..."
        $tempPath = "C:\WINDOWS\Temp"

        try {
            if (Test-Path $tempPath) {
                $files = Get-ChildItem -Path $tempPath -Recurse -File -ErrorAction SilentlyContinue
                $totalSize = ($files | Measure-Object -Property Length -Sum).Sum / 1MB
                $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

                Write-StyledMessage Success "✅ File temporanei Windows puliti ($($files.Count) file, $([math]::Round($totalSize, 2)) MB)"
                $script:Log += "[WindowsTemp] ✅ Pulizia completata ($($files.Count) file)"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Info "💭 Cartella temporanei Windows non presente"
                $script:Log += "[WindowsTemp] ℹ️ Directory non presente"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Warning "⚠️ Errore durante pulizia file temporanei Windows: $_"
            $script:Log += "[WindowsTemp] ⚠️ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-UserTempCleanup {
        Write-StyledMessage Info "📁 Pulizia file temporanei utente..."
        try {
            # Pulisce i file temporanei per tutti gli utenti
            $users = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
            $totalCleaned = 0
            $totalSize = 0

            foreach ($user in $users) {
                $tempPaths = @(
                    "$($user.FullName)\AppData\Local\Temp",
                    "$($user.FullName)\AppData\LocalLow\Temp"
                )

                foreach ($path in $tempPaths) {
                    if (Test-Path $path) {
                        try {
                            $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue
                            $size = ($files | Measure-Object -Property Length -Sum).Sum / 1MB
                            $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                            $totalCleaned += $files.Count
                            $totalSize += $size
                        }
                        catch {
                            Write-StyledMessage Warning "⚠️ Impossibile pulire temp per utente $($user.Name)"
                        }
                    }
                }
            }

            if ($totalCleaned -gt 0) {
                Write-StyledMessage Success "✅ File temporanei utente puliti ($totalCleaned file, $([math]::Round($totalSize, 2)) MB)"
                $script:Log += "[UserTemp] ✅ Pulizia completata ($totalCleaned file)"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Info "💭 Nessun file temporaneo utente da pulire"
                $script:Log += "[UserTemp] ℹ️ Nessun file da pulire"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Warning "⚠️ Errore durante pulizia file temporanei utente: $_"
            $script:Log += "[UserTemp] ⚠️ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-PrintQueueCleanup {
        Write-StyledMessage Info "🖨️ Pulizia coda di stampa..."
        try {
            # Ferma il servizio spooler
            Write-StyledMessage Info "⏸️ Arresto servizio spooler..."
            Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2

            # Pulisce la coda di stampa
            $spoolPath = "C:\WINDOWS\System32\spool\PRINTERS"
            $totalCleaned = 0

            if (Test-Path $spoolPath) {
                $files = Get-ChildItem -Path $spoolPath -File -ErrorAction SilentlyContinue
                $files | Remove-Item -Force -ErrorAction SilentlyContinue
                $totalCleaned = $files.Count
            }

            # Riavvia il servizio spooler
            Write-StyledMessage Info "▶️ Riavvio servizio spooler..."
            Start-Service -Name Spooler -ErrorAction SilentlyContinue

            if ($totalCleaned -gt 0) {
                Write-StyledMessage Success "✅ Coda di stampa pulita ($totalCleaned file)"
                $script:Log += "[PrintQueue] ✅ Pulizia completata ($totalCleaned file)"
            }
            else {
                Write-StyledMessage Info "💭 Nessun file in coda di stampa"
                $script:Log += "[PrintQueue] ℹ️ Nessun file da pulire"
            }

            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            # Assicura che il servizio spooler sia riavviato anche in caso di errore
            Start-Service -Name Spooler -ErrorAction SilentlyContinue
            Write-StyledMessage Warning "⚠️ Errore durante pulizia coda di stampa: $_"
            $script:Log += "[PrintQueue] ⚠️ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-SystemLogsCleanup {
        Write-StyledMessage Info "📄 Pulizia log di sistema..."
        $logPaths = @(
            "C:\WINDOWS\Logs",
            "C:\WINDOWS\System32\LogFiles",
            "C:\WINDOWS\Panther",
            "C:\ProgramData\Microsoft\Windows\WER\ReportQueue"
        )

        $totalCleaned = 0
        $totalSize = 0

        foreach ($path in $logPaths) {
            if (Test-Path $path) {
                try {
                    $files = Get-ChildItem -Path $path -Recurse -File -Include "*.log", "*.etl", "*.txt" -ErrorAction SilentlyContinue
                    $size = ($files | Measure-Object -Property Length -Sum).Sum / 1MB
                    $files | Remove-Item -Force -ErrorAction SilentlyContinue
                    $totalCleaned += $files.Count
                    $totalSize += $size
                    Write-StyledMessage Info "🗑️ Puliti log da: $path"
                }
                catch {
                    Write-StyledMessage Warning "⚠️ Impossibile pulire alcuni log in $path"
                }
            }
        }

        if ($totalCleaned -gt 0) {
            Write-StyledMessage Success "✅ Log di sistema puliti ($totalCleaned file, $([math]::Round($totalSize, 2)) MB)"
            $script:Log += "[SystemLogs] ✅ Pulizia completata ($totalCleaned file)"
            return @{ Success = $true; ErrorCount = 0 }
        }
        else {
            Write-StyledMessage Info "💭 Nessun log di sistema da pulire"
            $script:Log += "[SystemLogs] ℹ️ Nessun file da pulire"
            return @{ Success = $true; ErrorCount = 0 }
        }
    }

    function Invoke-CleanupTask([hashtable]$Task, [int]$Step, [int]$Total) {
        Write-StyledMessage Info "[$Step/$Total] Avvio $($Task.Name)..."
        $percent = 0; $spinnerIndex = 0

        try {
            $result = switch ($Task.Task) {
                'CleanMgrAuto' { Invoke-CleanMgrAuto }
                'WinSxS' { Invoke-WinSxSCleanup }
                'ErrorReports' { Invoke-ErrorReportsCleanup }
                'EventLogs' { Invoke-EventLogsCleanup }
                'UpdateHistory' { Invoke-UpdateHistoryCleanup }
                'RestorePoints' { Invoke-RestorePointsCleanup }
                'DownloadCache' { Invoke-DownloadCacheCleanup }
                'DotNetCache' { Invoke-DotNetCacheCleanup }
                'Prefetch' { Invoke-PrefetchCleanup }
                'ThumbnailCache' { Invoke-ThumbnailCacheCleanup }
                'WinInetCache' { Invoke-WinInetCacheCleanup }
                'InternetCookies' { Invoke-InternetCookiesCleanup }
                'DNSFlush' { Invoke-DNSFlush }
                'WindowsTemp' { Invoke-WindowsTempCleanup }
                'UserTemp' { Invoke-UserTempCleanup }
                'PrintQueue' { Invoke-PrintQueueCleanup }
                'SystemLogs' { Invoke-SystemLogsCleanup }
            }

            if ($result.Success) {
                Write-StyledMessage Success "$($Task.Icon) $($Task.Name) completato con successo"
            }
            else {
                Write-StyledMessage Warning "$($Task.Icon) $($Task.Name) completato con errori"
            }

            return $result
        }
        catch {
            Write-StyledMessage Error "Errore durante $($Task.Name): $_"
            $script:Log += "[$($Task.Name)] ❌ Errore fatale: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Center-Text {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Text,
            [Parameter(Mandatory = $false)]
            [int]$Width = $Host.UI.RawUI.BufferSize.Width
        )

        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))

        return (' ' * $padding + $Text)
    }

    function Show-Header {
        Clear-Host
        $width = $Host.UI.RawUI.BufferSize.Width
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green

        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            '    Cleaner Toolkit By MagnetarMan',
            '       Version 2.3 (Build 11)'
        )

        foreach ($line in $asciiArt) {
            if (-not [string]::IsNullOrEmpty($line)) {
                Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
            }
        }

        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }

    Show-Header

    for ($i = 5; $i -gt 0; $i--) {
        $spinner = $spinners[$i % $spinners.Length]
        Write-Host "`r$spinner ⏳ Preparazione sistema - $i secondi..." -NoNewline -ForegroundColor Yellow
        Start-Sleep 1
    }
    Write-Host "`n"

    try {
        Write-StyledMessage Info '🧹 Avvio pulizia completa del sistema...'
        Write-Host ''

        $totalErrors = $successCount = 0
        for ($i = 0; $i -lt $CleanupTasks.Count; $i++) {
            $result = Invoke-CleanupTask $CleanupTasks[$i] ($i + 1) $CleanupTasks.Count
            if ($result.Success) { $successCount++ }
            $totalErrors += $result.ErrorCount
            Start-Sleep 1
        }

        Write-Host ''
        Write-Host ('═' * 65) -ForegroundColor Green
        Write-StyledMessage Success "🎉 Pulizia completata con successo!"
        Write-StyledMessage Success "💻 Completati $successCount/$($CleanupTasks.Count) task di pulizia"
        if ($totalErrors -gt 0) {
            Write-StyledMessage Warning "⚠️ $totalErrors errori durante la pulizia"
        }
        Write-StyledMessage Info "🔄 Il sistema verrà riavviato per applicare tutte le modifiche"
        Write-Host ('═' * 65) -ForegroundColor Green
        Write-Host ''

        $shouldReboot = Start-InterruptibleCountdown $CountdownSeconds "Preparazione riavvio sistema"

        if ($shouldReboot) {
            Write-StyledMessage Info "🔄 Riavvio in corso..."
            Restart-Computer -Force
        }
        else {
            Write-StyledMessage Success "✅ Pulizia completata. Sistema non riavviato."
            Write-StyledMessage Info "💡 Riavvia quando possibile per applicare tutte le modifiche."
        }
    }
    catch {
        Write-Host ''
        Write-Host ('═' * 65) -ForegroundColor Red
        Write-StyledMessage Error "💥 Errore critico: $($_.Exception.Message)"
        Write-StyledMessage Error '❌ Si è verificato un errore durante la pulizia.'
        Write-Host ('═' * 65) -ForegroundColor Red
    }
    finally {
        Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
        Read-Host
    }

}

# Menu structure
$menuStructure = @(
    @{
        'Name' = 'Operazioni Preliminari'; 'Icon' = '🪄'
        'Scripts' = @([pscustomobject]@{ Name = 'WinInstallPSProfile'; Description = 'Installa profilo PowerShell'; Action = 'RunFunction' })
    },
    @{
        'Name' = 'Windows & Office'; 'Icon' = '🔧'
        'Scripts' = @(
            [pscustomobject]@{ Name = 'WinRepairToolkit'; Description = 'Toolkit Riparazione Windows'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinUpdateReset'; Description = 'Reset Windows Update'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinReinstallStore'; Description = 'Winget/WinStore Reset'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinBackupDriver'; Description = 'Backup Driver PC'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'WinCleaner'; Description = 'Pulizia File Temporanei'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'OfficeToolkit'; Description = 'Office Toolkit'; Action = 'RunFunction' }
        )
    },
    @{
        'Name' = 'Driver & Gaming'; 'Icon' = '🎮'
        'Scripts' = @(
            [pscustomobject]@{ Name = 'WinDriverInstall'; Description = 'Toolkit Driver Grafici - Planned V2.3'; Action = 'RunFunction' },
            [pscustomobject]@{ Name = 'GamingToolkit'; Description = 'Gaming Toolkit - Planned V2.4'; Action = 'RunFunction' }
        )
    },
    @{
        'Name' = 'Supporto'; 'Icon' = '🕹️'
        'Scripts' = @(
            [pscustomobject]@{ Name = 'SetRustDesk'; Description = 'Setting RustDesk - MagnetarMan Mode'; Action = 'RunFunction' }
        )
    }
)

# Main loop
while ($true) {
    Clear-Host
    $width = 65

    # Header
    Show-Header
    winver
    Write-Host ''

    # Build and display menu
    $allScripts = @()
    $scriptIndex = 1

    foreach ($category in $menuStructure) {
        Write-Host "=== $($category.Icon) $($category.Name) $($category.Icon) ===" -ForegroundColor Cyan
        Write-Host ''

        foreach ($script in $category.Scripts) {
            $allScripts += $script
            Write-StyledMessage -type 'Info' -text "[$scriptIndex] $($script.Description)"
            $scriptIndex++
        }
        Write-Host ''
    }

    # Exit section
    Write-Host "=== Uscita ===" -ForegroundColor Red
    Write-Host ''
    Write-StyledMessage -type 'Error' -text '[0] Esci dal Toolkit'
    Write-Host ''

    # Handle user choice
    $userChoice = Read-Host "Scegli un'opzione (es. 1, 3, 5 o 0 per uscire)"

    if ($userChoice -eq '0') {
        Write-StyledMessage -type 'Warning' -text 'Per supporto: Github.com/Magnetarman'
        Write-StyledMessage -type 'Success' -text 'Chiusura in corso...'
        Start-Sleep -Seconds 3
        break
    }

    # Parse and validate choices
    $choices = $userChoice -split '[ ,]+' | Where-Object { $_ -ne '' }
    $scriptsToRun = [System.Collections.Generic.List[object]]::new()
    $invalidChoices = [System.Collections.Generic.List[string]]::new()

    foreach ($choice in $choices) {
        if (($choice -match '^\d+$') -and ([int]$choice -ge 1) -and ([int]$choice -le $allScripts.Count)) {
            $scriptsToRun.Add($allScripts[[int]$choice - 1])
        }
        else {
            $invalidChoices.Add($choice)
        }
    }

    # Handle invalid choices
    if ($invalidChoices.Count -gt 0) {
        Write-StyledMessage -type 'Warning' -text "Opzioni non valide ignorate: $($invalidChoices -join ', ')"
        Start-Sleep -Seconds 2
    }

    # Execute valid scripts
    if ($scriptsToRun.Count -gt 0) {
        $executedCount = 0
        $errorCount = 0

        foreach ($selectedItem in $scriptsToRun) {
            Write-Host "`n" + ('-' * ($width / 2))
            Write-StyledMessage -type 'Info' -text "Avvio '$($selectedItem.Description)'..."

            try {
                if ($selectedItem.Action -eq 'RunFile') {
                    $scriptPath = Join-Path $PSScriptRoot $selectedItem.Name
                    if (Test-Path $scriptPath) { & $scriptPath }
                    else { Write-StyledMessage -type 'Error' -text "Script non trovato: $($selectedItem.Name)" }
                }
                elseif ($selectedItem.Action -eq 'RunFunction') {
                    Invoke-Expression $selectedItem.Name
                }
            }
            catch {
                Write-StyledMessage -type 'Error' -text "Errore in '$($selectedItem.Description)'"
                Write-StyledMessage -type 'Error' -text "Dettagli: $($_.Exception.Message)"
            }
            Write-StyledMessage -type 'Success' -text "Completato: '$($selectedItem.Description)'"
        }

        Write-Host "`nOperazioni completate. Premi un tasto per continuare..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

        # Summary
        if ($errorCount -eq 0) {
            Write-StyledMessage -type 'Success' -text "🎉 Tutte le operazioni completate con successo! ($executedCount/$executedCount)"
        }
        else {
            Write-StyledMessage -type 'Warning' -text "⚠️ $executedCount operazioni completate, $errorCount errori"
        }
    }
    elseif ($invalidChoices.Count -eq $choices.Count) {
        Write-StyledMessage -type 'Error' -text 'Nessuna scelta valida. Riprova.'
        Start-Sleep -Seconds 2
    }
}
