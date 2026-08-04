<#
.SYNOPSIS
    Start Script for Win Toolkit in Offline mode.
.DESCRIPTION
    This script prepares the Win Toolkit environment by downloading all dependencies
    needed (installers, icons, etc.) into a local 'start' folder.
    Subsequently, it launches the main 'start.ps1' script (which must be
    previously placed in the 'start' folder) in offline mode,
    allowing the toolkit to run even without internet connection.
.NOTES
  Version 2.4.1 Build 3
#>

[CmdletBinding()]
param([string]$Language = 'en-US')

# Ensure script runs with PowerShell 5.1 or higher for basic compatibility
# This script itself doesn't require PowerShell 7, but the main toolkit might.

$script:SourceTextLanguageData = $null
$script:SourceTextDefaultLanguageData = $null

function Get-SourceTextLanguageDirectory {
    $candidates = @(
        (Join-Path $PSScriptRoot 'languages'),
        (Join-Path (Split-Path $PSScriptRoot -Parent) 'languages'),
        (Join-Path (Get-Location) 'languages')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    return $candidates[0]
}

function Import-SourceTextLanguageFile {
    param([string]$LanguageCode)

    $languageDirectory = Get-SourceTextLanguageDirectory
    if (-not (Test-Path $languageDirectory)) { return $null }
    try {
        $localizedData = $null
        Import-LocalizedData -BindingVariable localizedData -BaseDirectory $languageDirectory -FileName 'WinToolkit.psd1' -UICulture $LanguageCode -ErrorAction Stop
        return $localizedData
    }
    catch {
        return $null
    }
}

function Initialize-SourceTextLocalization {
    param([string]$LanguageCode)

    $script:SourceTextDefaultLanguageData = Import-SourceTextLanguageFile -LanguageCode 'en-US'
    $script:SourceTextLanguageData = Import-SourceTextLanguageFile -LanguageCode $LanguageCode
    if (-not $script:SourceTextLanguageData) {
        $script:SourceTextLanguageData = $script:SourceTextDefaultLanguageData
    }
}

function Get-SourceTextLoc {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [object[]]$Arguments = @()
    )

    $value = $null
    if ($script:SourceTextLanguageData -and $script:SourceTextLanguageData.ContainsKey($Key)) {
        $value = [string]$script:SourceTextLanguageData[$Key]
    }
    elseif ($script:SourceTextDefaultLanguageData -and $script:SourceTextDefaultLanguageData.ContainsKey($Key)) {
        $value = [string]$script:SourceTextDefaultLanguageData[$Key]
    }
    else {
        $value = $Key
    }
    if ($Arguments.Count -gt 0) { return [string]::Format($value, $Arguments) }
    return $value
}

Initialize-SourceTextLocalization -LanguageCode $Language

function Write-StyledMessage {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Debug')]
        [string]$type,
        [Parameter(Mandatory = $true)]
        [string]$text
    )

    $colors = @{
        'Info'    = 'Cyan'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
        'Success' = 'Green'
        'Debug'   = 'DarkGray'
    }
    Write-Host $text -ForegroundColor $colors[$type]
}

function Show-Host {
    <#
    .SYNOPSIS
        Displays host system information.

    .DESCRIPTION
        Shows detailed information about the operating system, hardware and current configuration.
    #>

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
        '    Start-Offline By MagnetarMan',
        '       Version 2.4.1 (Build 3)'
    )

    foreach ($line in $asciiArt) {
        if ($line) {
            $padding = [Math]::Max(0, [Math]::Floor(($width - $line.Length) / 2))
            Write-Host (' ' * $padding + $line) -ForegroundColor White
        }
    }

    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    Write-Host ""

    try {
        $osInfo = Get-ComputerInfo
        $cpuInfo = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
        $memoryInfo = Get-WmiObject -Class Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
        $diskInfo = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"

        Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.operatingSystem0' -Args @($($osInfo.OsName)))
        Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.build01' -Args @($($osInfo.OsBuildNumber), $($osInfo.OsArchitecture)))
        Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.user0On1' -Args @($($env:USERNAME), $($env:COMPUTERNAME)))
        Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.powershell02' -Args @($($PSVersionTable.PSVersion.ToString())))
        Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.cpu0' -Args @($($cpuInfo.Name.Trim())))
        Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.ram0Gb' -Args @($([math]::Round($memoryInfo.Sum / 1GB, 2))))
        Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.diskC0TotalGb1FreeGb' -Args @($([math]::Round($diskInfo.Size / 1GB, 2)), $([math]::Round($diskInfo.FreeSpace / 1GB, 2))))

        # Verify Winget
        $wingetVersion = $null
        try {
            $wingetOutput = winget --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                $wingetVersion = $wingetOutput.Trim()
            }
        } catch {}

        if ($wingetVersion) {
            Write-StyledMessage -type 'Success' -text (Get-SourceTextLoc 'uiText.winget0' -Args @($wingetVersion))
        } else {
            Write-StyledMessage -type 'Warning' -text (Get-SourceTextLoc 'uiText.wingetNotAvailable')
        }

        # Verify internet connection
        $internetConnected = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet
        if ($internetConnected) {
            Write-StyledMessage -type 'Success' -text (Get-SourceTextLoc 'uiText.internetConnectionAvailable')
        } else {
            Write-StyledMessage -type 'Warning' -text (Get-SourceTextLoc 'uiText.internetConnectionNotAvailableOfflineMode')
        }

        Write-Host ""
        Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.scriptStartOfflineVersione241Build3')
        Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.byMagnetarmanWinToolkitProject')
    }
    catch {
        Write-StyledMessage -type 'Error' -text (Get-SourceTextLoc 'uiText.errorRetrievingSystemInformation0' -Args @($($_.Exception.Message)))
    }

    Write-Host ('═' * ($width - 1)) -ForegroundColor Green
    Write-Host ""
}

