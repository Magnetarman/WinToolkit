function Install-NuGetIfRequired {
    <#
    .SYNOPSIS
    Checks if NuGet PackageProvider is installed and installs it if required.
    #>
    
    if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            try {
                Install-PackageProvider -Name "NuGet" -Force -ForceBootstrap -ErrorAction SilentlyContinue *>$null
                Write-StyledMessage -Type Info -Text "NuGet provider installato."
            }
            catch {
                Write-StyledMessage -Type Warning -Text "Impossibile installare NuGet provider."
            }
        }
    }
}
