function Find-WinGet {
    <#
    .SYNOPSIS
    Finds the WinGet executable location.
    #>
    try {
        $wingetPathToResolve = Join-Path -Path $ENV:ProgramFiles -ChildPath 'Microsoft.DesktopAppInstaller_*_*__8wekyb3d8bbwe'
        $resolveWingetPath = Resolve-Path -Path $wingetPathToResolve -ErrorAction Stop | Sort-Object {
            [version]($_.Path -replace '^[^\d]+_((\d+\.)*\d+)_.*', '$1')
        }

        if ($ResolveWinGetPath) {
            $wingetPath = $resolveWingetPath[-1].Path[-1].Path
        }

        $wingetExe = Join-Path $wingetPath 'winget.exe'

        if (Test-Path -Path $wingetExe) {
            return $wingetExe
        }
        else {
            return $null
        }
    }
    catch {
        return $null
    }
}
