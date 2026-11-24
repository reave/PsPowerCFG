function Export-SystemSleepDiagnostics {
    <#
    .SYNOPSIS
        Generates a system sleep diagnostics report. Equivalent to powercfg /systemsleepdiagnostics.
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
    .PARAMETER OutFile
        Report path. Relative paths resolve against the current PowerShell
        location. The extension is corrected to .html or .xml to match the format.
        Default: .\system-sleep-diagnostics.html (or .xml with -FormatXML).
    .PARAMETER FormatXML
        Write the report as XML instead of HTML.
    .PARAMETER Duration
        Number of days of history to analyze.
    .PARAMETER ReformatXML
        Convert an existing XML report (-FilePath) to HTML.
    .PARAMETER FilePath
        Path to an XML report produced with -FormatXML.
    .EXAMPLE
        Export-SystemSleepDiagnostics -OutFile C:\Temp\sleepdiag.html -Duration 7
    .EXAMPLE
        Export-SystemSleepDiagnostics -FormatXML -OutFile C:\Temp\sleepdiag.xml
    .EXAMPLE
        Export-SystemSleepDiagnostics -ReformatXML -FilePath C:\Temp\sleepdiag.xml

        Writes C:\Temp\sleepdiag.html.
    .OUTPUTS
        System.IO.FileInfo
    #>
    [CmdletBinding(DefaultParameterSetName = 'OutputReport')]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(ParameterSetName = 'OutputReport', Position = 0)]
        [Parameter(ParameterSetName = 'TransformXML')]
        [string]$OutFile,

        [Parameter(ParameterSetName = 'OutputReport')]
        [switch]$FormatXML,

        [Parameter(ParameterSetName = 'OutputReport')]
        [ValidateRange(1, 28)]
        [int]$Duration,

        [Parameter(ParameterSetName = 'TransformXML', Mandatory = $true)]
        [switch]$ReformatXML,

        [Parameter(ParameterSetName = 'TransformXML', Mandatory = $true)]
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
        if ($PSCmdlet.ParameterSetName -eq 'TransformXML') {
            $report.TransformXml = $FilePath
        } else {
            $report.Xml = $FormatXML
            $report.Duration = $Duration
        }
        Invoke-PowerCfgReport @report
    }
}
