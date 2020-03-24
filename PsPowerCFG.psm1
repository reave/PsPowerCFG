Function Test-IsAdmin {
    [CmdletBinding()]
    Param()
    Process {
        ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    }
}

function Get-PowerSchemes {
    <#
	.SYNOPSIS
	Get existing Power Schemes on a computer
	
	.DESCRIPTION
	Get existing Power Schemes on a computer
	
	.EXAMPLE
	Get-PowerSchemes
	
	Returns all of the currently installed power schemes on the computer
	.NOTES
	
	#>
	
    [CmdletBinding()]
    Param()
    Begin {
        $exampleOutput = @"
Existing Power Schemes (* Active)
-----------------------------------
Power Scheme GUID: {[guid]ID*:381b4222-f694-41f0-9685-ff5bb260df2e}  ({[string]Name:Balanced})
Power Scheme GUID: {[guid]ID*:8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c}  ({[string]Name:High performance}) *
Power Scheme GUID: {[guid]ID*:a1841308-3541-4fab-bc81-f71556f20b4a}  ({[string]Name:Power saver})
"@
    }
    Process {
        Write-Verbose "Executing PowerCFG and saving output to ""$($env:TEMP)\ExistingPowerSchemes.txt"""
        Start-Process -FilePath powercfg.exe -ArgumentList '/L' -Wait -WindowStyle Hidden -RedirectStandardOutput "$($env:TEMP)\ExistingPowerSchemes.txt"
		
        If (Test-Path -Path "$($env:TEMP)\ExistingPowerSchemes.txt" -ErrorAction SilentlyContinue) {
            Write-Verbose "Importing our temporary file from $($env:TEMP)"
            $existingPowerSchemes = Get-Content "$($env:TEMP)\ExistingPowerSchemes.txt"
		
            Write-Verbose "Converting the string data to an Object"
            $outputObject = $existingPowerSchemes | ConvertFrom-String -TemplateContent $exampleOutput
			
            $outputObject
        } Else {
            Write-Error -Exception [System.IO.FileNotFoundException] -Message "File not found."
        }
    }
    End {
        Write-Verbose "Cleaning up the exported data"
        If (Test-Path -Path "$($env:TEMP)\ExistingPowerSchemes.txt" -ErrorAction SilentlyContinue) {
            Remove-Item -Path "$($env:TEMP)\ExistingPowerSchemes.txt" -Force
        }
    }
}

function Get-ActivePowerScheme {
    <#
	.SYNOPSIS
	Get the currently active power scheme
	
	.DESCRIPTION
	Get the currently active power scheme
	
	.EXAMPLE
	Get-ActivePowerScheme
	
	.NOTES
	
	#>
    [CmdletBinding()]
    param ()
    begin {
        $exampleOutput = @"
Power Scheme GUID: {[guid]ID*:8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c}  ({[string]Name:High performance})
Power Scheme GUID: {[guid]ID*:8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c}  ({[string]Name:Power saver})
Power Scheme GUID: {[guid]ID*:8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c}  ({[string]Name:Balanced})
"@
    }
	
    process {
        Write-Verbose "Executing PowerCFG and saving output to ""$($env:TEMP)\ActivePowerScheme.txt"""
        Start-Process -FilePath powercfg.exe -ArgumentList '/GETACTIVESCHEME' -Wait -WindowStyle Hidden -RedirectStandardOutput "$($env:TEMP)\ActivePowerScheme.txt"
		
        If (Test-Path -Path "$($env:TEMP)\ActivePowerScheme.txt" -ErrorAction SilentlyContinue) {
            Write-Verbose "Importing our temporary file from $($env:TEMP)"
            $activePowerScheme = Get-Content "$($env:TEMP)\ActivePowerScheme.txt"
		
            Write-Verbose "Converting the string data to an Object"
            $outputObject = $activePowerScheme | ConvertFrom-String -TemplateContent $exampleOutput
			
            $outputObject
        } Else {
            Write-Error -Exception [System.IO.FileNotFoundException] -Message "File not found."
        }
    }
	
    end {
        Write-Verbose "Cleaning up the exported data"
        If (Test-Path -Path "$($env:TEMP)\ActivePowerScheme.txt" -ErrorAction SilentlyContinue) {
            Remove-Item -Path "$($env:TEMP)\ActivePowerScheme.txt" -Force
        }
    }
}

function Export-SystemPowerReport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ParameterSetName = 'OutputReport')]
        [System.IO.FileInfo]$OutFile = "$($PSScriptRoot)\SleepStudy.html",
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
            } Else {
                Start-Process -FilePath powercfg.exe -ArgumentList "/SYSTEMPOWERREPORT /TRANSFORMXML ""$($FilePath)""" -WindowStyle Hidden -Wait -WorkingDirectory "$(Split-Path -Path $FilePath -Parent)"
                Write-Output "Sleep Study report saved to file path: $(Split-Path -Path $FilePath -Parent)\sleepstudy-report.html"
                Return
            }
        }
		
        Write-Verbose "Formatting Report as HTML"
        Start-Process -FilePath powercfg.exe -ArgumentList "/SYSTEMPOWERREPORT /OUTPUT ""$($OutFile)""" -WindowStyle Hidden -Wait
        Write-Output "Sleep Study report saved to file path: $($OutFile)"
    }
	
    end {
    }
}