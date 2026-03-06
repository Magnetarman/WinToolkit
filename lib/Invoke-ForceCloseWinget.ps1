function Invoke-ForceCloseWinget {
    <#
    .SYNOPSIS
    Closes the processes that actually block Appx installation.
    Safe approach that avoids killing system-critical processes.
    #>
    Write-StyledMessage -Type Info -Text "Chiusura processi interferenti..."
    
    # Lista mirata dei processi che bloccano effettivamente l'installazione Appx
    $interferingProcesses = @(
        "WinStore.App",
        "wsappx",
        "AppInstaller",
        "Microsoft.WindowsStore",
        "Microsoft.DesktopAppInstaller",
        "winget",
        "WindowsPackageManagerServer"
    )

    foreach ($procName in $interferingProcesses) {
        Get-Process -Name $procName -ErrorAction SilentlyContinue | 
        Where-Object { $_.Id -ne $PID } |  # Don't kill ourselves
        Stop-Process -Force -ErrorAction SilentlyContinue
    }
    
    Start-Sleep 2
    Write-StyledMessage -Type Success -Text "Processi interferenti chiusi."
}
