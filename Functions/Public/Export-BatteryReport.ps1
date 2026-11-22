function Export-BatteryReport {
    <#
    .SYNOPSIS
    Generates a battery usage and capacity history report. Equivalent to powercfg /batteryreport.
    .DESCRIPTION
    Writes an HTML or XML report of installed batteries (design and full
    charge capacity, chemistry, cycle count), recent usage, and capacity and
    life estimates over time. For the current charge only, use
    Get-PowerBatteryState.

    There is no public Win32 API for this report, so this calls powercfg.exe,
    with output captured in memory and the exit code checked.
    .PARAMETER OutFile
    Report path. Relative paths resolve against the current PowerShell
    location. The extension is corrected to .html or .xml to match the format.
    Default: .\battery-report.html (or .xml with -FormatXML).
    .PARAMETER FormatXML
    Write the report as XML instead of HTML.
    .PARAMETER Duration
    Number of days of history to analyze.
    .PARAMETER ReformatXML
    Convert an existing XML report (-FilePath) to HTML.
    .PARAMETER FilePath
    Path to an XML report produced with -FormatXML.
    .EXAMPLE
    Export-BatteryReport -OutFile C:\Temp\battery.html -Duration 14
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
        [ValidateRange(1, 3650)]
        [int]$Duration,

        [Parameter(ParameterSetName = 'TransformXML', Mandatory = $true)]
        [switch]$ReformatXML,

        [Parameter(ParameterSetName = 'TransformXML', Mandatory = $true)]
        [string]$FilePath
    )

    $report = @{
        Cmdlet      = $PSCmdlet
        Option      = 'batteryreport'
        DefaultName = 'battery-report'
        OutFile     = $OutFile
    }
    if ($PSCmdlet.ParameterSetName -eq 'TransformXML') {
        $report.TransformXml = $FilePath
    }
    else {
        $report.Xml = $FormatXML
        $report.Duration = $Duration
    }
    Invoke-PowerCfgReport @report
}
