function WinUpdateReset {
    <#
.SYNOPSIS
    Resetta i componenti di Windows Update.
#>
    param([int]$CountdownSeconds = 15)

    Initialize-ToolLogging -ToolName "WinUpdateReset"
    Show-Header -SubTitle "Update Reset Toolkit"

    function Manage-Service($serviceName, $action, $config, $currentStep, $totalSteps) {
        # Logica originale preservata
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if (-not $service) { return }
            switch ($action) {
                'Stop' { 
                    Show-ProgressBar "Servizi ($currentStep/$totalSteps)" "Arresto $serviceName" 50 '⚙️'
                    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                }
                'Configure' {
                    Set-Service -Name $serviceName -StartupType $config.Type -ErrorAction Stop
                }
                'Start' {
                    Start-Service -Name $serviceName -ErrorAction Stop
                }
            }
        }
        catch { Write-StyledMessage Warning "Errore servizio $serviceName: $_" }
    }

    function Remove-DirectorySafely([string]$path, [string]$displayName) {
        if (-not (Test-Path $path)) { return $true }
        try {
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-StyledMessage Success "🗑️ Directory $displayName eliminata."
            return $true
        }
        catch {
            Write-StyledMessage Warning "Tentativo fallito, provo con robocopy (metodo forzato)..."
            $tempDir = "$env:TEMP\empty_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            Start-Process "robocopy.exe" -ArgumentList "`"$tempDir`" `"$path`" /MIR /NFL /NDL /NJH /NJS /NP /NC" -Wait -WindowStyle Hidden
            Remove-Item $tempDir -Force
            Remove-Item $path -Force
            return (-not (Test-Path $path))
        }
    }

    function Invoke-WPFUpdatesEnable {
        Write-StyledMessage Info '🔧 Inizializzazione ripristino Windows Update...'
        Write-StyledMessage Info '📋 Ripristino impostazioni registro Windows Update...'

        try {
            If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU")) {
                New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force | Out-Null
            }
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Type DWord -Value 0
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Type DWord -Value 3

            If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config")) {
                New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Force | Out-Null
            }
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Type DWord -Value 1

            Write-StyledMessage Success "🔑 Impostazioni registro Windows Update ripristinate."
        }
        catch {
            Write-StyledMessage Warning "Avviso: Impossibile ripristinare alcune chiavi di registro - $($_.Exception.Message)"
        }

        Write-StyledMessage Info '🔧 Ripristino impostazioni WaaSMedicSvc...'

        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "Start" -Type DWord -Value 3 -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "FailureActions" -ErrorAction SilentlyContinue
            Write-StyledMessage Success "⚙️ Impostazioni WaaSMedicSvc ripristinate."
        }
        catch {
            Write-StyledMessage Warning "Avviso: Impossibile ripristinare WaaSMedicSvc - $($_.Exception.Message)"
        }

        Write-StyledMessage Info '🔄 Ripristino servizi di update...'

        $services = @(
            @{Name = "BITS"; StartupType = "Manual"; Icon = "📡" },
            @{Name = "wuauserv"; StartupType = "Manual"; Icon = "🔄" },
            @{Name = "UsoSvc"; StartupType = "Automatic"; Icon = "🚀" },
            @{Name = "uhssvc"; StartupType = "Disabled"; Icon = "⭕" },
            @{Name = "WaaSMedicSvc"; StartupType = "Manual"; Icon = "🛡️" }
        )

        foreach ($service in $services) {
            try {
                Write-StyledMessage Info "$($service.Icon) Ripristino $($service.Name) a $($service.StartupType)..."
                $serviceObj = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
                if ($serviceObj) {
                    Set-Service -Name $service.Name -StartupType $service.StartupType -ErrorAction SilentlyContinue

                    Start-Process -FilePath "sc.exe" -ArgumentList "failure `"$($service.Name)`" reset= 86400 actions= restart/60000/restart/60000/restart/60000" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue

                    if ($service.StartupType -eq "Automatic") {
                        Start-Service -Name $service.Name -ErrorAction SilentlyContinue
                    }

                    Write-StyledMessage Success "$($service.Icon) Servizio $($service.Name) ripristinato."
                }
            }
            catch {
                Write-StyledMessage Warning "Avviso: Impossibile ripristinare servizio $($service.Name) - $($_.Exception.Message)"
            }
        }

        Write-StyledMessage Info '📁 Ripristino DLL rinominate...'

        $dlls = @("WaaSMedicSvc", "wuaueng")

        foreach ($dll in $dlls) {
            $dllPath = "C:\Windows\System32\$dll.dll"
            $backupPath = "C:\Windows\System32\${dll}_BAK.dll"

            if ((Test-Path $backupPath) -and !(Test-Path $dllPath)) {
                try {
                    Start-Process -FilePath "takeown.exe" -ArgumentList "/f `"$backupPath`"" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                    Start-Process -FilePath "icacls.exe" -ArgumentList "`"$backupPath`" /grant *S-1-1-0:F" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                    Rename-Item -Path $backupPath -NewName "$dll.dll" -ErrorAction SilentlyContinue
                    Write-StyledMessage Success "Ripristinato ${dll}_BAK.dll a $dll.dll"
                    Start-Process -FilePath "icacls.exe" -ArgumentList "`"$dllPath`" /setowner `"NT SERVICE\TrustedInstaller`"" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                    Start-Process -FilePath "icacls.exe" -ArgumentList "`"$dllPath`" /remove *S-1-1-0" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                }
                catch {
                    Write-StyledMessage Warning "Avviso: Impossibile ripristinare $dll.dll - $($_.Exception.Message)"
                }
            }
            elseif (Test-Path $dllPath) {
                Write-StyledMessage Info "💭 $dll.dll già presente nella posizione originale."
            }
            else {
                Write-StyledMessage Warning "⚠️ $dll.dll non trovato e nessun backup disponibile."
            }
        }

        Write-StyledMessage Info '📅 Riabilitazione task pianificati...'

        $taskPaths = @(
            '\Microsoft\Windows\InstallService\*'
            '\Microsoft\Windows\UpdateOrchestrator\*'
            '\Microsoft\Windows\UpdateAssistant\*'
            '\Microsoft\Windows\WaaSMedic\*'
            '\Microsoft\Windows\WindowsUpdate\*'
            '\Microsoft\WindowsUpdate\*'
        )

        foreach ($taskPath in $taskPaths) {
            try {
                $tasks = Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue
                foreach ($task in $tasks) {
                    Enable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue
                    Write-StyledMessage Success "Task abilitato: $($task.TaskName)"
                }
            }
            catch {
                Write-StyledMessage Warning "Avviso: Impossibile abilitare task in $taskPath - $($_.Exception.Message)"
            }
        }

        Write-StyledMessage Info '🖨️ Abilitazione driver tramite Windows Update...'

        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Name "PreventDeviceMetadataFromNetwork" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontPromptForWindowsUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontSearchWindowsUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DriverUpdateWizardWuSearchEnabled" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -ErrorAction SilentlyContinue
            Write-StyledMessage Success "🖨️ Driver tramite Windows Update abilitati."
        }
        catch {
            Write-StyledMessage Warning "Avviso: Impossibile abilitare driver - $($_.Exception.Message)"
        }

        Write-StyledMessage Info '🔄 Abilitazione riavvio automatico Windows Update...'

        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUPowerManagement" -ErrorAction SilentlyContinue
            Write-StyledMessage Success "🔄 Riavvio automatico Windows Update abilitato."
        }
        catch {
            Write-StyledMessage Warning "Avviso: Impossibile abilitare riavvio automatico - $($_.Exception.Message)"
        }

        Write-StyledMessage Info '⚙️ Ripristino impostazioni Windows Update...'

        try {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "BranchReadinessLevel" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferFeatureUpdatesPeriodInDays" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferQualityUpdatesPeriodInDays" -ErrorAction SilentlyContinue
            Write-StyledMessage Success "⚙️ Impostazioni Windows Update ripristinate."
        }
        catch {
            Write-StyledMessage Warning "Avviso: Impossibile ripristinare alcune impostazioni - $($_.Exception.Message)"
        }

        Write-StyledMessage Info '📋 Ripristino criteri locali Windows...'

        try {
            Start-Process -FilePath "secedit" -ArgumentList "/configure /cfg $env:windir\inf\defltbase.inf /db defltbase.sdb /verbose" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c RD /S /Q $env:WinDir\System32\GroupPolicyUsers" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c RD /S /Q $env:WinDir\System32\GroupPolicy" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
            Start-Process -FilePath "gpupdate" -ArgumentList "/force" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue

            Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKCU:\Software\Microsoft\WindowsSelfHost" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKCU:\Software\Policies" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKLM:\Software\Microsoft\Policies" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKLM:\Software\Microsoft\WindowsSelfHost" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKLM:\Software\Policies" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Policies" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" -Recurse -Force -ErrorAction SilentlyContinue

            Write-StyledMessage Success "📋 Criteri locali Windows ripristinati."
        }
        catch {
            Write-StyledMessage Warning "Avviso: Impossibile ripristinare alcuni criteri - $($_.Exception.Message)"
        }
    }

    # --- INIZIO LOGICA PRINCIPALE ---
    Write-StyledMessage Info '🛠️ Avvio riparazione servizi Windows Update...'
    
    $serviceConfig = @{
        'wuauserv' = @{ Type = 'Automatic'; Critical = $true }; 'bits' = @{ Type = 'Automatic'; Critical = $true }
        'cryptsvc' = @{ Type = 'Automatic'; Critical = $true }; 'trustedinstaller' = @{ Type = 'Manual'; Critical = $true }
        'msiserver' = @{ Type = 'Manual'; Critical = $false }
    }
    
    # 1. Stop Services
    $stopServices = @('wuauserv', 'cryptsvc', 'bits', 'msiserver')
    for ($i = 0; $i -lt $stopServices.Count; $i++) {
        Manage-Service $stopServices[$i] 'Stop' $serviceConfig[$stopServices[$i]] ($i + 1) $stopServices.Count
    }
    
    # 2. Registry Clean
    try {
        Write-StyledMessage Info '📋 Pulizia registro Windows Update...'
        Remove-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {}

    # 3. Directory Clean
    $directories = @(
        @{ Path = "C:\Windows\SoftwareDistribution"; Name = "SoftwareDistribution" },
        @{ Path = "C:\Windows\System32\catroot2"; Name = "catroot2" }
    )
    foreach ($dir in $directories) { Remove-DirectorySafely $dir.Path $dir.Name }

    # 4. Start Services
    $essentialServices = @('wuauserv', 'cryptsvc', 'bits')
    for ($i = 0; $i -lt $essentialServices.Count; $i++) {
        Manage-Service $essentialServices[$i] 'Start' $serviceConfig[$essentialServices[$i]] ($i + 1) $essentialServices.Count
    }

    # 5. Reset Authorization
    Start-Process "cmd.exe" -ArgumentList "/c wuauclt /resetauthorization /detectnow" -Wait -WindowStyle Hidden

    Write-StyledMessage Success '🎉 Riparazione completata.'
    if (Start-InterruptibleCountdown $CountdownSeconds "Riavvio") { Restart-Computer -Force }
}

WinUpdateReset