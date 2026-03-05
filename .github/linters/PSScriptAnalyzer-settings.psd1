@{
    # Severity levels: Error, Warning, Information
    Severity     = @(
        'Error',
        'Warning'
    )

    # Excluded rules (rules that will not be executed)
    ExcludeRules = @(
        # Exclude PSUseSingularNouns - too many false positives for function names
        'PSUseSingularNouns',

        # Exclude PSShouldProcess - common in scripts that modify system state
        'PSShouldProcess',

        # Exclude PSUseApprovedVerbs - restrictive for internal scripts
        'PSUseApprovedVerbs'
    )

    # Custom rules path (optional)
    # CustomRulePath = @()

    # Settings for individual rules
    Rules        = @{
        # PSAvoidUsingCmdletAliases
        # Note: Using aliases like % for ForEach-Object or ? for Where-Object is common
        PSAvoidUsingCmdletAliases             = @{
            # This rule is set to Warning severity
            Severity = 'Warning'
        }

        # PSUseBOMForUnicode
        # We want UTF-8 with BOM for Windows compatibility
        PSUseBOMForUnicode                    = @{
            Severity = 'Warning'
        }

        # PSUseUTF8LineEnding
        # Use UTF8 with BOM (line endings handled by BOM rule)
        PSUseUTF8LineEnding                   = @{
            Severity = 'Information'
        }

        # PSAvoidTrailingWhitespace
        PSAvoidTrailingWhitespace             = @{
            Severity = 'Error'
        }

        # PSMissingModuleManifestField
        PSMissingModuleManifestField          = @{
            Severity = 'Warning'
        }

        # PSUseOutputTypeCorrectly
        PSUseOutputTypeCorrectly              = @{
            Severity = 'Warning'
        }

        # PSNoSpaceAroundOperator
        PSNoSpaceAroundOperator               = @{
            Severity = 'Warning'
        }

        # PSUseDeclaredVarsMoreThanAssignments
        PSUseDeclaredVarsMoreThanAssignments  = @{
            Severity = 'Warning'
        }

        # PSPossibleIncorrectComparisonWithBool
        PSPossibleIncorrectComparisonWithBool = @{
            Severity = 'Warning'
        }

        # PSAvoidGlobalVars
        PSAvoidGlobalVars                     = @{
            Severity = 'Warning'
        }
    }
}
