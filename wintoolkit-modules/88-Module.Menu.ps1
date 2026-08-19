

# ==============================================================================
# SECTION 13 · MENU STRUCTURE
# Category and interactive TUI menu item definitions.
# ==============================================================================

$menuStructure = @(
    @{ 'Name' = 'Windows'; 'CategoryKey' = 'category.windows'; 'Icon' = '🔧'; 'Scripts' = @(
            [pscustomobject]@{Name = 'WinRepairToolkit'; Description = 'Windows Repair'; DescriptionKey = 'script.WinRepairToolkit'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinUpdateReset'; Description = 'Reset Windows Update'; DescriptionKey = 'script.WinUpdateReset'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinReinstallStore'; Description = 'Winget/WinStore Reset'; DescriptionKey = 'script.WinReinstallStore'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinBackupDriver'; Description = 'Backup Driver PC'; DescriptionKey = 'script.WinBackupDriver'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinCleaner'; Description = 'Temporary File Cleanup'; DescriptionKey = 'script.WinCleaner'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'DisableBitlocker'; Description = 'Disable BitLocker'; DescriptionKey = 'script.DisableBitlocker'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'WinDeleteUserProfiles'; Description = 'Delete Windows User Profiles'; DescriptionKey = 'script.WinDeleteUserProfiles'; Action = 'RunFunction' }
        )
    },
    @{ 'Name' = 'Office'; 'CategoryKey' = 'category.office'; 'Icon' = '🏢'; 'Scripts' = @(
            [pscustomobject]@{Name = 'Install-Office'; Description = 'Install Office Basic'; DescriptionKey = 'script.Install-Office'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'Repair-Office'; Description = 'Repair Office'; DescriptionKey = 'script.Repair-Office'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'Uninstall-Office'; Description = 'Remove Office'; DescriptionKey = 'script.Uninstall-Office'; Action = 'RunFunction' }
        )
    },
    @{ 'Name' = 'Driver & Gaming'; 'CategoryKey' = 'category.driverGaming'; 'Icon' = '🎮'; 'Scripts' = @(
            [pscustomobject]@{Name = 'AutoVideoDriverInstall'; Description = 'Auto Install Driver Video [Nvidia-AMD]'; DescriptionKey = 'script.AutoVideoDriverInstall'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'VideoDriverReinstall'; Description = 'Reinstall Video Driver'; DescriptionKey = 'script.VideoDriverReinstall'; Action = 'RunFunction' },
            [pscustomobject]@{Name = 'GamingToolkit'; Description = 'Gaming Toolkit'; DescriptionKey = 'script.GamingToolkit'; Action = 'RunFunction' }
        )
    },
    @{ 'Name' = 'Support'; 'CategoryKey' = 'category.support'; 'Icon' = '🕹️'; 'Scripts' = @(
            [pscustomobject]@{Name = 'WinExportLog'; Description = 'Export WinToolkit Logs'; DescriptionKey = 'script.WinExportLog'; Action = 'RunFunction' }
        )
    }
)