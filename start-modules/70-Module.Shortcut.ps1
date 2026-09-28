# ============================================================================
# DESKTOP SHORTCUT
# ============================================================================

function New-ToolkitDesktopShortcut {
    <#
    .SYNOPSIS
    Creates the "Win Toolkit" desktop shortcut and flags it to run elevated.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.desktopShortcutCreation')

    try {
        $desktop = $script:AppConfig.Paths.Desktop
        $shortcut = Join-Path $desktop "Win Toolkit.lnk"
        $iconDir = $script:AppConfig.Paths.WinToolkitDir
        $icon = Join-Path $iconDir "WinToolkit.ico"

        $null = Initialize-Directory -Path $iconDir

        # Download the icon unless a previous run left a usable one: the size check
        # rejects partial downloads and HTML error pages saved as .ico.
        if (-not (Test-FileHasMinimumSize -Path $icon -MinimumBytes $script:MIN_ICON_FILE_BYTES)) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadIcona')
            $null = Invoke-DownloadFile -Uri $script:AppConfig.URLs.ToolkitIcon -OutFile $icon
        }

        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($shortcut)
        $link.TargetPath = $script:AppConfig.Paths.wtExe
        $link.Arguments = 'pwsh -ExecutionPolicy Bypass -Command "irm ' + $script:AppConfig.URLs.WebInstaller + ' | iex"'
        $link.WorkingDirectory = $script:AppConfig.Paths.wtDir

        if (Test-FileHasMinimumSize -Path $icon -MinimumBytes $script:MIN_ICON_FILE_BYTES) {
            $link.IconLocation = $icon
        }
        $link.Description = "Win Toolkit - Master Windows with Ease"
        $link.Save()

        # Enable "run as administrator" by setting the flag bit in the .lnk
        # header (MS-SHLLINK). Validate the length first: a shorter file means
        # WScript.Shell produced something unexpected.
        $bytes = [IO.File]::ReadAllBytes($shortcut)
        if ($bytes.Length -le $script:LNK_RUNAS_ADMIN_BYTE_OFFSET) {
            throw "Unexpected .lnk layout: file is only $($bytes.Length) bytes."
        }
        $bytes[$script:LNK_RUNAS_ADMIN_BYTE_OFFSET] = $bytes[$script:LNK_RUNAS_ADMIN_BYTE_OFFSET] -bor $script:LNK_RUNAS_ADMIN_BIT
        [IO.File]::WriteAllBytes($shortcut, $bytes)

        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.shortcutCreatedSuccessfully')
        return $true
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.shortcutCreationError0' -Args @($_.Exception.Message))
        return $false
    }
}
