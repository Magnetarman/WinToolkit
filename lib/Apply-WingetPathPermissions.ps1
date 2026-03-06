function Apply-WingetPathPermissions {
    <#
    .SYNOPSIS
    Applies PATH permissions and adds winget folder to PATH.
    Based on asheroto's Apply-PathPermissionsFixAndAddPath.
    #>
    
    $wingetFolderPath = $null
    
    try {
        # Find winget folder
        $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
        $wingetDir = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" -Filter "Microsoft.DesktopAppInstaller_*_*${arch}__8wekyb3d8bbwe" -ErrorAction SilentlyContinue | 
        Sort-Object Name -Descending | Select-Object -First 1
        
        if ($wingetDir) {
            $wingetFolderPath = $wingetDir.FullName
        }
    }
    catch { }

    if ($wingetFolderPath) {
        # Fix permissions
        Set-PathPermissions -FolderPath $wingetFolderPath
        
        # Add to system PATH
        Add-ToEnvironmentPath -PathToAdd $wingetFolderPath -Scope 'System'
        
        # Add user PATH with literal %LOCALAPPDATA%
        Add-ToEnvironmentPath -PathToAdd "%LOCALAPPDATA%\Microsoft\WindowsApps" -Scope 'User'
        
        Write-StyledMessage -Type Success -Text "PATH e permessi winget aggiornati."
    }
}
