

# SECTION 11 · OFFICE — SHARED HELPERS
# Functions shared by Install-Office, Repair-Office and Uninstall-Office.
# Defined at script scope to be accessible from all three compiled tools.
# ==============================================================================

function Invoke-OfficeSilentRemoval {
    param([Parameter(Mandatory = $true)][string]$Path, [switch]$Recurse)
    return Remove-ItemSafely -Path $Path -Recurse:$Recurse
}

function Stop-OfficeProcesses {
    $processes = @('winword', 'excel', 'powerpnt', 'outlook', 'onenote', 'msaccess', 'visio', 'lync')
    $closed = 0
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'uiText.closingOfficeProcesses')
    foreach ($processName in $processes) {
        $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($running) {
            try { $running | Stop-Process -Force -ErrorAction Stop; $closed++ }
            catch { Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.unableToClose0' -Args @($processName)) }
        }
    }
    if ($closed -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.0OfficeProcessesClosed' -Args @($closed)) }
}

function Invoke-OfficeDownloadFile([string]$Url, [string]$OutputPath, [string]$Description) {
    return Invoke-ToolkitDownload -Uri $Url -OutputPath $OutputPath -Description $Description
}

function Set-OfficePostConfig {
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'uiText.deepOptimizationOfMicrosoftOffice')

    $registrySettings = @(
        # Privacy & Telemetria
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common"; Name = "sendtelemetry"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common"; Name = "sendtelemetry"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "disconnectedstate"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "usercontentdisabled"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"; Name = "downloadcontentdisabled"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General"; Name = "ShownOptIn"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Feedback"; Name = "Enabled"; Value = 0 },
        # Performance & UI
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Graphics"; Name = "DisableAnimations"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Graphics"; Name = "DisableHardwareAcceleration"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\General"; Name = "DisableBootToStartScreen"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\LinkedIn"; Name = "ShowLinkedInIntegration"; Value = 0 }
    )

    foreach ($reg in $registrySettings) {
        if (-not (Test-Path $reg.Path)) { $null = New-Item -Path $reg.Path -Force }
        Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -Type 'DWord' -Force
    }

    $tasksToDisable = @(
        "OfficeTelemetryAgentLogon", "OfficeTelemetryAgentFallback",
        "OfficeBackgroundTaskHandlerRegistration", "OfficeBackgroundTaskHandlerLogon",
        "OfficeFeatureUpdates", "OfficeFeatureUpdatesLogon"
    )
    foreach ($tName in $tasksToDisable) {
        Get-ScheduledTask | Where-Object { $_.TaskName -eq $tName } | Disable-ScheduledTask -ErrorAction SilentlyContinue
    }

    Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.officeOptimizedTelemetryPrivacyAndScheduledTasksRemoved')
}

