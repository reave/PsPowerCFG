function Export-SrumDb {
    <#
    .SYNOPSIS
        Dumps SRUM energy estimation data to CSV or XML. Equivalent to powercfg /srumutil.
    .DESCRIPTION
        Exports the Energy Estimation data that the System Resource Usage Monitor
        (SRUM) keeps in %SystemRoot%\System32\sru\SRUDB.dat.

        There is no public API for this data: SRUDB.dat is an ESE database held
        open by the Diagnostic Policy Service, so reading it natively would need
        esent.dll interop plus a volume shadow copy. This calls powercfg.exe with
        output captured in memory and the exit code checked. Requires an elevated
        session.
    .EXAMPLE
        Export-SrumDb -OutFile C:\Temp\srum.csv

        Writes the SRUM energy estimation data as CSV and returns the file.
    .EXAMPLE
        Export-SrumDb -Format Xml

        Writes .\srumutil.xml in the current location.
    .NOTES
        Named Export-SRUMDB before 1.6.0. PowerShell command names are not case
        sensitive, so scripts that call Export-SRUMDB keep working.
    .OUTPUTS
        System.IO.FileInfo
    #>
    [CmdletBinding(DefaultParameterSetName = 'Format')]
    [OutputType([System.IO.FileInfo])]
    param(
        # Output path. Relative paths resolve against the current PowerShell
        # location. The extension is corrected to match -Format.
        # Default: .\srumutil.csv (or .xml).
        [Parameter(Position = 0)]
        [string]$OutFile,

        # Csv (default) or Xml.
        [Parameter(ParameterSetName = 'Format')]
        [ValidateSet('Csv', 'Xml')]
        [string]$Format = 'Csv',

        # Legacy switch, same as -Format Xml.
        [Parameter(ParameterSetName = 'LegacyXml', Mandatory = $true)]
        [switch]$FormatXml,

        # Legacy switch, same as -Format Csv.
        [Parameter(ParameterSetName = 'LegacyCsv', Mandatory = $true)]
        [switch]$FormatCsv
    )

    begin {
        Assert-IsAdmin -Cmdlet $PSCmdlet
    }

    process {
        if ($FormatXml) { $Format = 'Xml' }
        if ($FormatCsv) { $Format = 'Csv' }

        $extension = '.' + $Format.ToLowerInvariant()
        if (-not $OutFile) { $OutFile = 'srumutil' + $extension }
        $target = Resolve-OutputPath -Cmdlet $PSCmdlet -Path $OutFile -Extension $extension

        $arguments = @('/srumutil', '/output', $target, "/$($Format.ToLowerInvariant())")
        $invokeParams = @{
            Cmdlet           = $PSCmdlet
            ArgumentList     = $arguments
            WorkingDirectory = [System.IO.Path]::GetDirectoryName($target)
        }
        $stdout = Invoke-PowerCfg @invokeParams

        if (-not [System.IO.File]::Exists($target)) {
            $detail = if ($stdout -and $stdout.Trim()) { ' powercfg said: ' + $stdout.Trim() } else { '' }
            $exception = [System.IO.FileNotFoundException]::new(
                "powercfg /srumutil exited 0 but did not create $target.$detail", $target)
            $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                    $exception,
                    'ReportNotCreated',
                    [System.Management.Automation.ErrorCategory]::InvalidResult,
                    $target))
        }
        [System.IO.FileInfo]::new($target)
    }
}
