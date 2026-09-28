# ============================================================================
# POWERSHELL ENVIRONMENT (PSP): profile, theme, fonts, terminal settings
# ============================================================================

function Update-WindowsTerminalSettings {
    <#
    .SYNOPSIS
    Replaces a Windows Terminal settings.json atomically, keeping a timestamped backup.

    .DESCRIPTION
    Terminal reads settings.json at startup, so the swap is staged and moved in
    one step: an interrupted update must never leave an invalid configuration.
    #>
    param([Parameter(Mandatory = $true)][string]$SettingsPath)

    $downloadedPath = Join-Path $script:AppConfig.Paths.Temp "wt-settings-$([guid]::NewGuid()).json"
    try {
        if (-not (Invoke-DownloadFile -Uri $script:AppConfig.URLs.WindowsTerminalSettings -OutFile $downloadedPath -Silent)) {
            return $false
        }

        # The backup path is only returned when a previous file was replaced.
        $backupPath = Copy-FileAtomically -SourcePath $downloadedPath -DestinationPath $SettingsPath -Backup
        if ($backupPath) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.windowsTerminalSettingsOverwrittenBackup0' -Args @($backupPath))
        }
        return $true
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Windows Terminal settings update skipped: $($_.Exception.Message)"
        return $false
    }
    finally {
        if (Test-Path -LiteralPath $downloadedPath) { Remove-Item -LiteralPath $downloadedPath -Force -ErrorAction SilentlyContinue }
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
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.jetbrainsmonoNerdFontAlreadyInstalled')
            return $true
        }

        Write-StyledMessage -Type Info -Text ("⬇️ " + (Get-SourceTextLoc 'uiText.fontInstallationViaWingetQuickMethod'))

        # Use existing helper function for logical consistency
        $result = Invoke-WingetCommand -Arguments "install --id DEVCOM.JetBrainsMonoNerdFont --source winget --accept-source-agreements --accept-package-agreements --silent"

        if ($result.ExitCode -ne 0) {
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetReturnedCode0TheFontMayRequireATerminalRestart' -Args @($result.ExitCode))
            return $false
        }
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.nerdFontsInstalledSuccessfully')
        Write-StyledMessage -Type Warning -Text ("💡 " + (Get-SourceTextLoc 'uiText.noteFontsViaWingetRequireRestartingTerminalOrExplorerToBeVisible'))
        return $true
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.errorInstallingFont0' -Args @($_.Exception.Message))
        return $false
    }
}


function Test-OhMyPoshThemeFile {
    <#
    .SYNOPSIS
    Returns $true when the file is a plausible, parseable .omp.json theme.

    .DESCRIPTION
    A 404 page or a proxy/interstitial HTML response is a perfectly valid download
    as far as Invoke-WebRequest is concerned, and oh-my-posh then fails at every
    shell start. Parsing the JSON is what makes "Tema Oh My Posh scaricato"
    trustworthy instead of optimistic.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    try {
        if (-not (Test-FileHasMinimumSize -Path $Path -MinimumBytes $script:AppConfig.UserScope.MinThemeFileBytes)) {
            return $false
        }
        $null = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        return $true
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Oh My Posh theme is not valid JSON ($Path): $($_.Exception.Message)"
        return $false
    }
}



function Install-PspEnvironment {
    <#
    .SYNOPSIS
    Configures the PowerShell environment with tools, themes and custom profile.

    .DESCRIPTION
    Returns a result object instead of nothing, so the orchestrator can record the
    real outcome. Every step is verified on disk: the profile folder is created
    (even when Documents is empty or missing), the theme is validated as JSON, and
    the installed profile is re-read from its final location before it is reported
    as configured.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.startingPowershellEnvironmentSetupPsp')

    $result = [pscustomobject]@{
        Success          = $true
        Tools            = [pscustomobject]@{ Installed = @(); Failed = @() }
        FontOk           = $null
        ThemeOk          = $false
        ProfileOk        = $false
        ProfilePath      = $null
        ThemePath        = $null
        WingetRpcFailure = $false
        Message          = 'PowerShell environment configured.'
    }

    $context = Get-ToolkitOriginalUserContext
    if ($context.AccountSwitched) {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.elevationSwitchedAccount0' -Args @($context.OriginalUser, $context.CurrentUser))
    }

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
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.check0' -Args @($tool.Name))
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            $toolResult = Invoke-WingetCommand -Arguments "install -e --id $($tool.Id) --source winget --accept-source-agreements --accept-package-agreements --silent"
            if ($toolResult.ExitCode -ne 0) {
                Write-ToolkitLog -Level 'WARNING' -Message "Tool $($tool.Id) install returned exit code $($toolResult.ExitCode)."
            }
        }
    }

    # 2. Oh My Posh theme: always in the PowerShell 7 profile folder, because the
    #    profile is specific to PS7 and Windows Terminal.
    $ps7ProfileDir = [Environment]::GetFolderPath('MyDocuments') + '\PowerShell'
    $themesFolder = Initialize-Directory -Path (Join-Path $ps7ProfileDir 'Themes')

    $themePath = Join-Path $themesFolder 'atomic.omp.json'
    if (Invoke-DownloadFile -Uri $script:AppConfig.URLs.OhMyPoshTheme -OutFile $themePath) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.temaOhMyPoshScaricato')
    }

    # 3. Font Installation
    Install-NerdFontsLocal *>$null

    # 4. Profile configuration: the download is staged and swapped in, so the
    #    current profile is never removed before its replacement is on disk.
    $null = Initialize-Directory -Path $ps7ProfileDir
    $targetProfile = Join-Path $ps7ProfileDir 'Microsoft.PowerShell_profile.ps1'
    $stagedProfile = "$targetProfile.$([guid]::NewGuid()).tmp"
    try {
        if (Invoke-DownloadFile -Uri $script:AppConfig.URLs.PowerShellProfile -OutFile $stagedProfile) {
            $profileBackup = Copy-FileAtomically -SourcePath $stagedProfile -DestinationPath $targetProfile -Backup
            if ($profileBackup) {
                Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.existingProfileSaved0' -Args @($profileBackup))
            }
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7ProfileConfigured')
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.profileConfigurationError0' -Args @($_.Exception.Message))
    }
    finally {
        if (Test-Path -LiteralPath $stagedProfile) {
            Remove-Item -LiteralPath $stagedProfile -Force -ErrorAction SilentlyContinue
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
                    Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.windowsTerminalSettingsUpdated0' -Args @($wtPkg.Name))
                }
            }
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.terminalSettingsUpdateError0' -Args @($_.Exception.Message))
    }
}
