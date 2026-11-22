function Export-SystemPowerReport {
    <#
    .SYNOPSIS
    Generates a system power transition report. Equivalent to powercfg /systempowerreport (alias /sleepstudy).
    .DESCRIPTION
    Reports system power transitions over the last three days (or -Duration
    days), including modern standby / connected standby efficiency.

    There is no public Win32 API for this report, so this calls powercfg.exe,
    with output captured in memory and the exit code checked. Requires an
    elevated session.
    .PARAMETER OutFile
    Report path. Relative paths resolve against the current PowerShell
    location. The extension is corrected to .html or .xml to match the format.
    Default: .\sleepstudy-report.html (or .xml with -FormatXML).
    .PARAMETER FormatXML
    Write the report as XML instead of HTML.
    .PARAMETER Duration
    Number of days of history to analyze.
    .PARAMETER ReformatXML
    Convert an existing XML report (-FilePath) to HTML.
    .PARAMETER FilePath
    Path to an XML report produced with -FormatXML.
    .EXAMPLE
    Export-SystemPowerReport -OutFile C:\Temp\power.html -Duration 7
    .EXAMPLE
    Export-SystemPowerReport -FormatXML -OutFile C:\Temp\power.xml
    .EXAMPLE
    Export-SystemPowerReport -ReformatXML -FilePath C:\Temp\power.xml

    Writes C:\Temp\power.html.
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
            Option      = 'systempowerreport'
            DefaultName = 'sleepstudy-report'
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
}
