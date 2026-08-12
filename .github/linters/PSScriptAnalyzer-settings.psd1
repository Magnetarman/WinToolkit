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
        'PSUseApprovedVerbs',

        # Exclude PSAvoidUsingPositionalParameters - acceptable for internal scripts
        'PSAvoidUsingPositionalParameters',

        # Exclude PSAvoidUsingWriteHost - Use Write-Output instead of Write-Host
        'PSAvoidUsingWriteHost',

        # Exclude PSAvoidUsingEmptyCatchBlock - Empty catch blocks are sometimes intentional
        'PSAvoidUsingEmptyCatchBlock',

        # Exclude PSAvoidGlobalVars - Global variables are sometimes necessary
        'PSAvoidGlobalVars',

        # Exclude PSAvoidOverwritingBuiltInCmdlets - Common pattern for output redirection
        'PSAvoidOverwritingBuiltInCmdlets',

        # Exclude PSPossibleIncorrectComparisonWithNull - Style preference
        'PSPossibleIncorrectComparisonWithNull',

        # Exclude PSUseBOMForUnicodeEncodedFile - BOM handling varies by use case
        'PSUseBOMForUnicodeEncodedFile',

        # Exclude PSAvoidUsingWMICmdlet - CIM and WMI both acceptable for internal scripts
        'PSAvoidUsingWMICmdlet',

        # Exclude PSUseShouldProcessForStateChangingFunctions - May produce false positives
        'PSUseShouldProcessForStateChangingFunctions',

        # Exclude PSReviewUnusedParameter - May produce false positives
        'PSReviewUnusedParameter',

        # Exclude PSUseDeclaredVarsMoreThanAssignments - May produce false positives
        'PSUseDeclaredVarsMoreThanAssignments',

        # Exclude PSUseUsingScopeModifierInNewRunspaces - false positive with param() + -ArgumentList in Start-Job
        'PSUseUsingScopeModifierInNewRunspaces',

        # Exclude PSAvoidAssignmentToAutomaticVariable - Automatic variables are sometimes reassigned
        'PSAvoidAssignmentToAutomaticVariable'
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
