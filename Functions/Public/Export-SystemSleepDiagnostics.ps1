function Export-SystemSleepDiagnostics {
    <#
    .SYNOPSIS
        Generates a system sleep diagnostics report. Equivalent to
        powercfg /systemsleepdiagnostics.
    .DESCRIPTION
        Reports intervals over the last three days (or -Duration days) when the
        user was not present, and whether the system went to sleep.

        DEPRECATED BY WINDOWS: on current Windows 11 builds (verified on 10.0.26300)
        powercfg /systemsleepdiagnostics only prints a notice pointing to
        /systempowerreport and writes nothing. This function then throws a
        ReportNotCreated error carrying that notice. Use Export-SystemPowerReport.

        There is no public Win32 API for this report, so this calls powercfg.exe,
        with output captured in memory and the exit code checked. Requires an
        elevated session.
    .EXAMPLE
        Export-SystemSleepDiagnostics -OutFile C:\Temp\sleepdiag.html -Duration 7

        Writes an HTML report covering the last seven days and returns the file.
    .EXAMPLE
        Export-SystemSleepDiagnostics -FormatXml -OutFile C:\Temp\sleepdiag.xml

        Writes the same report as XML, for parsing or for converting later with -ReformatXml.
    .EXAMPLE
        Export-SystemSleepDiagnostics -ReformatXml -FilePath C:\Temp\sleepdiag.xml

        Writes C:\Temp\sleepdiag.html.
    .OUTPUTS
        System.IO.FileInfo
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'ReformatXml',
        Justification = 'The switch only selects the ReformatXml parameter set.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '',
        Justification = 'Public name kept for compatibility.')]
    [CmdletBinding(DefaultParameterSetName = 'OutputReport')]
    [OutputType([System.IO.FileInfo])]
    param(
        # Report path. Relative paths resolve against the current PowerShell
        # location. The extension is corrected to .html or .xml to match the format.
        # Default: .\system-sleep-diagnostics.html (or .xml with -FormatXml).
        [Parameter(ParameterSetName = 'OutputReport', Position = 0)]
        [Parameter(ParameterSetName = 'TransformXml')]
        [string]$OutFile,

        # Write the report as XML instead of HTML.
        [Parameter(ParameterSetName = 'OutputReport')]
        [switch]$FormatXml,

        # Number of days of history to analyze.
        [Parameter(ParameterSetName = 'OutputReport')]
        [ValidateRange(1, 28)]
        [int]$Duration,

        # Convert an existing XML report (-FilePath) to HTML.
        [Parameter(ParameterSetName = 'TransformXml', Mandatory = $true)]
        [switch]$ReformatXml,

        # Path to an XML report produced with -FormatXml.
        [Parameter(ParameterSetName = 'TransformXml', Mandatory = $true)]
        [string]$FilePath
    )

    begin {
        Assert-IsAdmin -Cmdlet $PSCmdlet
    }

    process {
        $report = @{
            Cmdlet      = $PSCmdlet
            Option      = 'systemsleepdiagnostics'
            DefaultName = 'system-sleep-diagnostics'
            OutFile     = $OutFile
        }
        if ($PSCmdlet.ParameterSetName -eq 'TransformXml') {
            $report.TransformXml = $FilePath
        } else {
            $report.Xml = $FormatXml
            $report.Duration = $Duration
        }
        Invoke-PowerCfgReport @report
    }
}
