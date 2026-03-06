function Test-WingetCompatibility {
    $osInfo = [Environment]::OSVersion
    $build = $osInfo.Version.Build

    if ($osInfo.Version.Major -lt 10) {
        Write-StyledMessage -Type Error -Text "Winget non supportato su Windows $($osInfo.Version.Major)."
        return $false
    }

    if ($osInfo.Version.Major -eq 10 -and $build -lt 16299) {
        Write-StyledMessage -Type Error -Text "Windows 10 build $build non supporta Winget."
        return $false
    }

    return $true
}
