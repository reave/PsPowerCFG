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
    .EXAMPLE
    Export-BatteryReport -OutFile C:\Temp\battery.html -Duration 14
    .OUTPUTS
    System.IO.FileInfo
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Position = 0)]
        [string]$OutFile,

        [switch]$FormatXML,

        [ValidateRange(1, 3650)]
        [int]$Duration
    )

    Invoke-PowerCfgReport -Cmdlet $PSCmdlet -Option 'batteryreport' -DefaultName 'battery-report' -OutFile $OutFile -Xml:$FormatXML -Duration $Duration
}
