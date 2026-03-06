function Test-VCRedistInstalled {
    <#
    .SYNOPSIS
    Checks if Visual C++ Redistributable is installed and verifies the major version is 14.
    #>
    
    $64BitOS = [System.Environment]::Is64BitOperatingSystem
    $64BitProcess = [System.Environment]::Is64BitProcess

    # Require running system native process
    if ($64BitOS -and -not $64BitProcess) {
        Write-StyledMessage -Type Warning -Text "Esegui PowerShell nativo (x64)."
        return $false
    }

    # Check registry
    $registryPath = [string]::Format(
        'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\{0}\Microsoft\VisualStudio\14.0\VC\Runtimes\X{1}',
        $(if ($64BitOS -and $64BitProcess) { 'WOW6432Node' } else { '' }),
        $(if ($64BitOS) { '64' } else { '86' })
    )

    $registryExists = Test-Path -Path $registryPath

    # Check major version
    $majorVersion = if ($registryExists) {
        (Get-ItemProperty -Path $registryPath -Name 'Major' -ErrorAction SilentlyContinue).Major
    }
    else { 0 }

    # Check DLL exists
    $dllPath = [string]::Format('{0}\system32\concrt140.dll', $env:windir)
    $dllExists = [System.IO.File]::Exists($dllPath)

    return $registryExists -and $majorVersion -eq 14 -and $dllExists
}
