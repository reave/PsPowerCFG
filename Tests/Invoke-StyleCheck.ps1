#Requires -Modules PSScriptAnalyzer
<#
    .SYNOPSIS
        Runs PSScriptAnalyzer over the module with the repository settings.

    .DESCRIPTION
        Writes one line per finding or analyzer error, and nothing when the code is clean. The
        manifest's long Description line is excluded, because a manifest allows only one constant
        string there.

        Each file is analyzed on its own and retried up to three times when the analyzer itself
        throws. PSScriptAnalyzer 1.23 to 1.25 intermittently fail inside their own command lookup
        (NullReferenceException in CommandInfo.get_Parameters, or "The term 'Get-Command' is not
        recognized"), from any rule that looks up commands. A retry repeats the same analysis, so
        it can't hide a finding. An error that survives the retries is reported.

        Run it in its own process: inside a Pester run with the module imported, those failures
        are much more frequent.

    .EXAMPLE
        pwsh.exe -NoProfile -File .\Tests\Invoke-StyleCheck.ps1

        Prints every finding as File:Line Rule Message. No output means the module is clean.
#>
[CmdletBinding()]
[OutputType([string])]
param(
    # Repository root. Defaults to the parent of this script's folder.
    [string]$Path = (Split-Path -Path $PSScriptRoot -Parent)
)

$settings = Join-Path -Path $Path -ChildPath 'PSScriptAnalyzerSettings.psd1'
$files = Get-ChildItem -Path $Path -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1'

foreach ($file in $files) {
    $analyzerParams = @{
        Path          = $file.FullName
        Settings      = $settings
        ErrorVariable = 'analyzerErrors'
        ErrorAction   = 'SilentlyContinue'
    }
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $analyzerErrors = $null
        $findings = Invoke-ScriptAnalyzer @analyzerParams
        if (-not $analyzerErrors) {
            break
        }
    }
    foreach ($f in $findings) {
        if ($f.RuleName -eq 'PSAvoidLongLines' -and $f.ScriptName -eq 'PsPowerCFG.psd1') {
            continue
        }
        '{0}:{1} {2} {3}' -f $f.ScriptName, $f.Line, $f.RuleName, $f.Message
    }
    foreach ($e in $analyzerErrors) {
        'analyzer error: {0} ({1})' -f $e, $e.TargetObject
    }
}
