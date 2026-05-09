function Uninstall-Office {
    <#
    .SYNOPSIS
        Rimuove completamente Microsoft Office. Usa SaRA su Win11 23H2+, rimozione diretta su versioni precedenti.
    .PARAMETER CountdownSeconds
        Secondi per il countdown prima del riavvio.
    #>
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitLog -ToolName "OfficeUninstall"
    Show-Header -SubTitle "Office Uninstall"
    $Host.UI.RawUI.WindowTitle = "Office Uninstall By MagnetarMan"

    $tempDir = $AppConfig.Paths.OfficeTemp

    # ============================================================================
    # FUNZIONI HELPER
    # ============================================================================

    function Invoke-SilentRemoval {
        param(
            [Parameter(Mandatory = $true)][string]$Path,
            [switch]$Recurse
        )
        if (-not (Test-Path $Path)) { return $false }
        try {
            $params = @{ Path = $Path; Force = $true; ErrorAction = 'SilentlyContinue' }
            if ($Recurse) { $params['Recurse'] = $true }
            Remove-Item @params *>$null
            Clear-ProgressLine
            return $true
        } catch { return $false }
    }

    function Stop-OfficeProcesses {
        $processes = @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')
        $closed = 0

        Write-StyledMessage -Type 'Info' -Text "📋 Chiusura processi Office."
        foreach ($processName in $processes) {
            $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($running) {
                try {
                    $running | Stop-Process -Force -ErrorAction Stop
                    $closed++
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text "Impossibile chiudere: $processName."
                }
            }
        }
        if ($closed -gt 0) { Write-StyledMessage -Type 'Success' -Text "$closed processi Office chiusi." }
    }

    function Get-WindowsVersion {
        try {
            $buildNumber = [int](Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber
            return $buildNumber -ge 22631 ? "Windows11_23H2_Plus" : ($buildNumber -ge 22000 ? "Windows11_22H2_Or_Older" : "Windows10_Or_Older")
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Impossibile rilevare versione Windows: $_"
            return "Unknown"
        }
    }

    function Invoke-DownloadFile([string]$Url, [string]$OutputPath, [string]$Description) {
        try {
            Write-StyledMessage -Type 'Info' -Text "📥 Download $Description."
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($Url, $OutputPath)
            $webClient.Dispose()
            $success = (Test-Path $OutputPath)
            Write-StyledMessage -Type ($success ? 'Success' : 'Error') -Text ($success ? "Download completato: $Description" : "File non trovato dopo download: $Description.")
            return $success
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore download $Description`: $_"
            return $false
        }
    }

    function Remove-ItemsSilently {
        param([string[]]$Paths, [string]$ItemType = "cartella")
        $removed = @()
        $failed  = @()
        foreach ($path in $Paths) {
            if (Test-Path $path) {
                if (Invoke-SilentRemoval -Path $path -Recurse) { $removed += $path }
                else { $failed += $path }
            }
        }
        return @{ Removed = $removed; Failed = $failed; Count = $removed.Count }
    }

    # ============================================================================
    # METODI DI RIMOZIONE
    # ============================================================================

    function Remove-OfficeDirectly {
        Write-StyledMessage -Type 'Info' -Text "🔧 Avvio rimozione diretta Office."

        try {
            Write-StyledMessage -Type 'Info' -Text "📋 Ricerca installazioni Office."
            $officePackages = Get-Package -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "*Microsoft Office*" -or $_.Name -like "*Microsoft 365*" -or $_.Name -like "*Office*" }

            if ($officePackages) {
                Write-StyledMessage -Type 'Info' -Text "Trovati $($officePackages.Count) pacchetti Office."
                foreach ($package in $officePackages) {
                    try {
                        $null = Uninstall-Package -Name $package.Name -Force -ErrorAction Stop
                        Write-StyledMessage -Type 'Success' -Text "Rimosso: $($package.Name)."
                    }
                    catch {}
                }
            }

            Write-StyledMessage -Type 'Info' -Text "🔍 Ricerca nel registro."
            $uninstallKeys = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )
            foreach ($keyPath in $uninstallKeys) {
                try {
                    $items = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue |
                        Where-Object { $_.DisplayName -like "*Office*" -or $_.DisplayName -like "*Microsoft 365*" }
                    foreach ($item in $items) {
                        if ($item.UninstallString -and $item.UninstallString -match "msiexec") {
                            try {
                                $null = Invoke-WithSpinner -Activity "Rimozione: $($item.DisplayName)" -Command 'msiexec.exe' `
                                    -Arguments @('/x', $item.PSChildName, '/qn', '/norestart') -TimeoutSeconds 1800 `
                                    -LogContextKey "Office-Uninstall-MSI-$($item.PSChildName)"
                            }
                            catch {}
                        }
                    }
                }
                catch {}
            }

            Write-StyledMessage -Type 'Info' -Text "🛑 Arresto servizi Office."
            $stoppedServices = 0
            foreach ($serviceName in @('ClickToRunSvc', 'OfficeSvc', 'OSE')) {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($service) {
                    try {
                        Stop-Service -Name $serviceName -Force -ErrorAction Stop
                        Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
                        Write-StyledMessage -Type 'Success' -Text "Servizio arrestato: $serviceName."
                        $stoppedServices++
                    }
                    catch {}
                }
            }

            Write-StyledMessage -Type 'Info' -Text "🧹 Pulizia cartelle Office."
            $foldersToClean = @(
                "$env:ProgramFiles\Microsoft Office",
                "${env:ProgramFiles(x86)}\Microsoft Office",
                "$env:ProgramFiles\Microsoft Office 15",
                "${env:ProgramFiles(x86)}\Microsoft Office 15",
                "$env:ProgramFiles\Microsoft Office 16",
                "${env:ProgramFiles(x86)}\Microsoft Office 16",
                "$env:ProgramData\Microsoft\Office",
                "$env:LOCALAPPDATA\Microsoft\Office",
                "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun",
                "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun"
            )
            $folderResult = Remove-ItemsSilently -Paths $foldersToClean -ItemType "cartella"
            if ($folderResult.Count -gt 0) { Write-StyledMessage -Type 'Success' -Text "$($folderResult.Count) cartelle Office rimosse." }
            if ($folderResult.Failed.Count -gt 0) { Write-StyledMessage -Type 'Warning' -Text "Impossibile rimuovere $($folderResult.Failed.Count) cartelle (potrebbero essere in uso)." }

            Write-StyledMessage -Type 'Info' -Text "🔧 Pulizia registro Office."
            $registryPaths = @(
                "HKCU:\Software\Microsoft\Office",
                "HKLM:\SOFTWARE\Microsoft\Office",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office",
                "HKCU:\Software\Microsoft\Office\16.0",
                "HKLM:\SOFTWARE\Microsoft\Office\16.0",
                "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun"
            )
            $regResult = Remove-ItemsSilently -Paths $registryPaths -ItemType "chiave"
            if ($regResult.Count -gt 0) { Write-StyledMessage -Type 'Success' -Text "$($regResult.Count) chiavi registro Office rimosse." }

            Write-StyledMessage -Type 'Info' -Text "📅 Pulizia attività pianificate."
            $tasksRemoved = 0
            try {
                $officeTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like "*Office*" }
                foreach ($task in $officeTasks) {
                    try { Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop; $tasksRemoved++ }
                    catch {}
                }
                if ($tasksRemoved -gt 0) { Write-StyledMessage -Type 'Success' -Text "$tasksRemoved attività Office rimosse." }
            }
            catch {}

            Write-StyledMessage -Type 'Info' -Text "🖥️ Rimozione collegamenti Office."
            $officeShortcuts = @(
                "Microsoft Word*.lnk", "Microsoft Excel*.lnk", "Microsoft PowerPoint*.lnk",
                "Microsoft Outlook*.lnk", "Microsoft OneNote*.lnk", "Microsoft Access*.lnk",
                "Office*.lnk", "Word*.lnk", "Excel*.lnk", "PowerPoint*.lnk", "Outlook*.lnk"
            )
            $desktopPaths = @(
                $AppConfig.Paths.Desktop,
                "$env:PUBLIC\Desktop",
                "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
                "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs"
            )
            $shortcutsRemoved = 0
            foreach ($desktopPath in $desktopPaths) {
                if (Test-Path $desktopPath) {
                    foreach ($shortcut in $officeShortcuts) {
                        $shortcutFiles = Get-ChildItem -Path $desktopPath -Filter $shortcut -Recurse -ErrorAction SilentlyContinue
                        foreach ($file in $shortcutFiles) {
                            if (Invoke-SilentRemoval -Path $file.FullName) { $shortcutsRemoved++ }
                        }
                    }
                }
            }
            if ($shortcutsRemoved -gt 0) { Write-StyledMessage -Type 'Success' -Text "$shortcutsRemoved collegamenti Office rimossi." }

            Write-StyledMessage -Type 'Info' -Text "💽 Pulizia residui Office."
            $null = Remove-ItemsSilently -Paths @(
                "$env:LOCALAPPDATA\Microsoft\OneDrive",
                "$env:APPDATA\Microsoft\OneDrive",
                "$env:TEMP\Office*",
                "$env:TEMP\MSO*"
            ) -ItemType "residuo"

            Write-StyledMessage -Type 'Success' -Text "✅ Rimozione diretta completata."
            Write-StyledMessage -Type 'Info' -Text "📊 Riepilogo: $($folderResult.Count) cartelle, $($regResult.Count) chiavi registro, $shortcutsRemoved collegamenti, $tasksRemoved attività rimosse."
            return $true
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "Errore durante rimozione diretta Office: $($_.Exception.Message)."
            return $false
        }
    }

    function Start-OfficeUninstallWithSaRA {
        try {
            if (-not (Test-Path $tempDir)) { $null = New-Item -ItemType Directory -Path $tempDir -Force }

            $saraZipPath = Join-Path $tempDir 'SaRA.zip'
            if (-not (Invoke-DownloadFile $AppConfig.URLs.SaRAInstaller $saraZipPath 'Microsoft SaRA')) {
                return $false
            }

            Write-StyledMessage -Type 'Info' -Text "📦 Estrazione SaRA."
            try {
                Expand-Archive -Path $saraZipPath -DestinationPath $tempDir -Force
                Write-StyledMessage -Type 'Success' -Text "Estrazione completata."
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "Errore durante estrazione archivio SaRA: $($_.Exception.Message)."
                return $false
            }

            $saraExe = Get-ChildItem -Path $tempDir -Filter "SaRACmd.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $saraExe) {
                Write-StyledMessage -Type 'Error' -Text "SaRACmd.exe non trovato."
                return $false
            }

            Write-StyledMessage -Type 'Info' -Text "🚀 Rimozione tramite SaRA."
            Write-StyledMessage -Type 'Warning' -Text "⏰ Questa operazione può richiedere alcuni minuti."

            try {
                $result = Invoke-WithSpinner -Activity "Rimozione Office tramite SaRA" -Command $saraExe.FullName `
                    -Arguments '-S OfficeScrubScenario -AcceptEula -OfficeVersion All' `
                    -TimeoutSeconds 86400 -LogContextKey "Office-Uninstall-SaRA"

                if ($result.ExitCode -eq 0) {
                    Write-StyledMessage -Type 'Success' -Text "✅ SaRA completato con successo."
                    return $true
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text "SaRA terminato con codice: $($result.ExitCode)."
                    Write-StyledMessage -Type 'Info' -Text "💡 Tentativo metodo alternativo."
                    return Remove-OfficeDirectly
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Errore durante esecuzione SaRA: $($_.Exception.Message)."
                Write-StyledMessage -Type 'Info' -Text "💡 Passaggio a metodo alternativo."
                return Remove-OfficeDirectly
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Errore durante processo SaRA: $($_.Exception.Message)."
            return $false
        }
        finally {
            Invoke-SilentRemoval -Path $tempDir -Recurse
        }
    }

    # ============================================================================
    # ESECUZIONE PRINCIPALE
    # ============================================================================

    $needsReboot = $false

    try {
        Write-StyledMessage -Type 'Warning' -Text "🗑️ Avvio rimozione completa Microsoft Office."
        Stop-OfficeProcesses

        Write-StyledMessage -Type 'Info' -Text "🔍 Rilevamento versione Windows."
        $windowsVersion = Get-WindowsVersion
        Write-StyledMessage -Type 'Info' -Text "🎯 Versione rilevata: $windowsVersion."

        $success = switch ($windowsVersion) {
            'Windows11_23H2_Plus' {
                Write-StyledMessage -Type 'Info' -Text "🚀 Utilizzo metodo SaRA per Windows 11 23H2+."
                Start-OfficeUninstallWithSaRA
            }
            default {
                Write-StyledMessage -Type 'Info' -Text "⚡ Utilizzo rimozione diretta per Windows 11 22H2 o precedenti."
                Remove-OfficeDirectly
            }
        }

        Write-Progress -Activity "Rimozione" -Completed -ErrorAction SilentlyContinue
        Write-Host ""
        Write-Host ""

        if ($success) {
            Write-StyledMessage -Type 'Success' -Text "🎉 Rimozione Office completata!"
            $needsReboot = $true
        }
        else {
            Write-StyledMessage -Type 'Error' -Text "Rimozione non completata."
            Write-StyledMessage -Type 'Info' -Text "💡 Puoi provare un metodo alternativo o rimozione manuale."
        }
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text "Errore critico durante rimozione Office: $($_.Exception.Message)"
        Write-ToolkitLog -Level ERROR -Message "Errore critico in Uninstall-Office" -Context @{
            Line      = $_.InvocationInfo.ScriptLineNumber
            Exception = $_.Exception.GetType().FullName
            Stack     = $_.ScriptStackTrace
        }
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text "🧹 Pulizia finale."
        Invoke-SilentRemoval -Path $tempDir -Recurse
        Write-StyledMessage -Type 'Success' -Text "🎯 Office Uninstall terminato."
        Write-ToolkitLog -Level INFO -Message "Uninstall-Office sessione terminata."
    }

    if ($needsReboot) {
        if ($SuppressIndividualReboot) {
            $Global:NeedsFinalReboot = $true
            Write-StyledMessage -Type 'Info' -Text "🚫 Riavvio individuale soppresso. Verrà gestito un riavvio finale."
        }
        else {
            if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message "Rimozione completata") {
                Restart-Computer -Force
            }
        }
    }
}
