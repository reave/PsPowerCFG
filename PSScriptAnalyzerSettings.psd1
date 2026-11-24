# PSScriptAnalyzer settings for this repository.
# Usage: Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
# Format: Invoke-Formatter -ScriptDefinition $text -Settings .\PSScriptAnalyzerSettings.psd1
# Rules follow the PowerShell Practice and Style guide (OTBS braces, 4-space indent, 115 columns).
@{
    Severity = @('Error', 'Warning', 'Information')
    Rules    = @{
        PSPlaceOpenBrace                   = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace                  = @{
            Enable             = $true
            NewLineAfter       = $false
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }
        PSUseConsistentIndentation         = @{
            Enable              = $true
            Kind                = 'space'
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }
        # CheckOperator is off: it flags the aligned hashtables that PSAlignAssignmentStatement asks for.
        PSUseConsistentWhitespace          = @{
            Enable          = $true
            CheckInnerBrace = $true
            CheckOpenBrace  = $true
            CheckOpenParen  = $true
            CheckOperator   = $false
            CheckPipe       = $true
            CheckSeparator  = $true
            CheckParameter  = $true
        }
        PSAlignAssignmentStatement         = @{
            Enable         = $true
            CheckHashtable = $true
        }
        PSUseCorrectCasing                 = @{
            Enable = $true
        }
        PSAvoidLongLines                   = @{
            Enable            = $true
            MaximumLineLength = 115
        }
        PSAvoidSemicolonsAsLineTerminators = @{
            Enable = $true
        }
        PSUseCompatibleSyntax              = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.0')
        }
        PSAvoidExclaimOperator             = @{
            Enable = $true
        }
    }
}
