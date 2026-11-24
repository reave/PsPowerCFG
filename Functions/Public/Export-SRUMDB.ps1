function Export-SRUMDB {
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
    .PARAMETER OutFile
        Output path. Relative paths resolve against the current PowerShell
        location. The extension is corrected to match -Format.
        Default: .\srumutil.csv (or .xml).
    .PARAMETER Format
        Csv (default) or Xml.
    .PARAMETER FormatXML
        Legacy switch, same as -Format Xml.
    .PARAMETER FormatCSV
        Legacy switch, same as -Format Csv.
    .EXAMPLE
        Export-SRUMDB -OutFile C:\Temp\srum.csv
    .EXAMPLE
        Export-SRUMDB -Format Xml
    .OUTPUTS
        System.IO.FileInfo
    #>
    [CmdletBinding(DefaultParameterSetName = 'Format')]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Position = 0)]
        [string]$OutFile,

        [Parameter(ParameterSetName = 'Format')]
        [ValidateSet('Csv', 'Xml')]
        [string]$Format = 'Csv',

        [Parameter(ParameterSetName = 'LegacyXml', Mandatory = $true)]
        [switch]$FormatXML,

        [Parameter(ParameterSetName = 'LegacyCsv', Mandatory = $true)]
        [switch]$FormatCSV
    )

    begin {
        Assert-IsAdmin -Cmdlet $PSCmdlet
    }

    process {
        if ($FormatXML) { $Format = 'Xml' }
        if ($FormatCSV) { $Format = 'Csv' }

        $extension = '.' + $Format.ToLowerInvariant()
        if (-not $OutFile) { $OutFile = 'srumutil' + $extension }
        $target = Resolve-OutputPath -Cmdlet $PSCmdlet -Path $OutFile -Extension $extension

        $arguments = @('/srumutil', '/output', $target, "/$($Format.ToLowerInvariant())")
        $stdout = (Invoke-PowerCfg -Cmdlet $PSCmdlet -ArgumentList $arguments -WorkingDirectory ([System.IO.Path]::GetDirectoryName($target)))

        if (-not [System.IO.File]::Exists($target)) {
            $detail = if ($stdout -and $stdout.Trim()) { ' powercfg said: ' + $stdout.Trim() } else { '' }
            $exception = [System.IO.FileNotFoundException]::new("powercfg /srumutil exited 0 but did not create $target.$detail", $target)
            $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                    $exception, 'ReportNotCreated', [System.Management.Automation.ErrorCategory]::InvalidResult, $target))
        }
        [System.IO.FileInfo]::new($target)
    }
}
