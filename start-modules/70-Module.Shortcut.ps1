# ============================================================================
# DESKTOP SHORTCUT
# ============================================================================

function Update-ShellDesktopCache {
    <#
    .SYNOPSIS
    Tells Explorer that the desktop changed, so the new shortcut appears at once.
    #>
    try {
        $signature = @'
[DllImport("shell32.dll", CharSet = CharSet.Auto, SetLastError = false)]
public static extern void SHChangeNotify(int eventId, uint flags, IntPtr item1, IntPtr item2);
'@
        $shell32 = Add-Type -MemberDefinition $signature -Name 'WinToolkitShell32' -Namespace 'WinToolkit' -PassThru
        # SHCNE_ASSOCCHANGED (0x08000000) | SHCNF_IDLIST (0x0000)
        $shell32::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero)
        return $true
    }
    catch {
        # Purely cosmetic: the shortcut exists even when Explorer is not notified.
        Write-ToolkitLog -Level 'DEBUG' -Message "SHChangeNotify unavailable: $($_.Exception.Message)"
        return $false
    }
}


function New-ToolkitDesktopShortcut {
    <#
    .SYNOPSIS
    Creates the "Win Toolkit" desktop shortcut and flags it to run elevated.

    .DESCRIPTION
    The desktop is resolved through Get-ToolkitUserFolderPath and the resulting
    file is verified twice: once after Save() and once after the RunAs bit patch.
    Reporting success without those checks is exactly how a shortcut could be
    logged as created while the user never saw it.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.desktopShortcutCreation')

    try {
        $desktop = Get-ToolkitUserFolderPath -Kind 'Desktop'
    # The desktop is user-scoped: a shortcut created in another account's desktop
    # is reported as created and never seen by the signed-in user.
    if (-not (Test-ToolkitPathBelongsToInteractiveUser -Path $desktop)) {
        Write-ToolkitLog -Level 'WARNING' -Message "Desktop shortcut target belongs to another account: $desktop"
    }
        $shortcut = Join-Path $desktop "Win Toolkit.lnk"
        $iconDir = $script:AppConfig.Paths.WinToolkitDir
        $icon = Join-Path $iconDir "WinToolkit.ico"

        $null = Initialize-Directory -Path $iconDir

        # Download the icon unless a previous run left a usable one: the size check
        # rejects partial downloads and HTML error pages saved as .ico.
        if (-not (Test-FileHasMinimumSize -Path $icon -MinimumBytes $script:MIN_ICON_FILE_BYTES)) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.downloadIcon')
            $null = Invoke-DownloadFile -Uri $script:AppConfig.URLs.ToolkitIcon -OutFile $icon -MinimumBytes $script:MIN_ICON_FILE_BYTES
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
        if (-not (Test-Path -LiteralPath $shortcut -PathType Leaf)) {
            throw "The shortcut was not written to '$shortcut'."
        }

        # Enable "run as administrator" by setting the flag bit in the .lnk
        # header (MS-SHLLINK). Validate the length first: a shorter file means
        # WScript.Shell produced something unexpected.
        $bytes = [IO.File]::ReadAllBytes($shortcut)
        if ($bytes.Length -le $script:LNK_RUNAS_ADMIN_BYTE_OFFSET) {
            throw "Unexpected .lnk layout: file is only $($bytes.Length) bytes."
        }
        $bytes[$script:LNK_RUNAS_ADMIN_BYTE_OFFSET] = $bytes[$script:LNK_RUNAS_ADMIN_BYTE_OFFSET] -bor $script:LNK_RUNAS_ADMIN_BIT
        [IO.File]::WriteAllBytes($shortcut, $bytes)

        # Final proof: the file is on disk, at the path that was reported.
        if (-not (Test-Path -LiteralPath $shortcut -PathType Leaf)) {
            throw "The shortcut disappeared from '$shortcut' after the elevation flag was set."
        }
        $null = Update-ShellDesktopCache

        Write-ToolkitLog -Level 'INFO' -Message "Desktop shortcut created: $shortcut"
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.shortcutCreatedSuccessfully')
        return New-StepResult -Success $true -Changed $true -Message 'Desktop shortcut created.'
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.shortcutCreationError0' -Args @($_.Exception.Message))
        Write-ToolkitLog -Level 'ERROR' -Message "Desktop shortcut creation failed: $($_.Exception.Message)"
        return New-StepResult -Success $false -Message $_.Exception.Message
    }
}
