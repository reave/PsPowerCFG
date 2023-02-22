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
        }
        Else {
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