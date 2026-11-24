<#
    .SYNOPSIS
        Runs PSScriptAnalyzer over the module with the repository settings.

    .DESCRIPTION
        Writes one line per finding or analyzer error, and nothing when the code is clean. Exits
        with 1 when it wrote anything. The manifest's long Description line is excluded, because a
        manifest allows only one constant string there.

        The analysis runs in a child process of the same PowerShell edition. PSScriptAnalyzer
        1.23 to 1.25 intermittently fail inside their own command lookup (NullReferenceException
        in CommandInfo.get_Parameters, or "The term 'Get-Command' is not recognized"), from any
        rule that looks up commands. Once that happens, the analyzer can stay broken for the rest
        of the process, so each file it failed on is analyzed again in a fresh process, up to
        three times. A retry repeats the same analysis, so it can't hide a finding. An analyzer
        error that survives the retries is reported.

    .EXAMPLE
        pwsh.exe -NoProfile -File .\Tests\Invoke-StyleCheck.ps1

        Prints every finding as File:Line Rule Message. No output and exit code 0 mean the module
        is clean.
#>
[CmdletBinding()]
[OutputType([string])]
param(
    # Repository root. Defaults to the parent of this script's folder.
    [string]$Path,

    # Internal: analyze Target in this process and write tab-separated records.
    [switch]$Worker,

    # Internal: the file or folder a worker analyzes.
    [string]$Target
)

# $PSScriptRoot is empty in parameter defaults under Windows PowerShell 5.1.
if (-not $Path) {
    $Path = Split-Path -Path $PSScriptRoot -Parent
}
$settings = Join-Path -Path $Path -ChildPath 'PSScriptAnalyzerSettings.psd1'

if ($Worker) {
    Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
    $files = Get-ChildItem -Path $Target -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1'
    foreach ($file in $files) {
        $analyzerErrors = $null
        $analyzerParams = @{
            Path          = $file.FullName
            Settings      = $settings
            ErrorVariable = 'analyzerErrors'
            ErrorAction   = 'SilentlyContinue'
        }
        $findings = Invoke-ScriptAnalyzer @analyzerParams
        if ($analyzerErrors) {
            # Findings from a run with errors are incomplete; the parent retries the whole file.
            "error`t{0}`t{1}" -f $file.FullName, $analyzerErrors[0]
            continue
        }
        foreach ($f in $findings) {
            if ($f.RuleName -eq 'PSAvoidLongLines' -and $f.ScriptName -eq 'PsPowerCFG.psd1') {
                continue
            }
            "finding`t{0}:{1} {2} {3}" -f $f.ScriptName, $f.Line, $f.RuleName, $f.Message
        }
    }
    return
}

$exe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$maxAttempts = 4
$report = [System.Collections.Generic.List[string]]::new()
$pending = [System.Collections.Generic.List[string]]::new()
$pending.Add($Path)
for ($attempt = 1; $attempt -le $maxAttempts -and $pending.Count; $attempt++) {
    $failed = [System.Collections.Generic.List[string]]::new()
    foreach ($item in $pending) {
        $output = & $exe -NoProfile -File $PSCommandPath -Worker -Path $Path -Target $item 2>&1
        if ($LASTEXITCODE -ne 0) {
            $report.Add(('worker failed on {0}: {1}' -f $item, ($output -join ' ')))
            continue
        }
        foreach ($line in $output) {
            $kind, $rest = "$line" -split "`t", 2
            if ($kind -eq 'finding') {
                $report.Add($rest)
            } elseif ($kind -eq 'error' -and $attempt -lt $maxAttempts) {
                $failed.Add(($rest -split "`t", 2)[0])
            } elseif ($kind -eq 'error') {
                $file, $message = $rest -split "`t", 2
                $report.Add(('analyzer error: {0} ({1})' -f $message, $file))
            } else {
                $report.Add(('worker output: {0}' -f $line))
            }
        }
    }
    $pending = $failed
}

$report
if ($report.Count) {
    exit 1
}
