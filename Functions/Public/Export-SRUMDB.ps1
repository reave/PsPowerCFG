function Export-SRUMDB {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [System.IO.FileInfo]$OutFile = "$($PSScriptRoot)\srumdbout.xml",
        [Parameter(Mandatory = $false)]
        [switch]$FormatXML,
        [Parameter(Mandatory = $false)]
        [switch]$FormatCSV
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

            $result = Start-Process -FilePath powercfg.exe -ArgumentList "/SRUMUTIL /OUTPUT ""$($OutFile)"" /XML" -WindowStyle Hidden -Wait -RedirectStandardError "$($env:temp)\error.txt" -RedirectStandardOutput "$($env:temp)\out.txt" -PassThru

            if ($result.ExitCode -ne 0) {
                Write-Verbose "Retrieving and resolving error message."
                $errorContent = Get-Content "$($env:temp)\error.txt"

                Write-Error -Message "$errorContent"
                break
            }
            else {
                Write-Output "SRUM Database saved to file path: $($Outfile.FullName)"
            }
        }

        If ($FormatCSV) {
            Write-Verbose "Formatting Report as CSV"
            If (!($OutFile.Extension -eq '.csv')) {
                Write-Verbose "Converting $($OutFile.FullName) to csv"
                $OutFile = $OutFile.FullName -Replace "$($OutFile.Extension)", ".csv"
            }

            $result = Start-Process -FilePath powercfg.exe -ArgumentList "/SRUMUTIL /OUTPUT ""$($OutFile)"" /CSV" -WindowStyle Hidden -Wait -RedirectStandardError "$($env:temp)\error.txt" -RedirectStandardOutput "$($env:temp)\out.txt" -PassThru

            if ($result.ExitCode -ne 0) {
                Write-Verbose "Retrieving and resolving error message."
                $errorContent = Get-Content "$($env:temp)\error.txt"

                Write-Error -Message "$errorContent"
                break
            }
            else {
                Write-Output "SRUM Database saved to file path: $($Outfile.FullName)"
            }
        }
    }
}