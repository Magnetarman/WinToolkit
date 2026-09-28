# ============================================================================
# INSTALLERS: Visual C++ Redistributable, Git, PowerShell 7, Windows Terminal
# ============================================================================

function Test-VCRedistRuntime {
    <#
    .SYNOPSIS
    Returns $true when one VC++ runtime is registered with major version 14 and its DLL exists.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RuntimeName,
        [Parameter(Mandatory = $true)][string]$DllPath
    )

    $registryPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\$RuntimeName"
    if (-not (Test-Path -Path $registryPath)) { return $false }

    $major = (Get-ItemProperty -Path $registryPath -Name 'Major' -ErrorAction SilentlyContinue).Major
    return [bool]($major -eq 14 -and [System.IO.File]::Exists($DllPath))
}


function Test-VCRedistInstalled {
    <#
    .SYNOPSIS
    Checks if Visual C++ Redistributable is installed and verifies the major version is 14.

    .DESCRIPTION
    The 32-bit runtime is enough on 32-bit systems; on x64/ARM64 systems BOTH the
    32-bit and the native runtime must be present.
    #>
    $architecture = Get-SystemArchitecture
    $checksPassed = 0

    if (Test-VCRedistRuntime -RuntimeName 'x86' -DllPath "$env:windir\syswow64\concrt140.dll") { $checksPassed++ }
    if ($architecture -ne 'X86') {
        $nativeRuntime = Get-ArchitectureSpecificValue -X64 'x64' -ARM64 'arm64'
        if (Test-VCRedistRuntime -RuntimeName $nativeRuntime -DllPath "$env:windir\system32\concrt140.dll") { $checksPassed++ }
    }

    $requiredChecks = if ($architecture -eq 'X86') { 1 } else { 2 }
    return $checksPassed -eq $requiredChecks
}


function Install-GitPackage {
    <#
    .SYNOPSIS
    Verifies and installs Git with direct download fallback.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.verifyGitInstallation')

    Update-EnvironmentPath

    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.gitAlreadyInstalled')
        return $true
    }

    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.gitInstallation')

    # 1. Preferred path: WinGet.
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $result = Invoke-WingetInstall -Id 'Git.Git'

        if ($result.Accepted) {
            Update-EnvironmentPath

            if (Wait-Until -Condition { Test-CommandExists -Name git } -TimeoutSeconds 15 -IntervalMs 1000) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.gitInstalledViaWinget')
                return $true
            }
        }
    }

    # 2. Fallback: direct download from GitHub
    try {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.fallbackDownloadGitDaGithub')
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.runningGitInstaller')
        $assetPattern = Get-ArchitectureSpecificValue -X64 '64-bit\.exe$' -X86 '32-bit\.exe$' -ARM64 'arm64\.exe$'
        $installResult = Install-FromGitHubRelease -ReleaseApiUrl $script:AppConfig.URLs.GitRelease `
            -AssetPattern $assetPattern -ExecutablePath '{INSTALLER}' `
            -InstallerArguments @('/SILENT', '/NORESTART', '/CLOSEAPPLICATIONS')
        if ($installResult.Success) {
            Update-EnvironmentPath
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.gitInstalledSuccessfully')
            return $true
        }

        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.installationFailedCode0' -Args @($installResult.ExitCode))
        # -1 means "the helper never even reached the installer": without this the log
        # only showed the code and the real reason (rate limit, DNS, 404) was lost.
        if ($installResult.PSObject.Properties.Name -contains 'Error' -and $installResult.Error) {
            Write-ToolkitLog -Level 'ERROR' -Message "Git installer fallback error: $($installResult.Error)"
        }
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.gitInstallationError0' -Args @($_.Exception.Message))
        return $false
    }
}


