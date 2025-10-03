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

    # Setup logging specifico per OfficeToolkit
    $dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logdir = "$env:LOCALAPPDATA\WinToolkit\logs"
    try {
        if (-not (Test-Path -Path $logdir)) {
            New-Item -Path $logdir -ItemType Directory -Force | Out-Null
        }
        Start-Transcript -Path "$logdir\OfficeToolkit_$dateTime.log" -Append -Force | Out-Null
    }
    catch {}

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
        $bar = "[$('█' * $filled)$('░' * (30 - $filled))] $safePercent%"
        Write-Host "`r📊 $Activity $bar $Status" -NoNewline -ForegroundColor Yellow
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
            $bar = "[$('█' * $filled)$('░' * $remaining)] $percent%"

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

    function Test-DotNetFramework481 {
        try {
            $release = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction Stop).Release
            return $release -ge 533320
        }
        catch {
            return $false
        }
    }

    function Install-DotNetFramework481 {
        Write-StyledMessage Info "🔧 Verifica .NET Framework 4.8.1..."

        if (Test-DotNetFramework481) {
            Write-StyledMessage Success ".NET Framework 4.8.1 già installato"
            return $true
        }

        Write-StyledMessage Warning ".NET Framework 4.8.1 non trovato"
        Write-StyledMessage Info "📦 Preparazione installazione .NET Framework 4.8.1 per SaRA..."

        if (-not (Test-Path $TempDir)) {
            New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
        }

        $dotnetInstaller = Join-Path $TempDir 'ndp481-x86-x64-allos-enu.exe'
        $installed = $false

        # Metodo 1: Winget
        Write-StyledMessage Info "🎯 Tentativo installazione tramite Winget..."
        try {
            $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
            if ($wingetPath) {
                $process = Start-Process -FilePath "winget" -ArgumentList "install --id Microsoft.DotNet.Framework.DeveloperPack_4 --silent --accept-package-agreements --accept-source-agreements" -Wait -PassThru -NoNewWindow
                
                Start-Sleep -Seconds 5
                
                if (Test-DotNetFramework481) {
                    Write-StyledMessage Success "✅ .NET Framework 4.8.1 installato tramite Winget"
                    $installed = $true
                }
            }
            else {
                Write-StyledMessage Warning "Winget non disponibile"
            }
        }
        catch {
            Write-StyledMessage Warning "Errore Winget: $_"
        }

        # Metodo 2: Download diretto
        if (-not $installed) {
            Write-StyledMessage Info "📥 Download diretto .NET Framework 4.8.1..."
            
            $dotnetUrl = 'https://go.microsoft.com/fwlink/?linkid=2203306'
            
            if (Invoke-DownloadFile $dotnetUrl $dotnetInstaller '.NET Framework 4.8.1') {
                Write-StyledMessage Info "🚀 Avvio installazione .NET Framework 4.8.1..."
                Write-StyledMessage Warning "⏳ L'installazione può richiedere diversi minuti..."
                
                try {
                    $process = Start-Process -FilePath $dotnetInstaller -ArgumentList "/q /norestart" -Wait -PassThru
                    
                    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                        Write-StyledMessage Success "✅ .NET Framework 4.8.1 installato"
                        $installed = $true
                        
                        if ($process.ExitCode -eq 3010) {
                            Write-StyledMessage Warning "⚠️ Riavvio necessario per completare l'installazione"
                        }
                    }
                    else {
                        Write-StyledMessage Warning "Codice uscita installazione: $($process.ExitCode)"
                    }
                }
                catch {
                    Write-StyledMessage Error "Errore durante installazione: $_"
                }
            }
        }

        # Verifica finale
        Start-Sleep -Seconds 2
        if (Test-DotNetFramework481) {
            Write-StyledMessage Success "🎉 .NET Framework 4.8.1 pronto"
            return $true
        }
        else {
            Write-StyledMessage Error "Impossibile installare .NET Framework 4.8.1"
            Write-StyledMessage Info "💡 Installazione manuale necessaria da: https://dotnet.microsoft.com/download/dotnet-framework/net481"
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

            if (Get-UserConfirmation "✅ Riparazione completata con successo?" 'Y') {
                Write-StyledMessage Success "🎉 Riparazione Office completata!"
                return $true
            }
            else {
                Write-StyledMessage Warning "Riparazione non completata correttamente"
                if ($choice -eq '1') {
                    if (Get-UserConfirmation "🌐 Tentare riparazione completa online?" 'Y') {
                        Write-StyledMessage Info "🌐 Avvio riparazione completa..."
                        $arguments = "scenario=Repair platform=x64 culture=it-it forceappshutdown=True RepairType=FullRepair DisplayLevel=True"
                        Start-Process -FilePath $officeClient -ArgumentList $arguments -Wait:$false

                        Write-Host "💡 Premi INVIO quando la riparazione completa è terminata..." -ForegroundColor Yellow
                        Read-Host | Out-Null

                        return Get-UserConfirmation "✅ Riparazione completa riuscita?" 'Y'
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
        Write-StyledMessage Warning "🗑️ Rimozione completa Microsoft Office"

        if (-not (Get-UserConfirmation "❓ Procedere con la rimozione completa?")) {
            Write-StyledMessage Info "❌ Operazione annullata"
            return $false
        }

        Stop-OfficeProcesses

        # Prima tenta con SaRA
        $saraSuccess = Start-OfficeUninstallWithSaRA

        if ($saraSuccess) {
            Write-StyledMessage Success "🎉 Rimozione Office completata con SaRA!"
            return $true
        }
        else {
            Write-StyledMessage Warning "SaRA non riuscito, tentativo con metodo alternativo..."

            # Fallback al metodo Click-to-Run
            $clickToRunSuccess = Start-OfficeUninstallClickToRun

            if ($clickToRunSuccess) {
                Write-StyledMessage Success "🎉 Rimozione Office completata con Click-to-Run!"
                return $true
            }
            else {
                Write-StyledMessage Error "Entrambi i metodi di rimozione non riusciti"
                Write-StyledMessage Info "💡 Rimozione manuale necessaria tramite Impostazioni > App > Office"
                return $false
            }
        }
    }

    function Repair-SaRAConfig([string]$ConfigPath) {
        try {
            Write-StyledMessage Info "🔧 Correzione configurazione SaRA per compatibilità..."
            
            $configContent = @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <startup>
    <supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.8.1"/>
  </startup>
  <system.diagnostics>
    <sources>
      <source name="SaRATraceSource" switchValue="All">
        <listeners>
          <add name="console"/>
        </listeners>
      </source>
    </sources>
    <sharedListeners>
      <add name="console" type="System.Diagnostics.ConsoleTraceListener"/>
    </sharedListeners>
  </system.diagnostics>
</configuration>
'@
            
            Set-Content -Path $ConfigPath -Value $configContent -Encoding UTF8 -Force
            Write-StyledMessage Success "Configurazione SaRA corretta"
            return $true
        }
        catch {
            Write-StyledMessage Warning "Impossibile correggere configurazione: $_"
            return $false
        }
    }

    function Start-OfficeUninstallWithSaRA {
        try {
            # Installa .NET Framework 4.8.1 se necessario
            if (-not (Install-DotNetFramework481)) {
                Write-StyledMessage Error ".NET Framework 4.8.1 richiesto per SaRA non disponibile"
                return $false
            }

            # Riavvio dopo installazione .NET se necessario
            if (-not (Test-DotNetFramework481)) {
                Write-StyledMessage Warning "🔄 Riavvio necessario per completare configurazione .NET Framework"
                if (Start-CountdownRestart ".NET Framework 4.8.1 installato") {
                    return $false
                }
            }

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

            $saraExe = Get-ChildItem -Path $TempDir -Filter "SaRAcmd.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $saraExe) {
                Write-StyledMessage Error "SaRAcmd.exe non trovato"
                return $false
            }

            # Correggi configurazione SaRA per Windows 11 22H2
            $configPath = "$($saraExe.FullName).config"
            if (Test-Path $configPath) {
                Repair-SaRAConfig -ConfigPath $configPath
            }

            Write-StyledMessage Info "🚀 Avvio rimozione tramite SaRA..."
            Write-StyledMessage Warning "⏰ Questa operazione può richiedere molto tempo"
            Write-StyledMessage Warning "🚫 Non chiudere la finestra di SaRA, si chiuderà automaticamente"

            $arguments = '-S OfficeScrubScenario -AcceptEula -OfficeVersion All'
            $process = Start-Process -FilePath $saraExe.FullName -ArgumentList $arguments -Verb RunAs -PassThru -ErrorAction Stop

            Start-Sleep -Seconds 5

            if ($process.HasExited -and $process.ExitCode -ne 0) {
                Write-StyledMessage Warning "SaRA terminato con codice errore: $($process.ExitCode)"
                return $false
            }

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
            Write-StyledMessage Warning "Errore durante SaRA: $_"
            return $false
        }
        finally {
            if (Test-Path $TempDir) {
                Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    function Start-OfficeUninstallClickToRun {
        Write-StyledMessage Info "🔧 Tentativo rimozione tramite Office Click-to-Run..."

        try {
            $officeClient = Get-OfficeClient
            if (-not $officeClient) {
                Write-StyledMessage Error "Office Click-to-Run non trovato"
                return $false
            }

            Write-StyledMessage Info "🎯 Selezione metodo di rimozione:"
            Write-Host "  [1] 🗑️ Disinstallazione completa" -ForegroundColor Red
            Write-Host "  [2] 🔧 Rimozione prodotti Office" -ForegroundColor Yellow

            do {
                $choice = Read-Host "Scelta [1-2]"
            } while ($choice -notin @('1', '2'))

            switch ($choice) {
                '1' {
                    Write-StyledMessage Info "🗑️ Avvio disinstallazione completa..."
                    $arguments = "scenario=Uninstall platform=x64 culture=it-it forceappshutdown=True DisplayLevel=True"
                }
                '2' {
                    Write-StyledMessage Info "🔧 Avvio rimozione prodotti Office..."
                    $arguments = "scenario=RemoveProducts platform=x64 culture=it-it forceappshutdown=True DisplayLevel=True"
                }
            }

            Start-Process -FilePath $officeClient -ArgumentList $arguments -Wait:$false

            Write-Host "💡 Premi INVIO quando la rimozione è completata..." -ForegroundColor Yellow
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
            Write-StyledMessage Error "Errore durante rimozione Click-to-Run: $_"
            return $false
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
            '        Version 2.3 (Build 8)'
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
        try { Stop-Transcript | Out-Null } catch {}
    }
}

OfficeToolkit