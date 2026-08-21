

# ==============================================================================
# SECTION 14 · INITIALIZATION
# Single startup block: paths, OS check, updates.
# Executed only in interactive mode (not -ImportOnly, not GUI).
# ==============================================================================

if (-not $ImportOnly) {
    Initialize-ToolkitPaths
    WinOSCheck
    Test-WindowsUpdateStatus
}