function Install-PowerShellCore {
    <#
    .SYNOPSIS
    Verifies and installs PowerShell 7 with direct download fallback.

    .DESCRIPTION
    This is the "application level" PowerShell 7 install: the start.ps1 stub only
    guarantees that some working pwsh exists so that start-core.ps1 can run at all.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.verificaPowershell7')

    $ps7Path64 = "$env:SystemDrive\Program Files\PowerShell\7"
    $ps7Path32 = "$env:SystemDrive\Program Files (x86)\PowerShell\7"

    if ((Test-Path $ps7Path64) -or (Test-Path $ps7Path32) -or (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7AlreadyInstalled')
        return $true
    }

    # 1. Preferred path: WinGet.
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.attemptingToInstallPowershell7ViaWinget')
        $result = Invoke-WingetCommand -Arguments "install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements --silent"

        if ($result.ExitCode -eq 0) {
            if (Wait-Until -Condition {
                    (Test-Path $ps7Path64) -or (Test-Path $ps7Path32) -or (Test-CommandExists -Name pwsh)
                } -TimeoutSeconds 15 -IntervalMs 1000) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7InstallatoViaWinget')
                return $true
            }
        }
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetInstallationFailedOrFailedExitcode0FallbackToDirectDownload' -Args @($result.ExitCode))
    }

    # 2. Fallback: direct MSI download from GitHub
    try {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.recuperoUltimaReleasePowershell')
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.installingPowershell7InProgress')
        $assetPattern = Get-ArchitectureSpecificValue -X64 'win-x64\.msi$' -X86 'win-x86\.msi$' -ARM64 'win-arm64\.msi$'
        $installerArguments = @('/i', '{INSTALLER}', '/norestart', '/passive',
            'ADD_PATH=1', 'ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1', 'REGISTER_MANIFEST=1')
        # PSRemoting reconfigures WinRM/firewall: opt-in only.
        if ($script:AppConfig.EnablePSRemoting) {
            $installerArguments += 'ENABLE_PSREMOTING=1'
        }
        $installResult = Install-FromGitHubRelease -ReleaseApiUrl $script:AppConfig.URLs.PowerShellRelease `
            -AssetPattern $assetPattern -ExecutablePath 'msiexec.exe' `
            -InstallerArguments $installerArguments `
            -AcceptedExitCodes @(0, 1641, 3010)

        if ((Test-Path $ps7Path64) -or (Test-Path $ps7Path32) -or (Test-CommandExists -Name pwsh) -or $installResult.Success) {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.powershell7InstalledSuccessfully')
            return $true
        }
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.installationFailedCode02' -Args @($installResult.ExitCode))
        return $false
    }
    catch {
        Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.powershellInstallationError0' -Args @($_.Exception.Message))
        return $false
    }
}


function Test-WindowsTerminalInstalled {
    $command = Get-Command 'wt.exe' -ErrorAction SilentlyContinue
    return [bool]($command -and $command.Source -and (Test-Path -LiteralPath $command.Source))
}


function Test-WindowsTerminalDefaultSupported {
    <#
    .SYNOPSIS
    Windows Terminal can only be set as the default terminal application on
    Windows 11, or Windows 10 22H2 with KB5026435 (build 19045.3031) or newer.
    #>
    $version = [Environment]::OSVersion.Version
    if ($version.Build -ge 22000) { return $true }
    if ($version.Build -eq 19045 -and $version.Revision -ge 3031) { return $true }
    return $false
}


function Install-WindowsTerminalApp {
    <#
    .SYNOPSIS
    Verifies and installs Windows Terminal with multiple fallback methods.
    #>
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.windowsTerminalConfiguration')

    if (Test-WindowsTerminalInstalled) {
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.windowsTerminalIsAlreadyInstalled')
        return $true
    }

    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.windowsTerminalInstallationInProgress')
    $tempFile = $null
    try {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.attemptingToInstallWindowsTerminalViaWinget')
            # Use the unambiguous package identifier, not the Store product id.
            $result = Invoke-WingetInstall -Id 'Microsoft.WindowsTerminal'
            if ($result.Accepted -and (Wait-Until -Condition { Test-WindowsTerminalInstalled })) {
                Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.windowsTerminalInstalledViaWinget')
                return $true
            }
            Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetInstallationForWindowsTerminalFailed')
        }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.wingetInstallationForWindowsTerminalFailed' -Args @($_.Exception.Message))
    }

    try {
        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.retrieveUrlLatestReleaseOfWindowsTerminal')
        $latestRel = Invoke-RestMethod -Uri $script:AppConfig.URLs.TerminalRelease -UseBasicParsing
        $asset = $latestRel.assets |
        Where-Object { $_.name -match '^Microsoft\.WindowsTerminal_.*\.msixbundle$' } |
        Select-Object -First 1

        if (-not $asset) {
            throw (Get-SourceTextLoc 'uiText.windowsTerminalAssetMsixbundleNotFound')
        }
        $downloadUrl = $asset.browser_download_url

        Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.iTryNativeAppxInstallationFromDownloadedBundle')
        $tempFile = Join-Path $env:TEMP "WinTerminal.msixbundle"
        if (-not (Invoke-DownloadFile -Uri $downloadUrl -OutFile $tempFile)) {
            throw (Get-SourceTextLoc 'uiText.windowsTerminalAppxInstallationFailed')
        }

        if (Start-AppxSilentProcess -AppxPath $tempFile -Flags '-ForceApplicationShutdown' -ExpectedPackageName 'Microsoft.WindowsTerminal') {
            Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.windowsTerminalAppxInstallationSuccessful')
        }
        else {
            throw (Get-SourceTextLoc 'uiText.windowsTerminalAppxInstallationFailed')
        }
        if (-not (Wait-Until -Condition { Test-WindowsTerminalInstalled } -TimeoutSeconds 30 -IntervalMs 1000)) {
            throw 'Windows Terminal package installed but wt.exe was not detected.'
        }
        return $true
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.standardWindowsTerminalInstallationFailed0FallbackToTheMicrosoftStore' -Args @($_.Exception.Message))
    }
    finally {
        if ($tempFile -and (Test-Path -LiteralPath $tempFile)) {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    if (Test-WindowsTerminalInstalled) {
        return $true
    }

    # Last resort: open the Store page. This is not an automatic installation,
    # so the caller must treat it as a failure, not as a completed step.
    Write-StyledMessage -Type Info -Text (Get-SourceTextLoc 'uiText.fallbackAperturaMicrosoftStorePerWindowsTerminal')
    Start-Process "ms-windows-store://pdp/?ProductId=9N0DX20HK701"
    Write-StyledMessage -Type Error -Text (Get-SourceTextLoc 'uiText.unableToInstallWindowsTerminalViaAnyAutomaticMethod')
    return $false
}


function Set-WindowsTerminalAsDefault {
    <#
    .SYNOPSIS
    Registers Windows Terminal as the default terminal application, when the
    running Windows build actually supports the delegation registry keys.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not (Test-WindowsTerminalDefaultSupported)) {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.defaultTerminalNotSupportedOnThisBuild')
        return [pscustomobject]@{ Success = $true; Changed = $false; Message = 'Default terminal not supported on this build.' }
    }

    if (-not $PSCmdlet.ShouldProcess('Windows Terminal', 'Set as default terminal application')) {
        return [pscustomobject]@{ Success = $true; Changed = $false; Message = 'WhatIf: default terminal not changed.' }
    }

    Write-StyledMessage -Type Info -Text ("⚙️ " + (Get-SourceTextLoc 'uiText.settingWindowsTerminalAsDefaultViaRegistry'))
    try {
        $registryPath = $script:AppConfig.Registry.TerminalStartup
        if (-not (Test-Path $registryPath)) { $null = New-Item -Path $registryPath -Force }

        Set-ItemProperty -Path $registryPath -Name 'DelegationTerminal' -Value $script:AppConfig.WindowsTerminal.DelegationTerminalClsid -Force
        Set-ItemProperty -Path $registryPath -Name 'DelegationConsole' -Value $script:AppConfig.WindowsTerminal.DelegationConsoleClsid -Force
        Write-StyledMessage -Type Success -Text (Get-SourceTextLoc 'uiText.windowsTerminalSetAsDefault')
        return [pscustomobject]@{ Success = $true; Changed = $true; Message = 'Windows Terminal set as default.' }
    }
    catch {
        Write-StyledMessage -Type Warning -Text (Get-SourceTextLoc 'uiText.failedToSetDefaultTerminal0' -Args @($_.Exception.Message))
        return [pscustomobject]@{ Success = $false; Changed = $false; Message = $_.Exception.Message }
    }
}
