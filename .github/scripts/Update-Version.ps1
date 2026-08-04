<#
.SYNOPSIS
    Increments the build number in the WinToolkit template.

.DESCRIPTION
    This script reads the WinToolkit-template.ps1 file, extracts the current version,
    increments the build number, and saves the updated file.

.EXAMPLE
    .\Update-Version.ps1 -TemplatePath "WinToolkit-template.ps1"

.NOTES
    Author: MagnetarMan
    Version: 1.0.5
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TemplatePath = "WinToolkit-template.ps1"
)

# --- PowerShell Best Practices ---
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Output variables ---
$script:NewVersion = $null
$script:BuildNumber = $null
$script:OldVersion = $null

function Write-StatusMessage {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )

    $colors = @{
        'Info'    = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $colors[$Type]
}

try {
    Write-StatusMessage -Message "========================================" -Type Info
    Write-StatusMessage -Message "  INCREMENTING BUILD NUMBER" -Type Info
    Write-StatusMessage -Message "========================================" -Type Info

    # Verify the file exists
    if (-not (Test-Path $TemplatePath)) {
        Write-StatusMessage -Message "❌ File $TemplatePath not found" -Type Error
        exit 1
    }

    # Read the file content
    Write-StatusMessage -Message "📖 Reading file: $TemplatePath" -Type Info
    $content = Get-Content -Path $TemplatePath -Raw

    # Find the version line and extract the build number
    $versionPattern = '\$ToolkitVersion\s*=\s*[''"](.+?)[''"]'

    if ($content -match $versionPattern) {
        $script:OldVersion = $matches[1]
        Write-StatusMessage -Message "📋 Current version: $script:OldVersion" -Type Success

        # Extract the build number (number in parentheses)
        $buildPattern = 'Build\s+(\d+)'

        if ($script:OldVersion -match $buildPattern) {
            $currentBuild = [int]$matches[1]
            $script:BuildNumber = $currentBuild + 1

            # Build the new version maintaining the same format
            $script:NewVersion = $script:OldVersion -replace "Build\s+$currentBuild", "Build $script:BuildNumber"

            Write-StatusMessage -Message "🔄 Build increment: $currentBuild → $script:BuildNumber" -Type Warning
            Write-StatusMessage -Message "🆕 New version: $script:NewVersion" -Type Success

            # Replace the version line
            $newLine = "`$ToolkitVersion = `"$script:NewVersion`""
            $content = $content -replace '\$ToolkitVersion\s*=\s*[''"](.+?)[''"]', $newLine

            # Write the updated file atomically (temp + rename)
            $tempPath = "$TemplatePath.tmp"
            $content | Set-Content -Path $tempPath -Encoding UTF8
            Move-Item $tempPath $TemplatePath -Force

            Write-StatusMessage -Message "✅ Version incremented successfully" -Type Success
        }
        else {
            Write-StatusMessage -Message "❌ Unable to find the build number in the version" -Type Error
            exit 1
        }
    }
    else {
        Write-StatusMessage -Message "❌ Unable to find the version line in the template" -Type Error
        exit 1
    }

    # Output for GitHub Actions
    Write-Output "new_version=$script:NewVersion" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    Write-Output "build_number=$script:BuildNumber" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    Write-Output "old_version=$script:OldVersion" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append

    Write-StatusMessage -Message "========================================" -Type Info
    Write-StatusMessage -Message "  COMPLETE" -Type Info
    Write-StatusMessage -Message "========================================" -Type Info

    exit 0
}
catch {
    Write-StatusMessage -Message "❌ ERROR: $($_.Exception.Message)" -Type Error
    Write-StatusMessage -Message "Stack Trace: $($_.ScriptStackTrace)" -Type Error
    exit 1
}
