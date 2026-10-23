function OutlookRepair {
    <#
    .SYNOPSIS
        Ripara i profili di Microsoft Outlook Classic.
    .DESCRIPTION
        Si aggancia al profilo Outlook corrente via COM, distingue gli account cloud
        (Exchange/IMAP) dagli archivi locali (POP3/PST) e applica una riparazione
        differenziata: svuota la "Posta Eliminata" per gli account cloud, avvia
        SCANPST.EXE per gli archivi PST locali.
    .PARAMETER NoWaitForScanPst
        Avvia SCANPST senza attendere la chiusura della GUI.
    .PARAMETER SuppressIndividualReboot
        Sopprime il reboot individuale (usato in esecuzione multi-script).
    .PARAMETER CountdownSeconds
        Secondi del countdown prima del riavvio.
    .NOTES
        Richiede PowerShell 7 e Microsoft Outlook Classic installato.
    #>
    [CmdletBinding()]
    param(
        [switch]$NoWaitForScanPst,
        [switch]$SuppressIndividualReboot,
        [int]$CountdownSeconds = 30
    )

    Start-ToolkitSession -ToolName "OutlookRepair" -SubTitle (Get-SourceTextLoc 'script.OutlookRepair')

    # Costanti del modello oggetto Outlook
    $olFolderDeletedItems = 3
    $olStoreExchange = 1
    $olStoreImap = 2
    $olStoreExchangeOther = 3

    # Percorsi standard di SCANPST.EXE (Office Click-to-Run, 64-bit e 32-bit)
    $scanPstCandidatePaths = @(
        "${env:ProgramFiles}\Microsoft Office\root\Office16\SCANPST.EXE",
        "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\SCANPST.EXE"
    )

    # Helper locale: rilascio oggetti COM per evitare processi zombie
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

    # Helper locale: ricerca di SCANPST.EXE nei percorsi standard
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

    # Helper locale: connessione COM a Outlook (istanza attiva o nuova)
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

    # Helper locale: pulizia "Posta Eliminata" per account cloud (Exchange/IMAP)
    function Repair-CloudAccount {
        param(
            [Parameter(Mandatory = $true)][object]$Store,
            [Parameter(Mandatory = $true)][object]$Namespace
        )
        $storeName = 'Sconosciuto'
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
            # Ciclo inverso per preservare la validità degli indici durante la rimozione
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

    # Helper locale: riparazione conservativa per archivi locali (POP3/PST)
    function Repair-Pop3PstAccount {
        param(
            [Parameter(Mandatory = $true)][object]$Store,
            [string]$ScanPstPath
        )
        $storeName = 'Sconosciuto'
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

    # Flusso principale
    $needsReboot = $false
    try {
        Write-StyledMessage -Type 'Info' -Text ("🔧 " + (Get-SourceTextLoc 'toolText.startingOutlookRepair'))
        Stop-ToolkitProcesses -ProcessNames @('outlook')

        Write-StyledMessage -Type 'Info' -Text ("🧹 " + (Get-SourceTextLoc 'toolText.outlookCacheCleanup'))
        $cleanedCount = 0
        foreach ($cache in @(
            "$env:LOCALAPPDATA\Microsoft\Outlook",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Lync\Lync.cache"
        )) {
            if (Remove-ItemSafely -Path $cache -Recurse) { $cleanedCount++ }
        }
        if ($cleanedCount -gt 0) { Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.0CachesDeleted' -Args @($cleanedCount)) }

        # 1. Ricerca di SCANPST.EXE
        Write-StyledMessage -Type 'Info' -Text ("[1/5] " + (Get-SourceTextLoc 'toolText.searchingScanpst'))
        $scanPstPath = Get-ScanPstPath
        if ($null -eq $scanPstPath) {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.scanpstNotFoundOutlookClassicMaybeNotInstalled')
        }
        else {
            Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'toolText.scanpstFound0' -Args @($scanPstPath))
        }

        # 2. Connessione COM a Outlook
        Write-StyledMessage -Type 'Info' -Text ("[2/5] " + (Get-SourceTextLoc 'toolText.connectingToOutlookCom'))
        $outlook = Connect-Outlook
        if ($null -eq $outlook) {
            Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'toolText.cannotProceedWithoutOutlookCom')
            return
        }

        # 3. Namespace MAPI
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

        # 4-5. Scansione Store e ramo di riparazione differenziato
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

        # Chiusura pulita
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