function VcardAnalizer {
    <#
    .SYNOPSIS
        Analyzes present GPUs and tries to associate stable drivers from DriverOverrides.json.
    .DESCRIPTION
        Detects cards even without complete drivers using Win32_VideoController (Name/Caption/PNPDeviceID),
        compares data with an override JSON file and saves the result in
        $Global:VcardAnalysisResult for reuse in tools.
    #>
    [CmdletBinding()]
    param(
        [string]$OverridesPath
    )

    $assetCacheDir = Join-Path $AppConfig.Paths.Root 'assets'
    if (-not (Test-Path $assetCacheDir)) {
        $null = New-Item -Path $assetCacheDir -ItemType Directory -Force
    }
    $defaultLocalOverrides = Join-Path $assetCacheDir 'DriverOverrides.json'
    $resolvedOverridesPath = if ($OverridesPath) { $OverridesPath } else { $defaultLocalOverrides }

    $analysis = [pscustomobject]@{
        Cards               = @()
        Matches             = @()
        PrimaryManufacturer = 'Unknown'
        OverridesLoaded     = $false
        OverridesSource     = $resolvedOverridesPath
    }

    try {
        $cards = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
        foreach ($card in $cards) {
            $name = [string]$card.Name
            $caption = [string]$card.Caption
            $pnpId = [string]$card.PNPDeviceID
            $manufacturer = 'Unknown'

            if ($name -match 'NVIDIA|GeForce|Quadro|Tesla' -or $caption -match 'NVIDIA') { $manufacturer = 'NVIDIA' }
            elseif ($name -match 'AMD|Radeon|ATI' -or $caption -match 'AMD|ATI') { $manufacturer = 'AMD' }
            elseif ($name -match 'Intel|Iris|UHD|HD Graphics' -or $caption -match 'Intel') { $manufacturer = 'Intel' }

            $analysis.Cards += [pscustomobject]@{
                Name         = $name
                Caption      = $caption
                PnpDeviceID  = $pnpId
                Manufacturer = $manufacturer
            }
        }
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.gpuAnalysisErrorReadingWin32Videocontroller0' -Args @($($_.Exception.Message)))
    }

    if ($analysis.Cards.Count -gt 0) {
        $analysis.PrimaryManufacturer = ($analysis.Cards | Select-Object -First 1).Manufacturer
    }

    $overrides = @()
    $remoteUrl = $AppConfig.URLs.DriverOverridesJson

    try {
        if (Invoke-ToolkitDownload -Uri $remoteUrl -OutputPath $defaultLocalOverrides -Description 'Driver Overrides JSON') {
            $resolvedOverridesPath = $defaultLocalOverrides
            $analysis.OverridesSource = $resolvedOverridesPath
        }
    }
    catch {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.driveroverridesJsonDownloadFailedUseLocalCacheIfAvailable')
    }

    if (Test-Path $resolvedOverridesPath) {
        try {
            $jsonRaw = Get-Content -Path $resolvedOverridesPath -Raw -Encoding UTF8
            $parsed = $jsonRaw | ConvertFrom-Json -ErrorAction Stop
            if ($parsed -is [System.Array]) { $overrides = $parsed }
            elseif ($parsed) { $overrides = @($parsed) }
            $analysis.OverridesLoaded = $true
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.invalidDriveroverridesJson0' -Args @($($_.Exception.Message)))
        }
    }
    else {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.driveroverridesJsonNotFoundIn0' -Args @($resolvedOverridesPath))
    }

    foreach ($gpu in $analysis.Cards) {
        foreach ($ovr in $overrides) {
            $namePattern = [string]$ovr.NamePattern
            $pnpPattern = [string]$ovr.PnpIdPattern
            $manufacturer = [string]$ovr.Manufacturer

            $nameMatches = $false
            $pnpMatches = $false
            $mfrMatches = $false

            if (-not [string]::IsNullOrWhiteSpace($namePattern) -and -not [string]::IsNullOrWhiteSpace($gpu.Name)) {
                $nameMatches = $gpu.Name -match $namePattern
            }
            if (-not [string]::IsNullOrWhiteSpace($pnpPattern) -and -not [string]::IsNullOrWhiteSpace($gpu.PnpDeviceID)) {
                $pnpMatches = $gpu.PnpDeviceID -like $pnpPattern
            }
            if (-not [string]::IsNullOrWhiteSpace($manufacturer) -and $gpu.Manufacturer -ne 'Unknown') {
                $mfrMatches = $gpu.Manufacturer -eq $manufacturer
            }

            if (($nameMatches -or $pnpMatches) -and ($mfrMatches -or [string]::IsNullOrWhiteSpace($manufacturer))) {
                $analysis.Matches += [pscustomobject]@{
                    Key          = [string]$ovr.Key
                    Manufacturer = [string]$ovr.Manufacturer
                    NamePattern  = [string]$ovr.NamePattern
                    PnpIdPattern = [string]$ovr.PnpIdPattern
                    DownloadUrl  = [string]$ovr.DownloadUrl
                    FileName     = [string]$ovr.FileName
                    DisplayName  = [string]$ovr.DisplayName
                    MatchedGpu   = [string]$gpu.Name
                    MatchedPnpId = [string]$gpu.PnpDeviceID
                }
            }
        }
    }

    if ($analysis.Matches.Count -gt 0) {
        $analysis.Matches = @($analysis.Matches | Group-Object Key | ForEach-Object { $_.Group | Select-Object -First 1 })
        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'uiText.detected0StableDriverMatchesFromDriveroverridesJson' -Args @($($analysis.Matches.Count)))
    }
    else {
        Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'uiText.noKnownStableDriversFoundForTheDetectedGpus')
    }

    $Global:VcardAnalysisResult = $analysis
    return $analysis
}
