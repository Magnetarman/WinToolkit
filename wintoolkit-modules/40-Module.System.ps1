

# SECTION 5 · SYSTEM — INFORMATION AND STATUS
# Data collection on the operating system, hardware and security services.
# ==============================================================================

function Get-SystemInfo {
    if ($Global:SystemInfoCache) { return $Global:SystemInfoCache }
    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem
        $computerInfo = Get-CimInstance Win32_ComputerSystem
        $diskInfo = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        $versionMap = @{
            28000 = "26H1"; 26200 = "25H2"; 26100 = "24H2"; 22631 = "23H2"; 22621 = "22H2"; 22000 = "21H2"
            19045 = "22H2"; 19044 = "21H2"; 19043 = "21H1"; 19042 = "20H2"; 19041 = "2004"; 18363 = "1909"
            18362 = "1903"; 17763 = "1809"; 17134 = "1803"; 16299 = "1709"; 15063 = "1703"; 14393 = "1607"
            10586 = "1511"; 10240 = "1507"
        }
        $build = [int]$osInfo.BuildNumber
        $ver = "N/A"
        foreach ($k in ($versionMap.Keys | Sort-Object -Descending)) { if ($build -ge $k) { $ver = $versionMap[$k]; break } }

        $Global:SystemInfoCache = @{
            ProductName    = $osInfo.Caption -replace 'Microsoft ', ''
            BuildNumber    = $build
            DisplayVersion = $ver
            Architecture   = $osInfo.OSArchitecture
            ComputerName   = $computerInfo.Name
            TotalRAM       = [Math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
            TotalDisk      = [Math]::Round($diskInfo.Size / 1GB, 0)
            FreeDisk       = [Math]::Round($diskInfo.FreeSpace / 1GB, 0)
            FreePercentage = [Math]::Round(($diskInfo.FreeSpace / $diskInfo.Size) * 100, 0)
        }
        return $Global:SystemInfoCache
    }
    catch { return $null }
}

function Convert-BitlockerStatusToKey {
    param([string]$StatusText)

    if ([string]::IsNullOrWhiteSpace($StatusText)) { return 'bitlocker.status.notConfigured' }

    $normalized = $StatusText.Trim().ToLowerInvariant()
    if ($normalized -match 'decritt|decrypt') { return 'bitlocker.status.decrypting' }
    if ($normalized -match 'crittografia in corso|encrypt') { return 'bitlocker.status.encrypting' }
    if ($normalized -match 'sospes|suspend') { return 'bitlocker.status.suspended' }
    if ($normalized -match 'non configur|not configured') { return 'bitlocker.status.notConfigured' }
    if ($normalized -match 'disattiv|protection off|off|disabled') { return 'bitlocker.status.off' }
    if ($normalized -match 'attiv|protection on|on|enabled') { return 'bitlocker.status.on' }

    return 'bitlocker.status.unknown'
}

function Get-BitlockerStatus {
    param([switch]$Key)

    try {
        $out = & manage-bde -status C: 2>&1
        $statusText = $null
        if ($out -match "(?im)^\s*(Stato protezione|Protection Status):\s*(.*)$") {
            $statusText = $matches[2].Trim()
        }

        $statusKey = Convert-BitlockerStatusToKey -StatusText $statusText
        if ($Key) { return $statusKey }
        return (Get-SourceTextLoc $statusKey)
    }
    catch {
        if ($Key) { return 'bitlocker.status.off' }
        return (Get-SourceTextLoc 'bitlocker.status.off')
    }
}


function Get-SourceTextLocalUserProfiles {
    <#
    .SYNOPSIS
        Restituisce le directory utente reali, escludendo i profili di sistema.
    #>
    return Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '^(Public|Default|Default User|All Users)$' }
}