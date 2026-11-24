function Export-SystemPowerReport {
    <#
    .SYNOPSIS
        Generates a system power transition report. Equivalent to powercfg /systempowerreport
        (alias /sleepstudy).
    .DESCRIPTION
        Reports system power transitions over the last three days (or -Duration
        days), including modern standby / connected standby efficiency.

        There is no public Win32 API for this report, so this calls powercfg.exe,
        with output captured in memory and the exit code checked. Requires an
        elevated session.
    .EXAMPLE
        Export-SystemPowerReport -OutFile C:\Temp\power.html -Duration 7

        Writes an HTML report covering the last seven days and returns the file.
    .EXAMPLE
        Export-SystemPowerReport -FormatXml -OutFile C:\Temp\power.xml

        Writes the same report as XML, for parsing or for converting later with -ReformatXml.
    .EXAMPLE
        Export-SystemPowerReport -ReformatXml -FilePath C:\Temp\power.xml

        Writes C:\Temp\power.html.
    .OUTPUTS
        System.IO.FileInfo
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'ReformatXml',
        Justification = 'The switch only selects the ReformatXml parameter set.')]
    [CmdletBinding(DefaultParameterSetName = 'OutputReport')]
    [OutputType([System.IO.FileInfo])]
    param(
        # Report path. Relative paths resolve against the current PowerShell
        # location. The extension is corrected to .html or .xml to match the format.
        # Default: .\sleepstudy-report.html (or .xml with -FormatXml).
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
            Option      = 'systempowerreport'
            DefaultName = 'sleepstudy-report'
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
