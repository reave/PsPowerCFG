function Export-SystemPowerReport {
    <#
    .SYNOPSIS
    Export System Power Reports
    .DESCRIPTION
    Generates a report of system power transitions over the last three days on
    the system, including connected standby power efficiency. The
    SYSTEMPOWERREPORT command will generate an HTML report file in the current
    path or the designated path.
    .PARAMETER OutFile
    Full path to where you want the report saved.

    For XML reports make sure the ending extension is .xml
    Standard Reports are HTML
    .PARAMETER FormatXML
    If you would prefer the report in XML instead of HTML pass this switch.

    Note: We will attempt to edit the outfile extension for you if you forget too
    .PARAMETER Duration
    Duration of days to go back in history and analyze
    .PARAMETER ReformatXML
    Reformat an XML report into HTML

    Note: This will save the reformatted report into the current path or working directory
    .PARAMETER FilePath
    Path to an existing XML report that we can convert to HTML
    .EXAMPLE
    Export-SystemPowerReport -OutFile C:\Temp\Test.html

    Export an HTML Power Report
    .EXAMPLE
    Export-SystemPowerReport -ReformatXML -FilePath C:\Temp\Test.XML

    Converts the Test.XML to a sleep-study.html
    .NOTES
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ParameterSetName = 'OutputReport')]
        [System.IO.FileInfo]$OutFile = "$($PSScriptRoot)\sleepstudy.html",
        [Parameter(Mandatory = $false, ParameterSetName = 'OutputReport')]
        [switch]$FormatXML,
        [Parameter(Mandatory = $false, ParameterSetName = 'OutputReport')]
        [int]$Duration,
        [Parameter(Mandatory = $false, ParameterSetName = 'TransformXML')]
        [switch]$ReformatXML,
        [Parameter(Mandatory = $false, ParameterSetName = 'TransformXML')]
        [string]$FilePath
    )
    begin {
        If (!(Test-IsAdmin)) {
            Write-Warning "This command requires administrator privileges and must be executed from an elevated command prompt."
            break
        }
    }

    process {
        If ($FormatXML) {
            Write-Verbose "Formatting Report as XML"
            If (!($OutFile.Extension -eq '.xml')) {
                Write-Verbose "Converting $($OutFile.FullName) to XML"
                $OutFile = $OutFile.FullName -Replace "$($OutFile.Extension)", ".xml"
            }

            Start-Process -FilePath powercfg.exe -ArgumentList "/SYSTEMPOWERREPORT /OUTPUT ""$($OutFile)"" /XML" -WindowStyle Hidden -Wait
            Write-Output "Sleep Study report saved to file path: $($OutFile)"
            Return
        }

        If ($ReformatXML) {
            If (!(Test-Path -Path "$($FilePath)" -ErrorAction SilentlyContinue)) {
                Write-Error -Exception [System.IO.FileNotFoundException] -Message "Report file not found. Please enter the correct path to an XML System Power Report and try again."
                Return
            }
            Else {
                Start-Process -FilePath powercfg.exe -ArgumentList "/SYSTEMPOWERREPORT /TRANSFORMXML ""$($FilePath)""" -WindowStyle Hidden -Wait -WorkingDirectory "$(Split-Path -Path $FilePath -Parent)"
                Write-Output "Sleep Study report saved to file path: $(Split-Path -Path $FilePath -Parent)\sleepstudy-report.html"
                Return
            }
        }

        Write-Verbose "Formatting Report as HTML"
        Start-Process -FilePath powercfg.exe -ArgumentList "/SYSTEMPOWERREPORT /OUTPUT ""$($OutFile)""" -WindowStyle Hidden -Wait
        Write-Output "Sleep Study report saved to file path: $($OutFile)"
    }
}