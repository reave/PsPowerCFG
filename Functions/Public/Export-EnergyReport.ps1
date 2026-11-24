function Export-EnergyReport {
    <#
    .SYNOPSIS
        Analyzes the system for energy-efficiency and battery-life problems. Equivalent to
        powercfg /energy.
    .DESCRIPTION
        Observes the system for -Duration seconds (default 60) and writes an HTML
        or XML report of errors, warnings and information about power use. Run it
        while the machine is idle with no open programs.

        There is no public Win32 API for this analysis, so this calls powercfg.exe,
        with output captured in memory and the exit code checked. Requires an
        elevated session.
    .EXAMPLE
        Export-EnergyReport -Duration 120 -OutFile C:\Temp\energy.html

        Observes the system for two minutes, then writes the HTML report and returns the file.
    .OUTPUTS
        System.IO.FileInfo
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        # Report path. Relative paths resolve against the current PowerShell
        # location. The extension is corrected to .html or .xml to match the format.
        # Default: .\energy-report.html (or .xml with -FormatXml).
        [Parameter(Position = 0)]
        [string]$OutFile,

        # Write the report as XML instead of HTML.
        [switch]$FormatXml,

        # Seconds to observe the system. Default 60.
        [ValidateRange(1, 3600)]
        [int]$Duration
    )

    Assert-IsAdmin -Cmdlet $PSCmdlet
    $report = @{
        Cmdlet      = $PSCmdlet
        Option      = 'energy'
        DefaultName = 'energy-report'
        OutFile     = $OutFile
        Xml         = $FormatXml
        Duration    = $Duration
    }
    Invoke-PowerCfgReport @report
}
