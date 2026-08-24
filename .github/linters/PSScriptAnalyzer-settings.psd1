@{
    # Severity: Error, Warning, Information
    Severity     = @(
        'Error',
        'Warning'
    )

    # Excluded rules
    ExcludeRules = @(
        'PSUseSingularNouns',                  # false positives for function names
        'PSShouldProcess',                     # system-state scripts
        'PSUseApprovedVerbs',                  # internal scripts
        'PSAvoidUsingPositionalParameters',    # internal scripts
        'PSAvoidUsingWriteHost',               # use Write-Output
        'PSAvoidUsingEmptyCatchBlock',         # intentional
        'PSAvoidGlobalVars',                   # sometimes necessary
        'PSAvoidOverwritingBuiltInCmdlets',    # output redirection
        'PSPossibleIncorrectComparisonWithNull', # style
        'PSUseBOMForUnicodeEncodedFile',       # use-case dependent
        'PSAvoidUsingWMICmdlet',               # internal scripts
        'PSUseShouldProcessForStateChangingFunctions', # false positives
        'PSReviewUnusedParameter',             # false positives
        'PSUseDeclaredVarsMoreThanAssignments', # false positives
        'PSUseUsingScopeModifierInNewRunspaces', # false positive with Start-Job
        'PSAvoidAssignmentToAutomaticVariable' # sometimes reassigned
    )

    # Custom rules path
    # CustomRulePath = @()

    # Rule settings
    Rules        = @{
        # PSAvoidUsingCmdletAliases: common aliases
        PSAvoidUsingCmdletAliases             = @{
            Severity = 'Warning'
        }

        # PSUseBOMForUnicode: UTF-8 BOM
        PSUseBOMForUnicode                    = @{
            Severity = 'Warning'
        }

        # PSUseUTF8LineEnding: BOM handled elsewhere
        PSUseUTF8LineEnding                   = @{
            Severity = 'Information'
        }

        PSAvoidTrailingWhitespace             = @{
            Severity = 'Error'
        }

        PSMissingModuleManifestField          = @{
            Severity = 'Warning'
        }

        PSUseOutputTypeCorrectly              = @{
            Severity = 'Warning'
        }

        PSNoSpaceAroundOperator               = @{
            Severity = 'Warning'
        }

        PSUseDeclaredVarsMoreThanAssignments  = @{
            Severity = 'Warning'
        }

        PSPossibleIncorrectComparisonWithBool = @{
            Severity = 'Warning'
        }

        PSAvoidGlobalVars                     = @{
            Severity = 'Warning'
        }
    }
}
