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

    try {
        # Install-RemoteFile owns the download, the atomic swap and the backup,
        # and skips the rewrite when the file is already identical.
        if (-not (Install-RemoteFile -Url $script:AppConfig.URLs.WindowsTerminalSettings `
                    -Destination $SettingsPath -MinimumBytes 64 -Backup)) {
            return $false
        }
        return $true
    }
    catch {
        Write-ToolkitLog -Level 'WARNING' -Message "Windows Terminal settings update skipped: $($_.Exception.Message)"
        return $false
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
        # .Accepted, not `-eq 0`: a rerun on an already installed font returns
        # 0x8A150061, which is a success for the setup, not a failure.
        $result = Invoke-WingetInstall -Id 'DEVCOM.JetBrainsMonoNerdFont'

        if (-not $result.Accepted) {
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

    # The availability check is done ONCE, before the loop: inside it every tool
    # used to print its "checking" message and then silently skip.
    $wingetAvailable = [bool](Get-WinGetExecutable)
    foreach ($tool in $tools) {
        if (-not $wingetAvailable) {
            $result.Tools.Failed += "$($tool.Name) (WinGet not available)"
            continue
        }
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.check0' -Args @($tool.Name))
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { continue }
        $toolResult = Invoke-WingetInstall -Id $tool.Id -Exact
        if ($toolResult.Accepted) {
            $result.Tools.Installed += $tool.Name
        }
        else {
            # -2147012859 (0x800706BA) is not "the package is already installed": it is
            # the App Installer deployment server refusing the session, and it makes
            # every following install fail the same way. It must be named, not
            # swallowed as a generic non-zero exit code.
            if (Test-WingetRpcFailure -Result $toolResult) { $result.WingetRpcFailure = $true }
            $result.Tools.Failed += "$($tool.Name) (exit $($toolResult.ExitCode))"
            Write-ToolkitLog -Level 'WARNING' -Message "Tool $($tool.Id) install returned exit code $($toolResult.ExitCode)."
        }
    }

    # 2. Oh My Posh theme: always in the PowerShell 7 profile folder, because the
    #    profile is specific to PS7 and Windows Terminal. The folder is RESOLVED and
    #    CREATED here: [Environment]::GetFolderPath('MyDocuments') returns '' when the
    #    Documents known folder is empty or unresolved, and '' + '\PowerShell' silently
    #    redirected the whole installation to <drive>:\PowerShell.
    $paths = $null
    try {
        $paths = Resolve-ToolkitPowerShellProfileDirectory
        Write-ToolkitLog -Level 'INFO' -Message "PowerShell profile directory resolved: $($paths.ProfileDirectory)"
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.profileDirectoryUnavailable0' -Args @($_.Exception.Message))
        $result.Success = $false
        $result.Message = "Unable to prepare the PowerShell profile directory: $($_.Exception.Message)"
        Write-ToolkitLog -Level 'ERROR' -Message $result.Message
        return $result
    }

    $result.ProfilePath = $paths.ProfilePath
    $result.ThemePath = $paths.ThemePath
    # Theme: several candidate endpoints, and the payload must be real JSON.
    $themeUris = @($script:AppConfig.URLs.OhMyPoshThemeFallback)
    if ($themeUris.Count -eq 0) { $themeUris = @($script:AppConfig.URLs.OhMyPoshThemeUrls) }
    if ($themeUris.Count -eq 0) { $themeUris = @($script:AppConfig.URLs.OhMyPoshTheme) }
    if (Invoke-DownloadFile -Uri $themeUris -OutFile $paths.ThemePath `
            -MinimumBytes $script:AppConfig.UserScope.MinThemeFileBytes `
            -ContentValidator { param($candidatePath) Test-OhMyPoshThemeFile -Path $candidatePath }) {
        $result.ThemeOk = $true
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.ohMyPoshThemeDownloaded')
        Write-ToolkitLog -Level 'INFO' -Message "Oh My Posh theme installed: $($paths.ThemePath)"
    }
    else {
        $result.Success = $false
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.ohMyPoshThemeDownloadFailed0' -Args @($paths.ThemePath))
    }

    # 3. Font Installation (the result is captured: it used to be discarded by *>$null)
    $result.FontOk = Install-NerdFontsLocal
    if (-not $result.FontOk) { $result.Success = $false }

    # 4. Profile configuration: installed through Install-RemoteFile, which stages
    #    the download, swaps it in atomically and only backs up a file that really
    #    changed. The final artifact is then re-read from disk before it is
    #    reported as configured.
    $targetProfile = $paths.ProfilePath
    try {
        if (Install-RemoteFile -Url $script:AppConfig.URLs.PowerShellProfile `
                -Destination $targetProfile -MinimumBytes $script:AppConfig.MinProfileBytes -Backup) {
            if (Test-FileHasMinimumSize -Path $targetProfile -MinimumBytes $script:AppConfig.MinProfileBytes) {
                $result.ProfileOk = $true
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7ProfileConfigured')
                Write-ToolkitLog -Level 'INFO' -Message "PowerShell profile installed: $targetProfile"
            }
            else {
                $result.Success = $false
                Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.profileNotInstalled0' -Args @($targetProfile))
            }
        }
        else {
            $result.Success = $false
            Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.profileNotInstalled0' -Args @($targetProfile))
        }
    }
    catch {
        $result.Success = $false
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.profileConfigurationError0' -Args @($_.Exception.Message))
    }

    if (-not $result.ProfileOk -or -not $result.ThemeOk) {
        $result.Message = "PowerShell environment incomplete (profile installed: $($result.ProfileOk), theme installed: $($result.ThemeOk))."
    }

    if (-not $result.ProfileOk -or -not $result.ThemeOk) {
        $result.Message = "PowerShell environment incomplete (profile installed: $($result.ProfileOk), theme installed: $($result.ThemeOk))."
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

    if ($result.WingetRpcFailure) {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.wingetRpcFailureDetected')
        $result.Message += ' WinGet failed with 0x800706BA (App Installer deployment server unavailable): the CLI tools were NOT installed.'
    }
    return $result
}
