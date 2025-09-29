function Restore-WebSearch {
    <#
   .SYNOPSIS
       Script per il ripristino della ricerca web su Windows 10/11.

   .DESCRIPTION
       Questo script esegue una serie di operazioni per ripristinare la funzionalità di ricerca web:
       - Correzione chiavi di registro che bloccano la ricerca web
       - Controllo del file hosts per eventuali blocchi di Bing o Microsoft
       - Reset della cache DNS per eliminare eventuali blocchi
       - Reinstallazione di Cortana/SearchUI
       - Riavvio del servizio Windows Search
       Al termine, richiede un riavvio del sistema per applicare completamente le modifiche.
   #>

    param([int]$CountdownSeconds = 30)

    $Host.UI.RawUI.WindowTitle = "Web Search Restore By MagnetarMan"
    $script:Log = @(); $script:CurrentAttempt = 0
    $spinners = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.ToCharArray()
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }
        Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error   = @{ Color = 'Red'; Icon = '❌' }
        Info    = @{ Color = 'Cyan'; Icon = '💎' }
    }

    $SearchTasks = @(
        @{ Task = 'RegistryFix'; Name = 'Correzione chiavi registro'; Icon = '🔧' }
        @{ Task = 'HostsCheck'; Name = 'Controllo file hosts'; Icon = '📄' }
        @{ Task = 'DnsFlush'; Name = 'Reset cache DNS'; Icon = '🌐' }
        @{ Task = 'CortanaReinstall'; Name = 'Reinstallazione Cortana/SearchUI'; Icon = '📱' }
        @{ Task = 'ServiceRestart'; Name = 'Riavvio servizio Windows Search'; Icon = '🔄' }
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

    function Invoke-RegistryFix {
        Write-StyledMessage Info "🔧 Correzione chiavi registro ricerca web..."
        $percent = 0; $spinnerIndex = 0

        try {
            $regPaths = @(
                "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer",
                "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
            )

            $keysFixed = 0
            foreach ($path in $regPaths) {
                if (Test-Path $path) {
                    $keys = @("DisableSearchBoxSuggestions", "DisableWebSearch")
                    foreach ($key in $keys) {
                        try {
                            $existingValue = Get-ItemProperty -Path $path -Name $key -ErrorAction SilentlyContinue
                            if ($existingValue) {
                                Set-ItemProperty -Path $path -Name $key -Value 0 -ErrorAction SilentlyContinue
                                Write-StyledMessage Info "🔧 Ripristinata chiave: $key in $path"
                                $keysFixed++
                            }
                        }
                        catch {
                            Write-StyledMessage Warning "⚠️ Impossibile modificare $key in $path - $_"
                        }
                    }
                }
            }

            if ($keysFixed -gt 0) {
                Write-StyledMessage Success "✅ Chiavi registro corrette ($keysFixed modifiche)"
                $script:Log += "[RegistryFix] ✅ Correzione completata ($keysFixed chiavi)"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Info "💭 Nessuna chiave registro da correggere"
                $script:Log += "[RegistryFix] ℹ️ Nessuna chiave da correggere"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante correzione registro: $_"
            $script:Log += "[RegistryFix] ❌ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-CortanaReinstall {
        Write-StyledMessage Info "📱 Reinstallazione Cortana/SearchUI..."
        $percent = 0; $spinnerIndex = 0

        try {
            $cortanaPackages = Get-AppxPackage -allusers Microsoft.Windows.Cortana -ErrorAction SilentlyContinue

            if (-not $cortanaPackages) {
                Write-StyledMessage Info "💭 Cortana non presente nel sistema"
                $script:Log += "[CortanaReinstall] ℹ️ Pacchetto Cortana non trovato"
                return @{ Success = $true; ErrorCount = 0 }
            }

            $reinstalled = 0
            foreach ($package in $cortanaPackages) {
                try {
                    Add-AppxPackage -DisableDevelopmentMode -Register "$($package.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
                    Write-StyledMessage Info "📱 Reinstallato: $($package.Name)"
                    $reinstalled++
                }
                catch {
                    Write-StyledMessage Warning "⚠️ Impossibile reinstallare $($package.Name) - $_"
                }
            }

            if ($reinstalled -gt 0) {
                Write-StyledMessage Success "✅ Cortana/SearchUI reinstallati ($reinstalled pacchetti)"
                $script:Log += "[CortanaReinstall] ✅ Reinstallazione completata ($reinstalled pacchetti)"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Warning "⚠️ Impossibile reinstallare i pacchetti Cortana"
                $script:Log += "[CortanaReinstall] ⚠️ Reinstallazione fallita"
                return @{ Success = $false; ErrorCount = 1 }
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante reinstallazione Cortana: $_"
            $script:Log += "[CortanaReinstall] ❌ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-HostsCheck {
        Write-StyledMessage Info "📄 Controllo file hosts per blocchi Microsoft..."
        $percent = 0; $spinnerIndex = 0

        try {
            $hostsPath = "$env:WINDIR\System32\drivers\etc\hosts"
            $hostsContent = Get-Content -Path $hostsPath -ErrorAction SilentlyContinue

            $microsoftDomains = @(
                'www.bing.com', 'bing.com',
                'www.microsoft.com', 'microsoft.com',
                'www.live.com', 'live.com',
                'www.msn.com', 'msn.com',
                'www.outlook.com', 'outlook.com'
            )

            $blockedEntries = @()
            foreach ($line in $hostsContent) {
                $trimmedLine = $line.Trim()
                # Salta commenti e righe vuote
                if ($trimmedLine -and !$trimmedLine.StartsWith('#')) {
                    foreach ($domain in $microsoftDomains) {
                        if ($trimmedLine -like "*$domain*") {
                            $blockedEntries += $trimmedLine
                            break
                        }
                    }
                }
            }

            if ($blockedEntries.Count -gt 0) {
                Write-StyledMessage Warning "⚠️ Trovate $($blockedEntries.Count) voci di blocco Microsoft nel file hosts:"
                foreach ($entry in $blockedEntries) {
                    Write-StyledMessage Warning "   └─ $entry"
                }

                # Crea backup del file hosts originale
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $backupPath = "$env:TEMP\hosts_backup_$timestamp"
                Copy-Item -Path $hostsPath -Destination $backupPath -Force

                # Rimuovi le voci di blocco
                $cleanedContent = @()
                foreach ($line in $hostsContent) {
                    $trimmedLine = $line.Trim()
                    $isBlocked = $false

                    if ($trimmedLine -and !$trimmedLine.StartsWith('#')) {
                        foreach ($domain in $microsoftDomains) {
                            if ($trimmedLine -like "*$domain*") {
                                $isBlocked = $true
                                break
                            }
                        }
                    }

                    if (-not $isBlocked) {
                        $cleanedContent += $line
                    }
                }

                # Salva il file hosts pulito
                $cleanedContent | Set-Content -Path $hostsPath -Force

                Write-StyledMessage Success "✅ Rimosse $($blockedEntries.Count) voci di blocco Microsoft dal file hosts"
                Write-StyledMessage Info "💾 Backup creato: $backupPath"
                $script:Log += "[HostsCheck] ✅ Rimosse $($blockedEntries.Count) voci di blocco Microsoft"
                return @{ Success = $true; ErrorCount = 0 }
            }
            else {
                Write-StyledMessage Success "✅ Nessun blocco Microsoft trovato nel file hosts"
                $script:Log += "[HostsCheck] ✅ Nessun blocco rilevato"
                return @{ Success = $true; ErrorCount = 0 }
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante controllo file hosts: $_"
            $script:Log += "[HostsCheck] ❌ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-DnsFlush {
        Write-StyledMessage Info "🌐 Reset cache DNS di sistema..."
        $percent = 0; $spinnerIndex = 0

        try {
            # Reset cache DNS
            ipconfig /flushdns | Out-Null

            # Registra di nuovo DNS
            ipconfig /registerdns | Out-Null

            # Rinnova lease DHCP
            ipconfig /renew | Out-Null

            Write-StyledMessage Success "✅ Cache DNS resettata con successo"
            Write-StyledMessage Info "💡 DNS registrato e lease DHCP rinnovato"
            $script:Log += "[DnsFlush] ✅ Reset cache DNS completato"
            return @{ Success = $true; ErrorCount = 0 }
        }
        catch {
            Write-StyledMessage Error "Errore durante reset cache DNS: $_"
            $script:Log += "[DnsFlush] ❌ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-ServiceRestart {
        Write-StyledMessage Info "🔄 Riavvio servizio Windows Search..."
        $percent = 0; $spinnerIndex = 0

        try {
            # Verifica se il servizio esiste
            $service = Get-Service -Name "WSearch" -ErrorAction SilentlyContinue
            if (-not $service) {
                Write-StyledMessage Warning "⚠️ Servizio Windows Search non trovato"
                $script:Log += "[ServiceRestart] ⚠️ Servizio WSearch non trovato"
                return @{ Success = $false; ErrorCount = 1 }
            }

            # Ferma il servizio
            try {
                Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }
            catch {
                Write-StyledMessage Warning "⚠️ Impossibile fermare il servizio WSearch - $_"
            }

            # Riavvia il servizio
            try {
                Restart-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
                Write-StyledMessage Success "✅ Servizio Windows Search riavviato"
                $script:Log += "[ServiceRestart] ✅ Riavvio completato"
                return @{ Success = $true; ErrorCount = 0 }
            }
            catch {
                Write-StyledMessage Warning "⚠️ Impossibile riavviare il servizio WSearch - $_"
                $script:Log += "[ServiceRestart] ⚠️ Riavvio fallito"
                return @{ Success = $false; ErrorCount = 1 }
            }
        }
        catch {
            Write-StyledMessage Error "Errore durante riavvio servizio: $_"
            $script:Log += "[ServiceRestart] ❌ Errore: $_"
            return @{ Success = $false; ErrorCount = 1 }
        }
    }

    function Invoke-SearchTask([hashtable]$Task, [int]$Step, [int]$Total) {
        Write-StyledMessage Info "[$Step/$Total] Avvio $($Task.Name)..."
        $percent = 0; $spinnerIndex = 0

        try {
            $result = switch ($Task.Task) {
                'RegistryFix' { Invoke-RegistryFix }
                'HostsCheck' { Invoke-HostsCheck }
                'DnsFlush' { Invoke-DnsFlush }
                'CortanaReinstall' { Invoke-CortanaReinstall }
                'ServiceRestart' { Invoke-ServiceRestart }
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
            '    Web Search Restore By MagnetarMan',
            '       Version 2.0 (Build 1)'
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
        Write-StyledMessage Info '🔍 Avvio ripristino ricerca web...'
        Write-Host ''

        $totalErrors = $successCount = 0
        for ($i = 0; $i -lt $SearchTasks.Count; $i++) {
            $result = Invoke-SearchTask $SearchTasks[$i] ($i + 1) $SearchTasks.Count
            if ($result.Success) { $successCount++ }
            $totalErrors += $result.ErrorCount
            Start-Sleep 1
        }

        Write-Host ''
        Write-Host ('═' * 65) -ForegroundColor Green
        Write-StyledMessage Success "🎉 Ripristino ricerca web completato!"
        Write-StyledMessage Success "🔍 Completati $successCount/$($SearchTasks.Count) task di ripristino"

        if ($totalErrors -gt 0) {
            Write-StyledMessage Warning "⚠️ $totalErrors errori durante il ripristino"
        }

        Write-StyledMessage Info "🔄 Il sistema verrà riavviato per applicare completamente le modifiche"
        Write-Host ('═' * 65) -ForegroundColor Green
        Write-Host ''

        $shouldReboot = Start-InterruptibleCountdown $CountdownSeconds "Preparazione riavvio sistema"

        if ($shouldReboot) {
            Write-StyledMessage Info "🔄 Riavvio in corso..."
            Restart-Computer -Force
        }
        else {
            Write-StyledMessage Success "✅ Ripristino completato. Sistema non riavviato."
            Write-StyledMessage Info "💡 Riavvia quando possibile per applicare completamente le modifiche."
        }
    }
    catch {
        Write-Host ''
        Write-Host ('═' * 65) -ForegroundColor Red
        Write-StyledMessage Error "💥 Errore critico: $($_.Exception.Message)"
        Write-StyledMessage Error '❌ Si è verificato un errore durante il ripristino.'
        Write-Host ('═' * 65) -ForegroundColor Red
    }
    finally {
        Write-Host "`nPremi Enter per uscire..." -ForegroundColor Gray
        Read-Host
    }
}

Restore-WebSearch