function Invoke-DownloadFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [int]$TimeoutSeconds = 60,
        [int]$MaxRetries = 3
    )

    $FileName = Split-Path $OutputPath -Leaf
    Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.download0From1' -Args @($FileName, $Uri))

    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $OutputPath -UseBasicParsing -TimeoutSec $TimeoutSeconds
            Write-StyledMessage -type 'Success' -text (Get-SourceTextLoc 'uiText.0DownloadComplete' -Args @($FileName))
            return $true
        }
        catch {
            Write-StyledMessage -type 'Warning' -text (Get-SourceTextLoc 'uiText.0AttemptBy1FailedFor23' -Args @($i, $MaxRetries, $FileName, $($_.Exception.Message)))
            if ($i -lt $MaxRetries) {
                Start-Sleep -Seconds 5
            }
        }
    }
    Write-StyledMessage -type 'Error' -text (Get-SourceTextLoc 'uiText.downloadOf0FailedAfter1Attempts' -Args @($FileName, $MaxRetries))
    return $false
}

function Initialize-OfflineResources {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OfflineResourcesDir
    )

    Write-Host ""
    Write-StyledMessage -type 'Info' -text "=========================================================="
    Write-StyledMessage -type 'Info' -text (" " + (Get-SourceTextLoc 'uiText.preparingOfflineResourcesForWinToolkitStarter') + " ")
    Write-StyledMessage -type 'Info' -text "=========================================================="
    Write-Host ""

    if (-not (Test-Path $OfflineResourcesDir)) {
        New-Item -Path $OfflineResourcesDir -ItemType Directory -Force | Out-Null
        Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.createdOfflineResourceDirectory0' -Args @($OfflineResourcesDir))
    }
    else {
        Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.existingOfflineResourceDirectory0' -Args @($OfflineResourcesDir))
    }
    Write-Host ""

    $allDownloadsSuccessful = $true

    # --- Winget Installer ---
    $wingetUrl = "https://aka.ms/getwinget"
    $wingetPath = Join-Path $OfflineResourcesDir "WingetInstaller.msixbundle"
    if (-not (Test-Path $wingetPath)) {
        if (-not (Invoke-DownloadFile -Uri $wingetUrl -OutputPath $wingetPath)) {
            $allDownloadsSuccessful = $false
        }
    } else {
        Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.wingetinstallerMsixbundleAlreadyPresent')
    }

    # --- Git Installer ---
    $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.51.0.windows.1/Git-2.51.0-64-bit.exe"
    $gitPath = Join-Path $OfflineResourcesDir "Git-2.51.0-64-bit.exe"
    if (-not (Test-Path $gitPath)) {
        if (-not (Invoke-DownloadFile -Uri $gitUrl -OutputPath $gitPath)) {
            $allDownloadsSuccessful = $false
        }
    } else {
        Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.git251064BitExeAlreadyExists')
    }

    # --- PowerShell 7 Installer ---
    $ps7Url = "https://github.com/PowerShell/PowerShell/releases/download/v7.5.2/PowerShell-7.5.2-win-x64.msi"
    $ps7Path = Join-Path $OfflineResourcesDir "PowerShell-7.5.2-win-x64.msi"
    if (-not (Test-Path $ps7Path)) {
        if (-not (Invoke-DownloadFile -Uri $ps7Url -OutputPath $ps7Path)) {
            $allDownloadsSuccessful = $false
        }
    } else {
        Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.powershell752WinX64MsiAlreadyPresent')
    }

    # --- Windows Terminal Installer (latest MSIX bundle from GitHub) ---
    $wtApiPath = "https://api.github.com/repos/microsoft/terminal/releases/latest"
    $wtFileNamePattern = "Microsoft.WindowsTerminal_*.msixbundle"
    $localWtInstaller = Get-ChildItem -Path $OfflineResourcesDir -Filter $wtFileNamePattern -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName -First 1

    if (-not $localWtInstaller) {
        Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.searchForLatestWindowsTerminalInstallerOnGithub')
        try {
            $release = Invoke-RestMethod -Uri $wtApiPath -UseBasicParsing -TimeoutSec 30
            $asset = $release.assets | Where-Object { $_.name -like "*Win10*msixbundle" } | Select-Object -First 1

            if ($asset) {
                $wtDownloadUrl = $asset.browser_download_url
                $wtPath = Join-Path $OfflineResourcesDir $($asset.name)
                if (-not (Test-Path $wtPath)) {
                    if (-not (Invoke-DownloadFile -Uri $wtDownloadUrl -OutputPath $wtPath)) {
                        $allDownloadsSuccessful = $false
                    }
                } else {
                    Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.0AlreadyPresent' -Args @($($asset.name)))
                }
            } else {
                Write-StyledMessage -type 'Error' -text (Get-SourceTextLoc 'uiText.noMsixBundleAssetsFoundForWindowsTerminal')
                $allDownloadsSuccessful = $false
            }
        } catch {
            Write-StyledMessage -type 'Error' -text (Get-SourceTextLoc 'uiText.errorGettingWindowsTerminalReleaseFromGithub0' -Args @($($_.Exception.Message)))
            $allDownloadsSuccessful = $false
        }
    } else {
        Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.windowsTerminalInstaller0AlreadyPresent' -Args @($($localWtInstaller | Split-Path -Leaf)))
    }

    # --- Win Toolkit Icon ---
    $iconUrl = "https://raw.githubusercontent.com/Magnetarman/WinToolkit/refs/heads/main/images/WinToolkit.ico"
    $iconPath = Join-Path $OfflineResourcesDir "WinToolkit.ico"
    if (-not (Test-Path $iconPath)) {
        if (-not (Invoke-DownloadFile -Uri $iconUrl -OutputPath $iconPath)) {
            $allDownloadsSuccessful = $false
        }
    } else { Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.wintoolkitIcoAlreadyPresent') }

    Write-Host ""
    if ($allDownloadsSuccessful) {
        Write-StyledMessage -type 'Success' -text (Get-SourceTextLoc 'uiText.allOfflineResourcesHaveBeenSuccessfullyPrepared')
    } else {
        Write-StyledMessage -type 'Error' -text (Get-SourceTextLoc 'uiText.someOfflineResourcesWereNotDownloadedCheckTheConnectionAndTryAgain')
    }
    Write-Host ""

    return $allDownloadsSuccessful
}

