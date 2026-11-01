

# ==============================================================================
# SECTION 6 · ENVIRONMENT — PATHS AND INITIALIZATION
# Working directory creation and process PATH refresh.
# ==============================================================================

function Initialize-ToolkitPaths {
    <#
    .SYNOPSIS
        Ensures creation of all required directories on first run.
    #>
    foreach ($path in $AppConfig.Paths.Values) {
        if (-not (Test-Path $path -PathType Leaf) -and $path -notmatch "\.exe$|\.zip$|\.msixbundle$") {
            try {
                if (-not (Test-Path $path)) { $null = New-Item -Path $path -ItemType Directory -Force -ErrorAction SilentlyContinue }
            }
            catch {
                Write-Warning "wintoolkit-modules\50-Module.Environment.ps1, Initialize-ToolkitPaths: $($_.Exception.Message)"
            }
        }
    }
}


function Update-EnvironmentPath {
    <#
    .SYNOPSIS
        Reloads PATH from the system and user variables for the current session.
    #>
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $newPath = ($machinePath, $userPath | Where-Object { $_ }) -join ';'
    $env:Path = $newPath
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'Process')
}


function Set-RegistryValue {
    <#
    .SYNOPSIS
        Creates the registry key if missing and sets the specified value.
    #>
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    if (-not (Test-Path $Path)) { $null = New-Item -Path $Path -Force }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
}
