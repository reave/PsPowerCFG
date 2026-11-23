function Export-EnergyReport {
    <#
    .SYNOPSIS
    Analyzes the system for energy-efficiency and battery-life problems. Equivalent to powercfg /energy.
    .DESCRIPTION
    Observes the system for -Duration seconds (default 60) and writes an HTML
    or XML report of errors, warnings and information about power use. Run it
    while the machine is idle with no open programs.

    There is no public Win32 API for this analysis, so this calls powercfg.exe,
    with output captured in memory and the exit code checked. Requires an
    elevated session.
    .PARAMETER OutFile
    Report path. Relative paths resolve against the current PowerShell
    location. The extension is corrected to .html or .xml to match the format.
    Default: .\energy-report.html (or .xml with -FormatXML).
    .PARAMETER FormatXML
    Write the report as XML instead of HTML.
    .PARAMETER Duration
    Seconds to observe the system. Default 60.
    .EXAMPLE
    Export-EnergyReport -Duration 120 -OutFile C:\Temp\energy.html
    .OUTPUTS
    System.IO.FileInfo
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Position = 0)]
        [string]$OutFile,

        [switch]$FormatXML,

        [ValidateRange(1, 3600)]
        [int]$Duration
    )

    Assert-IsAdmin -Cmdlet $PSCmdlet
    Invoke-PowerCfgReport -Cmdlet $PSCmdlet -Option 'energy' -DefaultName 'energy-report' -OutFile $OutFile -Xml:$FormatXML -Duration $Duration
}
