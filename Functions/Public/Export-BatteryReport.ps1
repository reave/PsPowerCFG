function Export-BatteryReport {
    <#
    .SYNOPSIS
        Generates a battery usage and capacity history report. Equivalent to
        powercfg /batteryreport.
    .DESCRIPTION
        Writes an HTML or XML report of installed batteries (design and full
        charge capacity, chemistry, cycle count), recent usage, and capacity and
        life estimates over time. For the current charge only, use
        Get-PowerBatteryState.

        There is no public Win32 API for this report, so this calls powercfg.exe,
        with output captured in memory and the exit code checked.
    .EXAMPLE
        Export-BatteryReport -OutFile C:\Temp\battery.html -Duration 14

        Writes an HTML report covering the last 14 days and returns the file.
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
        # Default: .\battery-report.html (or .xml with -FormatXml).
        [Parameter(ParameterSetName = 'OutputReport', Position = 0)]
        [Parameter(ParameterSetName = 'TransformXml')]
        [string]$OutFile,

        # Write the report as XML instead of HTML.
        [Parameter(ParameterSetName = 'OutputReport')]
        [switch]$FormatXml,

        # Number of days of history to analyze.
        [Parameter(ParameterSetName = 'OutputReport')]
        [ValidateRange(1, 3650)]
        [int]$Duration,

        # Convert an existing XML report (-FilePath) to HTML.
        [Parameter(ParameterSetName = 'TransformXml', Mandatory = $true)]
        [switch]$ReformatXml,

        # Path to an XML report produced with -FormatXml.
        [Parameter(ParameterSetName = 'TransformXml', Mandatory = $true)]
        [string]$FilePath
    )

    $report = @{
        Cmdlet      = $PSCmdlet
        Option      = 'batteryreport'
        DefaultName = 'battery-report'
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
