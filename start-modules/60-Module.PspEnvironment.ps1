# ============================================================================
# POWERSHELL ENVIRONMENT (PSP): profile, theme, fonts, terminal settings
# ============================================================================

function Update-WindowsTerminalSettings {
    <#
    .SYNOPSIS
    Replaces a Windows Terminal settings.json atomically, keeping a timestamped backup.
    #>
    param([Parameter(Mandatory = $true)][string]$SettingsPath)

    $remotePath = Join-Path $script:AppConfig.Paths.Temp "wt-settings-$([guid]::NewGuid()).json"
    try {
        if (-not (Invoke-DownloadFile -Uri $script:AppConfig.URLs.WindowsTerminalSettings -OutFile $remotePath)) {
            return $false
        }

        $backupPath = "$SettingsPath.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        if (Test-Path -LiteralPath $SettingsPath) {
            Copy-Item -LiteralPath $SettingsPath -Destination $backupPath -Force -ErrorAction Stop
        }

        $tempPath = "$SettingsPath.$([guid]::NewGuid()).tmp"
        try {
            Copy-Item -LiteralPath $remotePath -Destination $tempPath -Force -ErrorAction Stop
            Move-Item -LiteralPath $tempPath -Destination $SettingsPath -Force -ErrorAction Stop
        }
        finally {
            if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue }
        }

        Write-StyledMessage -Type Info -Text "Windows Terminal settings sovrascritti con la versione distribuita; backup: $backupPath."
        return $true
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Windows Terminal settings update skipped: $($_.Exception.Message)"
        return $false
    }
    finally {
        if (Test-Path -LiteralPath $remotePath) { Remove-Item -LiteralPath $remotePath -Force -ErrorAction SilentlyContinue }
    }
}

function Install-NerdFontsLocal {
    <#
    .SYNOPSIS
    Verifies and installs JetBrainsMono Nerd Font via Winget.
    #>
    try {
        Write-StyledMessage -Type Info -Text ("🔍 " + (Get-SourceTextLoc 'uiText.checkForJetbrainsmonoNerdFont'))

        # Quick check if the font is already registered in the system
        $fontRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        $installed = Get-ItemProperty -Path $fontRegistryPath -ErrorAction SilentlyContinue |
        Get-Member -MemberType NoteProperty |
        Where-Object Name -like "*JetBrainsMono*"

        if ($installed) {
            Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.jetbrainsmonoNerdFontAlreadyInstalled'))
            return $true
        }

        Write-StyledMessage -Type Info -Text ("⬇️ " + (Get-SourceTextLoc 'uiText.fontInstallationViaWingetQuickMethod'))

        # Use existing helper function for logical consistency
        $result = Invoke-WingetCommand -Arguments "install --id DEVCOM.JetBrainsMonoNerdFont --source winget --accept-source-agreements --accept-package-agreements --silent"

        if ($result.ExitCode -ne 0) {
            Write-StyledMessage -Type Warning -Text ((Get-SourceTextLoc 'uiText.wingetReturnedCode0TheFontMayRequireATerminalRestart' -Args @($($result.ExitCode))))
            return $false
        }
        Write-StyledMessage -Type Success -Text ((Get-SourceTextLoc 'uiText.nerdFontsInstalledSuccessfully'))
        Write-StyledMessage -Type Warning -Text ("💡 " + (Get-SourceTextLoc 'uiText.noteFontsViaWingetRequireRestartingTerminalOrExplorerToBeVisible'))
        return $true
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.errorInstallingFont0' -Args @($($_.Exception.Message)))
        return $false
    }
}

function Install-PspEnvironment {
    <#
    .SYNOPSIS
    Configures the PowerShell environment with tools, themes and custom profile.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingPowershellEnvironmentSetupPsp')

    # ============================================================================
    # PSP SETUP EXECUTION
    # ============================================================================

    # 1. Tool Installation via Winget
    $tools = @(
        @{ Id = "JanDeDobbeleer.OhMyPosh"; Name = "Oh My Posh" },
        @{ Id = "ajeetdsouza.zoxide"; Name = "zoxide" },
        @{ Id = "aristocratos.btop4win"; Name = "btop" },
        @{ Id = "Fastfetch-cli.Fastfetch"; Name = "fastfetch" }
    )

    foreach ($tool in $tools) {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.check0' -Args @($($tool.Name)))
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            $toolResult = Invoke-WingetCommand -Arguments "install -e --id $($tool.Id) --source winget --accept-source-agreements --accept-package-agreements --silent"
            if ($toolResult.ExitCode -ne 0) {
                Write-ToolkitLog -Level 'WARNING' -Message "Tool $($tool.Id) install returned exit code $($toolResult.ExitCode)."
            }
        }
    }

    # 2. Oh My Posh Theme Installation
    # Always in the PowerShell 7 folder (the profile is specific to PS7 and Windows Terminal)
    $ps7ProfileDir = [Environment]::GetFolderPath('MyDocuments') + '\PowerShell'
    $themesFolder = Join-Path $ps7ProfileDir 'Themes'
    if (-not (Test-Path $themesFolder)) {
        New-Item -Path $themesFolder -ItemType Directory -Force *>$null
    }

    $themePath = Join-Path $themesFolder 'atomic.omp.json'
    if (Invoke-DownloadFile -Uri $script:AppConfig.URLs.OhMyPoshTheme -OutFile $themePath) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.temaOhMyPoshScaricato')
    }

    # 3. Font Installation
    Install-NerdFontsLocal *>$null

    # 4. Profile Configuration (always in the PowerShell 7 folder).
    # Download first into a temporary file, then swap: the existing profile is
    # never moved away before the replacement is known to be on disk.
    if (-not (Test-Path $ps7ProfileDir)) {
        New-Item -Path $ps7ProfileDir -ItemType Directory -Force *>$null
    }
    $targetProfile = Join-Path $ps7ProfileDir 'Microsoft.PowerShell_profile.ps1'
    $temporaryProfile = "$targetProfile.$([guid]::NewGuid()).tmp"
    try {
        if (Invoke-DownloadFile -Uri $script:AppConfig.URLs.PowerShellProfile -OutFile $temporaryProfile) {
            if (Test-Path -LiteralPath $targetProfile) {
                $profileBackup = "$targetProfile.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                [System.IO.File]::Replace($temporaryProfile, $targetProfile, $profileBackup, $true)
                Write-StyledMessage -Type Info -Text "Profilo esistente salvato in $profileBackup."
            }
            else {
                Move-Item -LiteralPath $temporaryProfile -Destination $targetProfile -Force -ErrorAction Stop
            }
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7ProfileConfigured')
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.profileConfigurationError0' -Args @($($_.Exception.Message)))
    }
    finally {
        if ($temporaryProfile -and (Test-Path -LiteralPath $temporaryProfile)) {
            Remove-Item -LiteralPath $temporaryProfile -Force -ErrorAction SilentlyContinue
        }
    }

    # 5. Windows Terminal Settings Configuration (stable and preview)
    try {
        $wtPackages = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Directory `
            -Filter 'Microsoft.WindowsTerminal*' -ErrorAction SilentlyContinue
        foreach ($wtPkg in $wtPackages) {
            $localStatePath = Join-Path $wtPkg.FullName 'LocalState'
            if (Test-Path $localStatePath) {
                $settingsPath = Join-Path $localStatePath 'settings.json'
                if (Update-WindowsTerminalSettings -SettingsPath $settingsPath) {
                    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.windowsTerminalSettingsUpdated0' -Args @($($wtPkg.Name)))
                }
            }
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.terminalSettingsUpdateError0' -Args @($($_.Exception.Message)))
    }
}