# --- Main execution for Start-Offline.ps1 ---
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$OfflineResourcesDir = Join-Path $scriptRoot "start"
$mainScriptPath = Join-Path $OfflineResourcesDir "start.ps1"

$Host.UI.RawUI.WindowTitle = "Toolkit Starter Offline by MagnetarMan"

Clear-Host
Show-Host
Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.startingOfflineEnvironmentPreparation')

if (Initialize-OfflineResources -OfflineResourcesDir $OfflineResourcesDir) {
    Write-StyledMessage -type 'Info' -text (Get-SourceTextLoc 'uiText.checkForMainScriptStartPs1In0' -Args @($OfflineResourcesDir))
    if (-not (Test-Path $mainScriptPath)) {
        Write-StyledMessage -type 'Error' -text (Get-SourceTextLoc 'uiText.errorModifiedScriptStartPs1IsMissingFrom0' -Args @($OfflineResourcesDir))
        Write-StyledMessage -type 'Error' -text (Get-SourceTextLoc 'uiText.makeSureYouHaveCopiedTheModifiedMainScriptAfterStep2IntoThisDirectory')
        Read-Host (Get-SourceTextLoc 'sourceText.pressEnterToExit')
        exit 1
    }

    Write-StyledMessage -type 'Success' -text (Get-SourceTextLoc 'uiText.resourcesReadyStartingTheMainScriptInOfflineMode')
    Write-Host ""

    # Execute the modified main script, passing the offline directory
    # Use Invoke-Expression (iex) to ensure the script runs in the current session context if preferred,
    # or '&' for a new context. Using '&' is safer for external scripts.
    & $mainScriptPath -OfflineModeDir $OfflineResourcesDir -Language $Language
}
else {
    Write-StyledMessage -type 'Error' -text (Get-SourceTextLoc 'uiText.offlineResourcePreparationFailedUnableToProceed')
    Read-Host (Get-SourceTextLoc 'sourceText.pressEnterToExit')
    exit 1
}
