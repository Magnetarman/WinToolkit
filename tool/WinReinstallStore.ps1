function WinReinstallStore {
    <#
    .SYNOPSIS
        Reinstalla automaticamente il Microsoft Store su Windows 10/11 utilizzando Winget.
    
    .DESCRIPTION
        Script ottimizzato per reinstallare Winget, Microsoft Store e UniGet UI senza output bloccanti.
    #>
    
    param([int]$CountdownSeconds = 30)
    
    # Inizializzazione
    $Host.UI.RawUI.WindowTitle = "Store Repair Toolkit By MagnetarMan"
    
    # Configurazione globale
    $MsgStyles = @{
        Success = @{ Color = 'Green'; Icon = '✅' }; Warning = @{ Color = 'Yellow'; Icon = '⚠️' }
        Error = @{ Color = 'Red'; Icon = '❌' }; Info = @{ Color = 'Cyan'; Icon = '💎' }
        Progress = @{ Color = 'Magenta'; Icon = '🔄' }
    }
    
    # Funzione per centrare il testo
    function Center-Text {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Text,
            [Parameter(Mandatory = $false)]
            [int]$Width = $Host.UI.RawUI.BufferSize.Width # Usa la larghezza dinamica di default
        )
    
        # Calcola il padding necessario
        $padding = [Math]::Max(0, [Math]::Floor(($Width - $Text.Length) / 2))
    
        # Restituisce la stringa centrata
        return (' ' * $padding + $Text)
    }

    #---

    # Funzione principale che mostra l'header
    function Show-Header {
        Clear-Host
    
        # Ottiene la larghezza della finestra della console in tempo reale
        $width = $Host.UI.RawUI.BufferSize.Width
    
        # Disegna la linea superiore adattandola alla larghezza
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    
        $asciiArt = @(
            '      __        __  _  _   _ ',
            '      \ \      / / | || \ | |',
            '       \ \ /\ / /  | ||  \| |',
            '        \ V  V /   | || |\  |',
            '         \_/\_/    |_||_| \_|',
            '',
            ' Store Repair Toolkit By MagnetarMan',
            '       Version 2.2 (Build 27)'
        )
    
        foreach ($line in $asciiArt) {
            # Chiama la funzione Center-Text e le passa la larghezza dinamica
            Write-Host (Center-Text -Text $line -Width $width) -ForegroundColor White
        }
    
        # Disegna la linea inferiore
        Write-Host ('═' * ($width - 1)) -ForegroundColor Green
        Write-Host ''
    }
    function Write-StyledMessage([string]$Type, [string]$Text) {
        $style = $MsgStyles[$Type]
        Write-Host "$($style.Icon) $Text" -ForegroundColor $style.Color
    }
    
    function Clear-Terminal {
        # Pulizia aggressiva multi-metodo
        1..50 | ForEach-Object { Write-Host "" }  # Forza scroll
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
        
        try {
            # Metodo 1: Repair se disponibile (Windows 11 24H2+)
            if ([System.Environment]::OSVersion.Version.Build -ge 26100) {
                try {
                    if (Get-Command Repair-WinGetPackageManager -ErrorAction SilentlyContinue) {
                        $null = Repair-WinGetPackageManager -Force -Latest 2>$null
                        Start-Sleep 5
                        if (Test-WingetAvailable) { return $true }
                    }
                }
                catch {}
            }
            
            # Metodo 2: Download diretto con esecuzione completamente nascosta
            $url = "https://aka.ms/getwinget"
            $temp = "$env:TEMP\WingetInstaller.msixbundle"
            if (Test-Path $temp) { Remove-Item $temp -Force }
            
            Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing
            
            # Esecuzione in subprocess completamente isolato
            $process = Start-Process powershell -ArgumentList @(
                "-NoProfile", "-WindowStyle", "Hidden", "-Command",
                "try { Add-AppxPackage -Path '$temp' -ForceApplicationShutdown -ErrorAction Stop } catch { exit 1 }; exit 0"
            ) -Wait -PassThru -WindowStyle Hidden
            
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
            Start-Sleep 5
            
            return (Test-WingetAvailable)
        }
        catch {
            return $false
        }
    }
    
    function Install-MicrosoftStoreSilent {
        Write-StyledMessage Progress "Reinstallazione Microsoft Store in corso..."
        
        # Reset servizi
        @("AppXSvc", "ClipSVC", "WSService") | ForEach-Object {
            try { Restart-Service $_ -Force -ErrorAction SilentlyContinue } catch {}
        }
        
        # Pulizia cache
        @("$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_*\LocalCache",
            "$env:LOCALAPPDATA\Microsoft\Windows\INetCache") | ForEach-Object {
            if (Test-Path $_) { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue }
        }
        
        # Metodi di installazione
        $methods = @(
            # Winget
            {
                if (Test-WingetAvailable) {
                    $process = Start-Process winget -ArgumentList "install 9WZDNCRFJBMP --accept-source-agreements --accept-package-agreements --silent --disable-interactivity" -Wait -PassThru -WindowStyle Hidden
                    return $process.ExitCode -eq 0
                }
                return $false
            },
            # Manifest
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
            # DISM
            {
                $process = Start-Process DISM -ArgumentList "/Online /Add-Capability /CapabilityName:Microsoft.WindowsStore~~~~0.0.1.0" -Wait -PassThru -WindowStyle Hidden
                return $process.ExitCode -eq 0
            }
        )
        
        foreach ($method in $methods) {
            try {
                if (& $method) {
                    Start-Process wsreset.exe -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                    return $true
                }
            }
            catch { continue }
        }
        return $false
    }
    
    function Install-UniGetUISilent {
        Write-StyledMessage Progress "Reinstallazione UniGet UI in corso..."
        if (-not (Test-WingetAvailable)) { return $false }
        
        try {
            # Disinstalla se presente
            $null = Start-Process winget -ArgumentList "uninstall --exact --id MartiCliment.UniGetUI --silent --disable-interactivity" -Wait -PassThru -WindowStyle Hidden
            Start-Sleep 2
            
            # Installa sempre
            $process = Start-Process winget -ArgumentList "install --exact --id MartiCliment.UniGetUI --source winget --accept-source-agreements --accept-package-agreements --silent --disable-interactivity --force" -Wait -PassThru -WindowStyle Hidden
            return $process.ExitCode -eq 0
        }
        catch {
            return $false
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
            
            # Barra di progressione countdown identica al riferimento
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
    
    # === ESECUZIONE PRINCIPALE ===
    Show-Header
    Write-StyledMessage Info "🚀 AVVIO REINSTALLAZIONE STORE"
    
    try {
        # FASE 1: Winget
        Write-StyledMessage Info "📋 FASE 1: Winget"
        $wingetResult = Install-WingetSilent
        Clear-Terminal
        Show-Header
        Write-StyledMessage $(if ($wingetResult) { 'Success' }else { 'Warning' }) "$(if($wingetResult){'✅'}else{'⚠️'}) Winget $(if($wingetResult){'installato'}else{'processato'})"
        
        # FASE 2: Microsoft Store  
        Write-StyledMessage Info "📋 FASE 2: Microsoft Store"
        $storeResult = Install-MicrosoftStoreSilent
        if (-not $storeResult) {
            Write-StyledMessage Error "❌ Errore installazione Microsoft Store"
            Write-StyledMessage Info "💡 Verifica: Internet, Admin, Windows Update"
            return
        }
        Write-StyledMessage Success "✅ Microsoft Store installato"
        
        # FASE 3: UniGet UI
        Write-StyledMessage Info "📋 FASE 3: UniGet UI" 
        $unigetResult = Install-UniGetUISilent
        Write-StyledMessage $(if ($unigetResult) { 'Success' }else { 'Warning' }) "$(if($unigetResult){'✅'}else{'⚠️'}) UniGet UI $(if($unigetResult){'installato'}else{'processato'})"
        
        # Completamento
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

WinReinstallStore