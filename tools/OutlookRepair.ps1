function OutlookRepair {
    <#
    .SYNOPSIS
        Repairs Microsoft Outlook Classic profiles.
    .DESCRIPTION
        Attaches to the current Outlook profile via COM, distinguishes cloud accounts
        (Exchange/IMAP) from local archives (POP3/PST) and applies a differentiated
        repair strategy:
          * Cloud accounts -> safely empties the "Deleted Items" folder.
          * Local PST archives -> launches SCANPST.EXE (GUI, requires manual interaction).
    .PARAMETER NoWaitForScanPst
        Launches SCANPST without waiting for the GUI to close.
    .PARAMETER SuppressIndividualReboot
        Suppresses the individual reboot (used in multi-script execution).
    .PARAMETER CountdownSeconds
        Seconds in the countdown before restarting.
    .NOTES
        Requires PowerShell 7 and Microsoft Outlook Classic installed.
    #>
    [CmdletBinding()]
    param(
        [switch]$NoWaitForScanPst,
        [switch]$SuppressIndividualReboot,
        [int]$CountdownSeconds = 30
    )

    # Standard tool session initialization (log file, header, window title).
    Start-ToolkitSession -ToolName "OutlookRepair" -SubTitle (Get-SourceTextLoc 'script.OutlookRepair')

    # Outlook Object Model constants.
    $olFolderDeletedItems = 3   # Deleted Items folder
    $olStoreExchange = 1        # Exchange store
    $olStoreImap = 2           # IMAP store
    $olStoreExchangeOther = 3   # Exchange store (variant)

    # Standard SCANPST.EXE locations (Office Click-to-Run, 64-bit and 32-bit).
    $scanPstCandidatePaths = @(
        "${env:ProgramFiles}\Microsoft Office\root\Office16\SCANPST.EXE",
        "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\SCANPST.EXE"
    )

    # ==========================================================================
    # HELPER: release a COM object cleanly to avoid zombie processes.
    # ==========================================================================
    function Release-ComObject {
        param([object]$ComObject)
        if ($null -eq $ComObject) { return }
        try {
            while ([System.Runtime.Interopservices.Marshal]::ReleaseComObject($ComObject) -gt 0) { }
        }
        catch { }
        [System.Runtime.Interopservices.Marshal]::FinalReleaseComObject($ComObject) 2>$null
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }

    # ==========================================================================
    # HELPER: locate SCANPST.EXE in the standard Office paths.
    # Returns the full path when found, otherwise $null.
    # ==========================================================================
    function Get-ScanPstPath {
        foreach ($candidatePath in $scanPstCandidatePaths) {
            try {
                if (Test-Path -LiteralPath $candidatePath -PathType Leaf -ErrorAction Stop) {
                    return $candidatePath
                }
            }
            catch { }
        }
        return $null
    }

    # ==========================================================================
    # HELPER: connect to Outlook via COM (attach to running instance or create new).
    # Returns the Outlook.Application COM object, or $null on failure.
    # ==========================================================================
    function Connect-Outlook {
        try {
            $outlook = [Runtime.Interopservices.Marshal]::GetActiveObject('Outlook.Application')
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.outlookAlreadyRunningAttached')
            return $outlook
        }
        catch {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.outlookNotRunningStartingCom')
        }
        try {
            $outlook = New-Object -ComObject Outlook.Application
            $null = $outlook.GetNamespace('MAPI')
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.outlookComInstanceCreated')
            return $outlook
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.cannotCreateOutlookCom0' -Args @($($_.Exception.Message)))
            return $null
        }
    }

    # ==========================================================================
    # HELPER: clean the "Deleted Items" folder for cloud accounts (Exchange/IMAP).
    # ==========================================================================
    function Repair-CloudAccount {
        param(
            [Parameter(Mandatory = $true)][object]$Store,
            [Parameter(Mandatory = $true)][object]$Namespace
        )
        $storeName = 'Unknown'
        try { $storeName = $Store.DisplayName } catch { }
        try {
            Write-StyledMessage -Type 'Info' -Text "[$storeName] $(Get-SourceTextLoc 'toolText.cloudAccountCleaningDeletedItems')"
            $deletedFolder = $null
            try { $deletedFolder = $Namespace.GetDefaultFolder($olFolderDeletedItems) }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "[$storeName] $(Get-SourceTextLoc 'toolText.cannotAccessDeletedItems0' -Args @($($_.Exception.Message)))"
                return
            }
            if ($null -eq $deletedFolder) {
                Write-StyledMessage -Type 'Warning' -Text "[$storeName] $(Get-SourceTextLoc 'toolText.deletedItemsFolderUnavailable')"
                return
            }
            $items = $null
            try { $items = $deletedFolder.Items }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "[$storeName] $(Get-SourceTextLoc 'toolText.cannotEnumerateDeletedItems0' -Args @($($_.Exception.Message)))"
                Release-ComObject -ComObject $deletedFolder
                return
            }
            $itemCount = 0
            try { $itemCount = $items.Count } catch { $itemCount = 0 }
            if ($itemCount -eq 0) {
                Write-StyledMessage -Type 'Success' -Text "[$storeName] $(Get-SourceTextLoc 'toolText.deletedItemsAlreadyEmpty')"
                Release-ComObject -ComObject $items
                Release-ComObject -ComObject $deletedFolder
                return
            }
            Write-StyledMessage -Type 'Info' -Text "[$storeName] $(Get-SourceTextLoc 'toolText.found0ItemsToRemove' -Args @($itemCount))"
            # Iterate backwards so item indices stay valid while deleting.
            for ($i = $itemCount; $i -ge 1; $i--) {
                $item = $null
                try {
                    $item = $items.Item($i)
                    $item.Delete()
                }
                catch {
                    Write-StyledMessage -Type 'Warning' -Text "[$storeName] $(Get-SourceTextLoc 'toolText.cannotDeleteItem01' -Args @($i, $($_.Exception.Message)))"
                }
                finally {
                    if ($null -ne $item) { Release-ComObject -ComObject $item }
                }
            }
            Write-StyledMessage -Type 'Success' -Text "[$storeName] $(Get-SourceTextLoc 'toolText.deletedItemsCleanupComplete')"
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "[$storeName] $(Get-SourceTextLoc 'toolText.criticalErrorCloudCleanup0' -Args @($($_.Exception.Message)))"
        }
        finally {
            if ($null -ne $items) { Release-ComObject -ComObject $items }
            if ($null -ne $deletedFolder) { Release-ComObject -ComObject $deletedFolder }
        }
    }

    # ==========================================================================
    # HELPER: conservative repair for local archives (POP3/PST) via SCANPST.EXE.
    # ==========================================================================
    function Repair-Pop3PstAccount {
        param(
            [Parameter(Mandatory = $true)][object]$Store,
            [string]$ScanPstPath
        )
        $storeName = 'Unknown'
        try { $storeName = $Store.DisplayName } catch { }
        try {
            Write-StyledMessage -Type 'Warning' -Text "[$storeName] $(Get-SourceTextLoc 'toolText.localArchiveConservativeApproach')"
            $pstPath = $null
            try { $pstPath = $Store.FilePath }
            catch {
                Write-StyledMessage -Type 'Warning' -Text "[$storeName] $(Get-SourceTextLoc 'toolText.cannotGetPstPath')"
                return
            }
            if ([string]::IsNullOrWhiteSpace($pstPath)) {
                Write-StyledMessage -Type 'Warning' -Text "[$storeName] $(Get-SourceTextLoc 'toolText.emptyPstPathSkipping')"
                return
            }
            if (-not (Test-Path -LiteralPath $pstPath -PathType Leaf -ErrorAction SilentlyContinue)) {
                Write-StyledMessage -Type 'Warning' -Text "[$storeName] $(Get-SourceTextLoc 'toolText.pstFileNotFound0' -Args @($pstPath))"
                return
            }
            if (-not $pstPath.EndsWith('.pst', [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-StyledMessage -Type 'Warning' -Text "[$storeName] $(Get-SourceTextLoc 'toolText.nonPstExtensionSkipping0' -Args @($pstPath))"
                return
            }
            Write-StyledMessage -Type 'Info' -Text "[$storeName] $(Get-SourceTextLoc 'toolText.pstFileFound0' -Args @($pstPath))"
            if (-not $ScanPstPath) {
                # SCANPST.EXE not found: Outlook Classic may not be installed.
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.scanpstNotFoundOutlookClassicMaybeNotInstalled')
                return
            }
            Write-StyledMessage -Type 'Info' -Text "[$storeName] $(Get-SourceTextLoc 'toolText.startingScanpstFor0' -Args @($pstPath))"
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.scanpstGuiManualStartRequired')
            $arguments = "-file `"$pstPath`""
            try {
                $process = Start-Process -FilePath $ScanPstPath -ArgumentList $arguments -PassThru -ErrorAction Stop
                Write-StyledMessage -Type 'Success' -Text "[$storeName] $(Get-SourceTextLoc 'toolText.scanpstStarted0' -Args @($process.Id))"
                if (-not $NoWaitForScanPst) {
                    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.waitForRepairToFinish')
                }
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text "[$storeName] $(Get-SourceTextLoc 'toolText.cannotStartScanpst0' -Args @($($_.Exception.Message)))"
            }
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text "[$storeName] $(Get-SourceTextLoc 'toolText.errorManagingPst0' -Args @($($_.Exception.Message)))"
        }
    }

    # ==========================================================================
    # MAIN FLOW
    # ==========================================================================
    $needsReboot = $false
    try {
        Write-StyledMessage -Type 'Info' -Text ("🔧 " + (Get-SourceTextLoc 'toolText.startingOutlookRepair'))
        # Close Outlook before touching its data files.
        Stop-ToolkitProcesses -ProcessNames @('outlook')

        Write-StyledMessage -Type 'Info' -Text ("🧹 " + (Get-SourceTextLoc 'toolText.outlookCacheCleanup'))
        $cleanedCount = 0
        foreach ($cache in @(
            "$env:LOCALAPPDATA\Microsoft\Outlook",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache"
        )) {
            if (Remove-ItemSafely -Path $cache -Recurse) { $cleanedCount++ }
        }
        if ($cleanedCount -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0DeletedCaches' -Args @($cleanedCount)) }

        # 1. Locate SCANPST.EXE. If not found, Outlook Classic may not be installed.
        Write-StyledMessage -Type 'Info' -Text ("[1/5] " + (Get-SourceTextLoc 'toolText.searchingScanpst'))
        $scanPstPath = Get-ScanPstPath
        if ($null -eq $scanPstPath) {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.scanpstNotFoundOutlookClassicMaybeNotInstalled')
        }
        else {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.scanpstFound0' -Args @($scanPstPath))
        }

        # 2. Connect to Outlook via COM.
        Write-StyledMessage -Type 'Info' -Text ("[2/5] " + (Get-SourceTextLoc 'toolText.connectingToOutlookCom'))
        $outlook = Connect-Outlook
        if ($null -eq $outlook) {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.cannotProceedWithoutOutlookCom')
            return
        }

        # 3. Retrieve the MAPI namespace.
        Write-StyledMessage -Type 'Info' -Text ("[3/5] " + (Get-SourceTextLoc 'toolText.retrievingMapiNamespace'))
        $namespace = $null
        try {
            $namespace = $outlook.GetNamespace('MAPI')
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.mapiNamespaceRetrieved')
        }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.cannotRetrieveMapiNamespace0' -Args @($($_.Exception.Message)))
            Release-ComObject -ComObject $outlook
            return
        }

        # 4-5. Iterate configured stores and apply the differentiated repair.
        Write-StyledMessage -Type 'Info' -Text ("[4-5/5] " + (Get-SourceTextLoc 'toolText.scanningConfiguredStores'))
        $stores = $null
        try { $stores = $namespace.Stores }
        catch {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.cannotAccessStoresCollection0' -Args @($($_.Exception.Message)))
            Release-ComObject -ComObject $namespace
            Release-ComObject -ComObject $outlook
            return
        }
        $storeCount = 0
        try { $storeCount = $stores.Count } catch { $storeCount = 0 }
        Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.configuredStoresInProfile0' -Args @($storeCount))

        for ($i = 1; $i -le $storeCount; $i++) {
            $store = $null
            try { $store = $stores.Item($i) }
            catch {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'toolText.cannotAccessStore0Skipping' -Args @($i))
                continue
            }
            $storeType = -1
            try { $storeType = $store.ExchangeStoreType } catch { }
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'toolText.store01ExchangeStoreType2' -Args @($i, $store.DisplayName, $storeType))

            if ($storeType -in @($olStoreExchange, $olStoreImap, $olStoreExchangeOther)) {
                Repair-CloudAccount -Store $store -Namespace $namespace
            }
            else {
                Repair-Pop3PstAccount -Store $store -ScanPstPath $scanPstPath
            }
            Release-ComObject -ComObject $store
        }

        # Release COM objects and finalize.
        Write-StyledMessage -Type 'Info' -Text ("[5/5] " + (Get-SourceTextLoc 'toolText.releasingComObjects'))
        Release-ComObject -ComObject $namespace
        Release-ComObject -ComObject $outlook

        Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.outlookRepairCompleted')
        $needsReboot = $true
    }
    catch {
        Write-ToolkitError -Record $_ -ToolName 'OutlookRepair' -Message (Get-SourceTextLoc 'toolText.criticalErrorRepairingOutlook')
    }
    finally {
        Write-StyledMessage -Type 'Success' -Text ("🎯 " + (Get-SourceTextLoc 'toolText.outlookRepairFinished'))
        Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'toolText.outlookRepairSessionEnded')
    }

    if ($needsReboot) {
        Invoke-ToolkitReboot -Message (Get-SourceTextLoc 'toolText.outlookRepairCompleted') -Seconds $CountdownSeconds -SuppressIndividualReboot:$SuppressIndividualReboot
    }
}
