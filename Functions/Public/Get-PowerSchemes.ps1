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
        }
        Else {
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