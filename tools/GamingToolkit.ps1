function GamingToolkit {
    <#
    .SYNOPSIS
        Gaming Toolkit - Windows gaming optimization tools.

    .DESCRIPTION
        Optimizes system performance for gaming.
        Includes runtime and game client installation plus system configuration.

    .PARAMETER CountdownSeconds
        Number of seconds in the countdown before restarting.

    .OUTPUTS
        None. The function does not return output.
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateRange(0, 300)]
        [int]$CountdownSeconds = 30,
        [switch]$SuppressIndividualReboot
    )

    Start-ToolkitSession -ToolName "GamingToolkit" -SubTitle (Get-SourceTextLoc 'script.GamingToolkit')

    $timeout = 3600

    function Test-WingetPackageAvailable([string]$PackageId) {
        try {
            $searchResult = winget search --id $PackageId --accept-source-agreements 2>&1
            $outputStr = $searchResult -join ' '
            if ($outputStr -match [regex]::Escape($PackageId)) {
                return $true
            }
            $listResult = winget list --id $PackageId --accept-source-agreements 2>&1
            $listStr = $listResult -join ' '
            if ($listStr -match [regex]::Escape($PackageId)) {
                return $true
            }
            return $false
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.packetVerificationError01' -Args @($PackageId, $errorMessage))
            return $false
        }
    }

    function Invoke-WingetInstallWithProgress([string]$PackageId, [string]$DisplayName, [int]$Step, [int]$Total) {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.01Installation2' -Args @($Step, $Total, $DisplayName))

        $outFile = "$env:TEMP\winget_$PackageId.log"
        $errFile = "$env:TEMP\winget_err_$PackageId.log"

        try {
            $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.installation0' -Args @($DisplayName)) -Command 'winget' -Arguments @('install', '--id', $PackageId, '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements') -TimeoutSeconds $timeout -LogContextKey "Gaming-Install-$PackageId"

            $exitCode = if ($null -ne $result -and ($result.PSObject.Properties.Name -contains 'ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 1638, 3010, -1978335189)

            if ($exitCode -in $successCodes) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.installed0' -Args @($DisplayName))
                return @{ Success = $true; ExitCode = $exitCode }
            }
            else {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.installationError0Code1' -Args @($DisplayName, $exitCode))
                return @{ Success = $false; ExitCode = $exitCode }
            }
        }
        catch {
            Clear-ProgressLine
            Clear-ProgressLine
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.exception01' -Args @($DisplayName, $($_.Exception.Message)))
            return @{ Success = $false }
        }
        finally {
            Remove-ItemSafely -Path $outFile
            Remove-ItemSafely -Path $errFile
        }
    }

    # Countdown preparazione
    Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.preparation') -Timer -Action { Start-Sleep 5 } -TimeoutSeconds 5

    Show-Header -SubTitle (Get-SourceTextLoc 'script.GamingToolkit')

    # Step 1: Verifica e ripristino automatico Winget
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.checkWingetAvailability')
    Update-EnvironmentPath
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.wingetNotAvailableStartingAutomaticRecovery')
        $resetOk = Reset-Winget
        Update-EnvironmentPath
        if (-not $resetOk -or -not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.wingetRestoreFailedUnableToProceedWithGamingToolkit')
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.pressAnyKeyToContinue')
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }
    }
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.wingetAvailable')

    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.wingetSourcesUpdate')
    try {
        winget source update *>$null
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.updatedSources')
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.sourceUpdateError0' -Args @($($_.Exception.Message)))
    }

    # Step 2: NetFramework
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.enablingNetframework')
    $netFxFeatures = @('NetFx4-AdvSrvs', 'NetFx3')
    $netFxFailed = $false
    foreach ($feature in $netFxFeatures) {
        try {
            # Enable-WindowsOptionalFeature with multiple features + -All fails under
            # PowerShell 7 ("Interfaccia non registrata"). DISM handles each feature
            # reliably across editions without relying on the CBS COM interface.
            $dismResult = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.enablingNetframeworkFeature0' -Args @($feature)) -Command 'dism.exe' -Arguments @('/Online', '/Enable-Feature', "/FeatureName:$feature", '/All', '/NoRestart') -TimeoutSeconds $timeout -LogContextKey "Gaming-NetFx-$feature"
            $exitCode = if ($null -ne $dismResult -and ($dismResult.PSObject.Properties.Name -contains 'ExitCode')) { $dismResult.ExitCode } else { -1 }
            if ($exitCode -in @(0, 3010)) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.netframeworkFeatureEnabled0' -Args @($feature))
            }
            else {
                $netFxFailed = $true
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.errorEnablingNetframeworkFeature0Code1' -Args @($feature, $exitCode))
            }
        }
        catch {
            $netFxFailed = $true
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.errorEnablingNetframeworkFeature0Code1' -Args @($feature, $($_.Exception.Message)))
        }
    }
    if (-not $netFxFailed) {
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.netframeworkEnabled')
    }

    # Step 3: Runtime e VCRedist
    $runtimes = @(
        "Microsoft.DotNet.DesktopRuntime.3_1",
        "Microsoft.DotNet.DesktopRuntime.5",
        "Microsoft.DotNet.DesktopRuntime.6",
        "Microsoft.DotNet.DesktopRuntime.7",
        "Microsoft.DotNet.DesktopRuntime.8",
        "Microsoft.DotNet.DesktopRuntime.9",
        "Microsoft.DotNet.DesktopRuntime.10",
        "Microsoft.VCRedist.2010.x64",
        "Microsoft.VCRedist.2010.x86",
        "Microsoft.VCRedist.2012.x64",
        "Microsoft.VCRedist.2012.x86",
        "Microsoft.VCRedist.2013.x64",
        "Microsoft.VCRedist.2013.x86",
        "Microsoft.VCLibs.Desktop.14",
        "Microsoft.VCRedist.2015+.x64",
        "Microsoft.VCRedist.2015+.x86"
    )

    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.installingNetRuntimeAndVcredist')
    for ($runtimeIndex = 0; $runtimeIndex -lt $runtimes.Count; $runtimeIndex++) {
        Invoke-WingetInstallWithProgress $runtimes[$runtimeIndex] $runtimes[$runtimeIndex] ($runtimeIndex + 1) $runtimes.Count *>$null
    }
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.runtimesCompleted')

    # Step 4: DirectX
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.directxInstallation')
    $dxDir = Join-Path $AppConfig.Paths.LocalAppData "WinToolkit\Directx"
    $dxPath = "$dxDir\dxwebsetup.exe"

    if (-not (Test-Path $dxDir)) { New-Item -Path $dxDir -ItemType Directory -Force *>$null }

    try {
        Invoke-WebRequest -Uri $AppConfig.URLs.DirectXWebSetup -OutFile $dxPath -ErrorAction Stop
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.directxDownloaded')

        $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.directxInstallation') -Command $dxPath -TimeoutSeconds $timeout -LogContextKey "Gaming-DirectX"

        Clear-ProgressLine
        Clear-ProgressLine

        if ($null -eq $result) {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.directxProcessDidNotStartCorrectly')
        }
        elseif ($result -is [hashtable] -and $result.Contains('TimedOut') -and $result.TimedOut) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.directxTimeout')
        }
        else {
            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 3010, 5100, -9, 9, -1442840576)
            $messageType = if ($exitCode -in $successCodes) { 'Success' } else { 'Error' }
            $messageText = if ($exitCode -in $successCodes) {
                Get-SourceTextLoc 'toolText.extra.directxInstalledCode0' -Args @($exitCode)
            }
            else {
                Get-SourceTextLoc 'toolText.extra.directxError0' -Args @($exitCode)
            }
            Write-StyledMessage -Type $messageType -Text $messageText
        }
    }
    catch {
        Clear-ProgressLine
        Clear-ProgressLine
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorDuringDirectxInstallation0' -Args @($($_.Exception.Message)))
    }

    # Step 5: Client di gioco
    $gameClients = @(
        "Amazon.Games", "GOG.Galaxy", "EpicGames.EpicGamesLauncher",
        "ElectronicArts.EADesktop", "Playnite.Playnite", "Valve.Steam",
        "Ubisoft.Connect"
    )

    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.gameClientInstallation')
    for ($clientIndex = 0; $clientIndex -lt $gameClients.Count; $clientIndex++) {
        Invoke-WingetInstallWithProgress $gameClients[$clientIndex] $gameClients[$clientIndex] ($clientIndex + 1) $gameClients.Count *>$null
    }
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.clientsInstalled')

    # Step 5b: Xbox Game Bar & Xbox App
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.reinstallingXboxGameBarApp')

    $xboxPackages = @("9NZKPSTSNW4P", "9MV0B5HZVK9Z")

    foreach ($pkg in $xboxPackages) {
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.reinstallation0' -Args @($pkg))

        $outFile = "$env:TEMP\winget_$pkg.log"
        $errFile = "$env:TEMP\winget_err_$pkg.log"

        try {
            $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'uiText.reinstallation0' -Args @($pkg)) -Process -Action {
                $procParams = @{
                    FilePath               = 'winget'
                    ArgumentList           = @('install', '--id', $pkg, '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements', '--force')
                    PassThru               = $true
                    NoNewWindow            = $true
                    RedirectStandardOutput = $outFile
                    RedirectStandardError  = $errFile
                }
                Start-Process @procParams
            } -TimeoutSeconds $timeout -UpdateInterval 700

            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 1638, 3010, -1978335189)

            if ($exitCode -in $successCodes) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.reinstalled0' -Args @($pkg))
            }
            else {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.0Code1' -Args @(${pkg}, $exitCode))
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.error01' -Args @($pkg, $($_.Exception.Message)))
        }
        finally {
            Remove-ItemSafely -Path $outFile
            Remove-ItemSafely -Path $errFile
        }
    }
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.xboxReinstalled')

    # Step 6: Battle.net
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.installingBattleNet')

    $battleNetPkg = "Blizzard.BattleNet"
    $outFile = "$env:TEMP\winget_$battleNetPkg.log"
    $errFile = "$env:TEMP\winget_err_$battleNetPkg.log"

    try {
        # Battle.net non supporta l'override della cartella di installazione tramite
        # winget (--location causa un errore e il fallimento dell'installazione).
        # Si usa lo stesso pattern Start-Process dei pacchetti Xbox, gia' collaudato.
        $result = Invoke-WithSpinner -Activity (Get-SourceTextLoc 'toolText.extra.installingBattleNet') -Process -Action {
            $procParams = @{
                FilePath               = 'winget'
                ArgumentList           = @('install', '--id', $battleNetPkg, '--exact', '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements', '--force')
                PassThru               = $true
                NoNewWindow            = $true
                RedirectStandardOutput = $outFile
                RedirectStandardError  = $errFile
            }
            Start-Process @procParams
        } -TimeoutSeconds $timeout -UpdateInterval 700

        Clear-ProgressLine
        Clear-ProgressLine

        if ($null -eq $result) {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.battleNetProcessDidNotStartProperly')
        }
        elseif ($result -is [hashtable] -and $result.Contains('TimedOut') -and $result.TimedOut) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.battleNetTimedOut')
        }
        else {
            $exitCode = if ($result -is [hashtable] -and $result.Contains('ExitCode')) { $result.ExitCode } else { -1 }
            $successCodes = @(0, 1638, 3010, -1978335189)
            if ($exitCode -in $successCodes) {
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.battleNetInstalled')
            }
            else {
                $errDetail = ''
                if (Test-Path $errFile) { $errDetail = (Get-Content -Path $errFile -Raw -ErrorAction SilentlyContinue) }
                if ([string]::IsNullOrWhiteSpace($errDetail) -and (Test-Path $outFile)) { $errDetail = (Get-Content -Path $outFile -Raw -ErrorAction SilentlyContinue) }
                if (-not [string]::IsNullOrWhiteSpace($errDetail)) {
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.battleNetCode0' -Args @($exitCode))
                    Write-StyledMessage -Type 'Warning' -Text ($errDetail.Trim() -split "`n" | Select-Object -First 5 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() } | Join-String -Separator "`n")
                }
                else {
                    Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.extra.battleNetCode0' -Args @($exitCode))
                }
            }
        }
    }
    catch {
        Clear-ProgressLine
        Clear-ProgressLine
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorInstallingBattleNet0' -Args @($($_.Exception.Message)))
    }
    finally {
        Remove-ItemSafely -Path $outFile
        Remove-ItemSafely -Path $errFile
    }

    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.pressAnyKeyToContinue')
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

    # Step 7: Pulizia avvio automatico
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.autostartCleaner')
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    @('Steam', 'Battle.net', 'GOG Galaxy', 'GogGalaxy', 'GalaxyClient') | ForEach-Object {
        if (Get-ItemProperty -Path $runKey -Name $_ -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $runKey -Name $_ -ErrorAction SilentlyContinue
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.removed0' -Args @($_))
        }
    }

    $startupPath = $AppConfig.Paths.Startup
    @('Steam.lnk', 'Battle.net.lnk', 'GOG Galaxy.lnk') | ForEach-Object {
        $path = Join-Path $startupPath $_
        Remove-ItemSafely -Path $path
        if (-not (Test-Path $path)) {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.removed0' -Args @($_))
        }
    }
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.cleaningCompleted')

    # Step 8: Profilo energetico
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.energyProfileConfiguration')
    $ultimateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    $planName = "WinToolkit Gaming Performance"
    $guid = $null

    $existingPlan = powercfg -list | Select-String -Pattern $planName -ErrorAction SilentlyContinue
    if ($existingPlan) {
        $guid = ($existingPlan.Line -split '\s+')[3]
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.existingPlanFound')
    }
    else {
        try {
            $output = powercfg /duplicatescheme $ultimateGUID | Out-String
            if ($output -match "\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b") {
                $guid = $matches[0]
                powercfg /changename $guid $planName 'Optimized for Gaming by WinToolkit' *>$null
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.planCreated')
            }
            else {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.planCreationError')
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorDuringEnergyPlanDuplication0' -Args @($($_.Exception.Message)))
        }
    }

    if ($guid) {
        try {
            powercfg -setactive $guid *>$null
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.planActivated')
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorDuringEnergyPlanActivation0' -Args @($($_.Exception.Message)))
        }
    }
    else {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.unableToActivatePlan')
    }

    # Step 9: Focus Assist
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.doNotDisturbActivation')
    try {
        Set-ItemProperty -Path $AppConfig.Registry.FocusAssist -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Value 0 -Force
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.doNotDisturbActive')
    }
    catch {
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.errorDuringFocusAssistConfiguration0' -Args @($($_.Exception.Message)))
    }

    # Step 10: Completamento
    Write-StyledMessage -Type 'Info' -Text ('─' * 60)
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.gamingToolkitCompleted')
    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.systemOptimizedForGaming')
    Write-StyledMessage -Type 'Info' -Text ('─' * 60)

    Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.extra.rebootRequired') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
}
