function Uninstall-Office {
    <#
    .SYNOPSIS
        Rimuove completamente Microsoft Office. Usa Get Help su Win11 23H2+, rimozione diretta su versioni precedenti.
    .PARAMETER CountdownSeconds
        Secondi per il countdown prima del riavvio.
    #>
    [CmdletBinding()]
    param(
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "OfficeUninstall" -SubTitle "Office Uninstall"

    $tempDir = $AppConfig.Paths.OfficeTemp

    # ============================================================================
    # FUNZIONI HELPER SPECIFICHE PER UNINSTALL
    # ============================================================================

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

    function Remove-ItemsSilently {
        param([string[]]$Paths, [string]$ItemType = "cartella")
        $removed = @()
        $failed  = @()
        foreach ($path in $Paths) {
            if (Test-Path $path) {
                if (Remove-ItemSafely -Path $path -Recurse) { $removed += $path }
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
            foreach ($keyPath in @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )) {
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
                        Stop-Service  -Name $serviceName -Force -ErrorAction Stop
                        Set-Service   -Name $serviceName -StartupType Disabled -ErrorAction Stop
                        Write-StyledMessage -Type 'Success' -Text "Servizio arrestato: $serviceName."
                        $stoppedServices++
                    }
                    catch {}
                }
            }

            Write-StyledMessage -Type 'Info' -Text "🧹 Pulizia cartelle Office."
            $folderResult = Remove-ItemsSilently -Paths @(
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
            ) -ItemType "cartella"
            if ($folderResult.Count -gt 0)        { Write-StyledMessage -Type 'Success' -Text "$($folderResult.Count) cartelle Office rimosse." }
            if ($folderResult.Failed.Count -gt 0)  { Write-StyledMessage -Type 'Warning' -Text "Impossibile rimuovere $($folderResult.Failed.Count) cartelle (potrebbero essere in uso)." }

            Write-StyledMessage -Type 'Info' -Text "🔧 Pulizia registro Office."
            $regResult = Remove-ItemsSilently -Paths @(
                "HKCU:\Software\Microsoft\Office",
                "HKLM:\SOFTWARE\Microsoft\Office",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office",
                "HKCU:\Software\Microsoft\Office\16.0",
                "HKLM:\SOFTWARE\Microsoft\Office\16.0",
                "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun"
            ) -ItemType "chiave"
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
            $shortcutsRemoved = 0
            foreach ($desktopPath in @(
                $AppConfig.Paths.Desktop,
                "$env:PUBLIC\Desktop",
                "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
                "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs"
            )) {
                if (Test-Path $desktopPath) {
                    foreach ($shortcut in @(
                        "Microsoft Word*.lnk", "Microsoft Excel*.lnk", "Microsoft PowerPoint*.lnk",
                        "Microsoft Outlook*.lnk", "Microsoft OneNote*.lnk", "Microsoft Access*.lnk",
                        "Office*.lnk", "Word*.lnk", "Excel*.lnk", "PowerPoint*.lnk", "Outlook*.lnk"
                    )) {
                        foreach ($file in (Get-ChildItem -Path $desktopPath -Filter $shortcut -Recurse -ErrorAction SilentlyContinue)) {
                            if (Remove-ItemSafely -Path $file.FullName) { $shortcutsRemoved++ }
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

    function Start-OfficeUninstallWithGetHelp {
        try {
            if (-not (Test-Path $tempDir)) { $null = New-Item -ItemType Directory -Path $tempDir -Force }

            $getHelpZipPath = Join-Path $tempDir 'GetHelp.zip'
            if (-not (Invoke-ToolkitDownload -Uri $AppConfig.URLs.GetHelpInstaller -OutputPath $getHelpZipPath -Description 'Microsoft Get Help')) {
                return $false
            }

            Write-StyledMessage -Type 'Info' -Text "📦 Estrazione Get Help."
            try {
                Expand-Archive -Path $getHelpZipPath -DestinationPath $tempDir -Force
                Write-StyledMessage -Type 'Success' -Text "Estrazione completata."
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "Errore durante estrazione archivio Get Help: $($_.Exception.Message)."
                return $false
            }

            $getHelpExe = Get-ChildItem -Path $tempDir -Filter "GetHelpCmd.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $getHelpExe) {
                Write-StyledMessage -Type 'Error' -Text "GetHelpCmd.exe non trovato."
                return $false
            }

            Write-StyledMessage -Type 'Info' -Text "🚀 Rimozione tramite Get Help."
            Write-StyledMessage -Type 'Warning' -Text "⏰ Questa operazione può richiedere alcuni minuti."

            try {
                $result = Invoke-WithSpinner -Activity "Rimozione Office tramite Get Help" -Command $getHelpExe.FullName `
                    -Arguments '-S OfficeScrubScenario -AcceptEula' `
                    -TimeoutSeconds 86400 -LogContextKey "Office-Uninstall-GetHelp"

                $outputStr    = $result.StdOut + $result.StdErr
                $isInvalidArgs = $outputStr -match "Error: Invalid command line arguments" -or $outputStr -match "Usage: GetHelpCmd\.exe"

                if ($result.ExitCode -eq 0 -and -not $isInvalidArgs) {
                    $blockingProcesses = @('Setup', 'GetHelpCmd', 'OfficeClickToRun', 'Integrator', 'OfficeScrub', 'cscript')
                    $waitStart         = Get-Date
                    Start-Sleep -Seconds 12

                    if (Get-Process -Name $blockingProcesses -ErrorAction SilentlyContinue) {
                        Write-StyledMessage -Type 'Info' -Text "⏳ Get Help ha avviato la rimozione in una finestra esterna. Attesa completamento..."
                        $spinnerIndex = 0
                        while ((Get-Process -Name $blockingProcesses -ErrorAction SilentlyContinue) -and ((Get-Date) - $waitStart).TotalSeconds -lt 2700) {
                            $elapsed = [math]::Round(((Get-Date) - $waitStart).TotalSeconds, 1)
                            $spinner = if ($Global:Spinners) { $Global:Spinners[$spinnerIndex++ % $Global:Spinners.Length] } else { '' }
                            Show-ProgressBar -Activity "Rimozione Office" -Status "In corso... ($elapsed secondi)" -Percent 90 -Icon '⏳' -Spinner $spinner
                            Start-Sleep -Milliseconds 500
                        }
                        Clear-ProgressLine
                    }

                    Write-StyledMessage -Type 'Success' -Text "✅ Get Help completato con successo."
                    return $true
                }
                else {
                    $reason = if ($isInvalidArgs) { "Parametri non supportati dalla versione del tool" } else { "Codice uscita: $($result.ExitCode)" }
                    Write-StyledMessage -Type 'Warning' -Text "Get Help fallito: $reason. Tentativo metodo alternativo."
                    return Remove-OfficeDirectly
                }
            }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "Errore durante esecuzione Get Help: $($_.Exception.Message). Passaggio a metodo alternativo."
                return Remove-OfficeDirectly
            }
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text "Errore durante processo Get Help: $($_.Exception.Message)."
            return $false
        }
        finally {
            Remove-ItemSafely -Path $tempDir -Recurse
        }
    }

    # ============================================================================
    # ESECUZIONE PRINCIPALE
    # ============================================================================

    $needsReboot = $false

    try {
        Write-StyledMessage -Type 'Warning' -Text "🗑️ Avvio rimozione completa Microsoft Office."
        Stop-ToolkitProcesses -ProcessNames @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')

        Write-StyledMessage -Type 'Info' -Text "🔍 Rilevamento versione Windows."
        $windowsVersion = Get-WindowsVersion
        Write-StyledMessage -Type 'Info' -Text "🎯 Versione rilevata: $windowsVersion."

        $success = switch ($windowsVersion) {
            'Windows11_23H2_Plus' {
                Write-StyledMessage -Type 'Info' -Text "🚀 Utilizzo metodo Get Help per Windows 11 23H2+."
                Start-OfficeUninstallWithGetHelp
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
        Remove-ItemSafely -Path $tempDir -Recurse
        Write-StyledMessage -Type 'Success' -Text "🎯 Office Uninstall terminato."
        Write-ToolkitLog -Level INFO -Message "Uninstall-Office sessione terminata."
    }

    if ($needsReboot) {
        Invoke-ToolkitReboot -Message "Rimozione completata" -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
    }
}
