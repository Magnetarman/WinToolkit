# ==============================================================================
# SECTION 15 · MAIN MENU
# Interactive TUI loop. Suppressed in library mode (-ImportOnly) and GUI.
# ==============================================================================

if (-not $ImportOnly -and -not $Global:GuiSessionActive) {

    Write-Host ""
    Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'menu.startedInteractive')
    Write-Host ""

    function Confirm-UserProfileDeletion {
        Write-Host ''
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'confirm.profile.warn1')
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'confirm.profile.warn2')
        Write-Host ''
        Write-Host "💎 [1] $(Get-SourceTextLoc 'confirm.profile.yes')" -ForegroundColor White
        Write-Host "[INVIO] $(Get-SourceTextLoc 'menu.back')" -ForegroundColor Gray
        $firstConfirm = Microsoft.PowerShell.Utility\Read-Host (Get-SourceTextLoc 'menu.choice')

        if ($firstConfirm -ne '1') {
            return $false
        }

        Write-Host ''
        Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'confirm.profile.sure')
        Write-Host ''
        Write-Host "💎 [1] $(Get-SourceTextLoc 'confirm.profile.accept')" -ForegroundColor White
        Write-Host "[INVIO] $(Get-SourceTextLoc 'menu.back')" -ForegroundColor Gray
        $secondConfirm = Microsoft.PowerShell.Utility\Read-Host (Get-SourceTextLoc 'menu.choice')

        return ($secondConfirm -eq '1')
    }

    function Show-LanguageMenu {
        while ($true) {
            Show-Header -SubTitle (Get-SourceTextLoc 'menu.language')
            Write-Host ''
            Write-Host "==== 🌐 $(Get-SourceTextLoc 'menu.chooseLanguage') 🌐 ====" -ForegroundColor Cyan
            Write-Host ''

            $languages = @(Get-AvailableSourceTextLanguages)
            if ($languages.Count -eq 0) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'menu.noLanguages')
                Start-Sleep -Seconds 2
                return
            }

            for ($i = 0; $i -lt $languages.Count; $i++) {
                $marker = if ($languages[$i].Code -eq $Global:SourceTextLanguage) { '*' } else { ' ' }
                $aiTag = if ($languages[$i].AiTranslated) { ' [AI Trad.]' } else { '' }
                Write-Host "💎 [$($i + 1)] $marker $($languages[$i].NativeName) ($($languages[$i].Code))$aiTag" -ForegroundColor White
            }

            Write-Host ''
            Write-Host "↩️ [0] $(Get-SourceTextLoc 'menu.back')" -ForegroundColor Gray
            Write-Host ''

            $choice = Microsoft.PowerShell.Utility\Read-Host (Get-SourceTextLoc 'menu.choice')
            if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq '0') { return }

            $parsed = 0
            if ([int]::TryParse($choice, [ref]$parsed) -and $parsed -ge 1 -and $parsed -le $languages.Count) {
                $selectedLanguage = $languages[$parsed - 1]
                Set-SourceTextLanguage -LanguageCode $selectedLanguage.Code
                Write-StyledMessage -Type 'Success' -Text (Get-SourceTextLoc 'menu.languageChanged' -Args @($selectedLanguage.NativeName))
                Start-Sleep -Seconds 1
                return
            }

            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'menu.invalidSelection')
            Start-Sleep -Seconds 1
        }
    }

    :MainMenu while ($true) {
        Show-Header -SubTitle (Get-SourceTextLoc 'menu.main')

        # ── Informazioni di sistema ───────────────────────────────────────────
        $width = try { $Host.UI.RawUI.BufferSize.Width } catch { 80 }
        Write-Host ''
        Write-Host "==== 💻 $(Get-SourceTextLoc 'system.infoTitle') 💻 ====" -ForegroundColor Cyan
        Write-Host ''
        $si = Get-SystemInfo
        if ($si) {
            $editionIcon = if ($si.ProductName -match "Pro") { "🔧" } else { "💻" }
            Write-Host "💻 $(Get-SourceTextLoc 'system.edition'): $editionIcon $($si.ProductName)" -ForegroundColor White
            Write-Host "🆔 $(Get-SourceTextLoc 'system.version'): " -NoNewline -ForegroundColor White
            Write-Host (Get-SourceTextLoc 'uiText.ver0Build1' -Args @($($si.DisplayVersion), $($si.BuildNumber))) -ForegroundColor Green
            Write-Host "🔑 $(Get-SourceTextLoc 'system.architecture'): $($si.Architecture)"  -ForegroundColor White
            Write-Host "🔧 $(Get-SourceTextLoc 'system.computerName'): $($si.ComputerName)"       -ForegroundColor White
            Write-Host (Get-SourceTextLoc 'uiText.ram0Gb' -Args @($($si.TotalRAM)))            -ForegroundColor White
            Write-Host "💾 $(Get-SourceTextLoc 'system.disk'): " -NoNewline -ForegroundColor White

            $diskFreeGB = $si.FreeDisk
            $displayString = "$($si.FreePercentage)% $(Get-SourceTextLoc 'system.free') ($($diskFreeGB) GB)"
            $diskColor = if ($diskFreeGB -lt 50) { "Red" } elseif ($diskFreeGB -le 80) { "Yellow" } else { "Green" }
            Write-Host $displayString -ForegroundColor $diskColor -NoNewline
            Write-Host ""

            $blStatusKey = Get-BitlockerStatus -Key
            $blStatus = Get-SourceTextLoc $blStatusKey
            $blColor = if ($blStatusKey -in @('bitlocker.status.off', 'bitlocker.status.notConfigured')) { 'Green' } elseif ($blStatusKey -in @('bitlocker.status.suspended', 'bitlocker.status.decrypting')) { 'Yellow' } else { 'Red' }
            Write-Host "🔒 $(Get-SourceTextLoc 'system.bitlockerStatus'): " -NoNewline -ForegroundColor White
            Write-Host "$blStatus" -ForegroundColor $blColor
        }
        Write-Host ('*' * 50) -ForegroundColor Red
        Write-Host ""

        # ── Voci di menu ─────────────────────────────────────────────────────
        $allScripts = @(); $idx = 1
        $languageMenuIndex = $null
        foreach ($cat in $menuStructure) {
            Write-Host "==== $($cat.Icon) $(Get-SourceTextMenuText $cat) $($cat.Icon) ====" -ForegroundColor Cyan
            Write-Host ""
            foreach ($s in $cat.Scripts) {
                $allScripts += $s
                Write-Host "💎 [$idx] $(Get-SourceTextMenuText $s)" -ForegroundColor White
                $idx++
            }
            if ($cat.Name -eq 'Support' -and -not $Global:GuiSessionActive) {
                $languageMenuIndex = $idx
                Write-Host "`e[1m🌐 [$idx] $(Get-SourceTextLoc 'menu.changeLanguage')`e[0m" -ForegroundColor Yellow
                $idx++
            }
            Write-Host ""
        }
        Write-Host "==== $(Get-SourceTextLoc 'menu.exitSection') ====" -ForegroundColor Red
        Write-Host ""
        Write-Host "❌ [0] $(Get-SourceTextLoc 'menu.exitToolkit')" -ForegroundColor Red
        Write-Host ""

        # ── Input utente ──────────────────────────────────────────────────────
        $rawInput = Microsoft.PowerShell.Utility\Read-Host (Get-SourceTextLoc 'menu.multiPrompt')

        # Secret check
        if ($rawInput -eq [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('V2luZG93cyDDqCB1bmEgbWVyZGE='))) {
            Start-Process ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly93d3cueW91dHViZS5jb20vd2F0Y2g/dj15QVZVT2tlNGtvYw==')))
            continue
        }

        $maxMenuOption = $allScripts.Count + $(if ($null -ne $languageMenuIndex) { 1 } else { 0 })
        $rawSelections = Read-ValidatedChoice -Prompt (Get-SourceTextLoc 'menu.multiPromptShort') -Min 0 -Max $maxMenuOption -AllowZero -RawInput $rawInput
        $c = if ($rawSelections.Count -gt 0) { $rawSelections[0] } else { '' }

        if ($c -eq 0 -or $c -eq '0') {
            Write-StyledMessage -type 'Warning' -text (Get-SourceTextLoc 'menu.support')
            Write-StyledMessage -type 'Success' -text (Get-SourceTextLoc 'menu.closing')
            Write-ToolkitLog -Level INFO -Message (Get-SourceTextLoc 'uiText.wintoolkitSessionTerminatedByUser')
            Start-Sleep -Seconds 3
            break
        }

        if ($null -ne $languageMenuIndex -and $rawSelections -contains $languageMenuIndex) {
            Show-LanguageMenu
            continue
        }

        $selections = @($rawSelections | Where-Object { $_ -ge 1 -and $_ -le $maxMenuOption })
        if ($selections.Count -eq 0) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'menu.invalidSelection')
            Start-Sleep -Seconds 2
            continue
        }

        # ── Esecuzione ────────────────────────────────────────────────
        $Global:ExecutionLog = @()
        $Global:NeedsFinalReboot = $false
        $isMultiScript = ($selections.Count -gt 1)

        Write-Host ''
        if ($isMultiScript) {
            Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'run.sequence' -Args @($selections.Count))
            Write-Host ''
        }

        foreach ($sel in $selections) {
            $scriptToRun = $allScripts[$sel - 1]
            $scriptDescription = Get-SourceTextMenuText $scriptToRun
            if ($scriptToRun.Name -eq 'WinDeleteUserProfiles' -and -not (Confirm-UserProfileDeletion)) {
                Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'run.cancelled')
                Start-Sleep -Seconds 2
                continue MainMenu
            }

            Write-StyledMessage -Type 'Progress' -Text (Get-SourceTextLoc 'run.start' -Args @($scriptDescription))
            Write-Host ''
            try {
                if ($isMultiScript) { & ([scriptblock]::Create("$($scriptToRun.Name) -SuppressIndividualReboot")) }
                else { & $ExecutionContext.InvokeCommand.GetCommand($scriptToRun.Name, 'Function') }
                $Global:ExecutionLog += @{ Name = $scriptDescription; Success = $true }
            }
            catch {
                Write-StyledMessage -Type 'Error' -Text (Get-SourceTextLoc 'run.error' -Args @($scriptDescription, $_.Exception.Message))
                $Global:ExecutionLog += @{ Name = $scriptDescription; Success = $false; Error = $_.Exception.Message }
            }
            Write-Host ''
        }

        # ── Multi-script summary ────────────────────────────────────────────
        if ($isMultiScript) {
            Write-Host ''
            $tableRows = $Global:ExecutionLog | ForEach-Object {
                @{ Operation = $_.Name; Status = if ($_.Success) { "✅ $(Get-SourceTextLoc 'summary.completed')" } else { "❌ $(Get-SourceTextLoc 'summary.error')" }; Detail = if ($_.Error) { $_.Error } else { '' } }
            }
            Show-ConsoleTable -Rows $tableRows -Columns @(
                @{ Header = (Get-SourceTextLoc 'summary.operation'); Key = 'Operation' },
                @{ Header = (Get-SourceTextLoc 'summary.status'); Key = 'Status' },
                @{ Header = (Get-SourceTextLoc 'summary.detail'); Key = 'Detail' }
            ) -Title "📊 $(Get-SourceTextLoc 'summary.title')"
            Write-Host ''
        }

        # ── Final reboot ────────────────────────────────────────────────────
        if ($Global:NeedsFinalReboot) {
            Write-StyledMessage -Type 'Warning' -Text (Get-SourceTextLoc 'reboot.required')
            if (Start-InterruptibleCountdown -Seconds $CountdownSeconds -Message (Get-SourceTextLoc 'reboot.countdown')) {
                Restart-Computer -Force
            }
            else {
                Write-Host ''
                Write-StyledMessage -Type 'Info' -Text (Get-SourceTextLoc 'reboot.reminder')
            }
        }

        Write-Host "`n$(Get-SourceTextLoc 'menu.pressEnter')" -ForegroundColor Gray
        $null = Read-Host
    }
}
else {
    # Library/import mode — functions loaded, TUI menu suppressed
    Write-Verbose "═══════════════════════════════════════════════════════════"
    Write-Verbose ("  " + (Get-SourceTextLoc 'uiText.wintoolkitLoadedInLibraryMode'))
    Write-Verbose ("  " + (Get-SourceTextLoc 'uiText.functionsAvailableTuiMenuSuppressed'))
    Write-Verbose ("  💎 " + (Get-SourceTextLoc 'sourceText.version') + ": $ToolkitVersion")
    Write-Verbose "═══════════════════════════════════════════════════════════"
    $Global:menuStructure = $menuStructure
}