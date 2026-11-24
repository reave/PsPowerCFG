function Invoke-PowerCfgReport {
    <#
    .SYNOPSIS
        Shared implementation for the powercfg report options that have no public
        API (/systempowerreport, /systemsleepdiagnostics, /batteryreport, ...).
    .EXAMPLE
        Invoke-PowerCfgReport -Cmdlet $PSCmdlet -Option 'energy' -DefaultName 'energy-report' -Duration 30

        Runs powercfg /energy /output .\energy-report.html /duration 30 and returns the
        report file. Stops the caller with ReportNotCreated if powercfg wrote nothing.
    .OUTPUTS
        System.IO.FileInfo for the generated report.
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        # The caller's $PSCmdlet, so the error is attributed to the public function.
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCmdlet]$Cmdlet,

        # powercfg option without the slash, e.g. 'systempowerreport'.
        [Parameter(Mandatory = $true)]
        [string]$Option,

        # Default base file name (no extension) when -OutFile is not given.
        [Parameter(Mandatory = $true)]
        [string]$DefaultName,

        # Output path. Default: DefaultName plus .html or .xml in the current location.
        [string]$OutFile,

        # Ask powercfg for XML instead of HTML (/xml).
        [switch]$Xml,

        # Seconds to observe, for options that take /duration. 0 or less omits it.
        [int]$Duration,

        # Existing XML report to convert to HTML.
        [string]$TransformXml
    )

    if ($TransformXml) {
        $source = $Cmdlet.GetUnresolvedProviderPathFromPSPath($TransformXml)
        if (-not [System.IO.File]::Exists($source)) {
            $exception = [System.IO.FileNotFoundException]::new("XML report not found: $source", $source)
            $Cmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                    $exception,
                    'ReportNotFound',
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $source))
        }
        if (-not $OutFile) { $OutFile = [System.IO.Path]::ChangeExtension($source, '.html') }
        $target = Resolve-OutputPath -Cmdlet $Cmdlet -Path $OutFile -Extension '.html'
        $arguments = @("/$Option", '/transformxml', $source, '/output', $target)
    } else {
        $extension = if ($Xml) { '.xml' } else { '.html' }
        if (-not $OutFile) { $OutFile = $DefaultName + $extension }
        $target = Resolve-OutputPath -Cmdlet $Cmdlet -Path $OutFile -Extension $extension
        $arguments = @("/$Option", '/output', $target)
        if ($Xml) { $arguments += '/xml' }
        if ($Duration -gt 0) { $arguments += @('/duration', [string]$Duration) }
    }

    $invokeParams = @{
        Cmdlet           = $Cmdlet
        ArgumentList     = $arguments
        WorkingDirectory = [System.IO.Path]::GetDirectoryName($target)
    }
    $stdout = Invoke-PowerCfg @invokeParams

    # Some report options exit 0 without writing anything, e.g.
    # /systemsleepdiagnostics on current Windows 11 builds, which only prints a
    # deprecation notice. Surface powercfg's own text instead of a bare
    # "file not found".
    if (-not [System.IO.File]::Exists($target)) {
        $detail = ''
        if ($stdout -and $stdout.Trim()) {
            $said = foreach ($line in $stdout.Trim() -split '\r?\n') { $line.Trim() }
            $detail = ' powercfg said: ' + ($said -join ' ')
        }
        $exception = [System.IO.FileNotFoundException]::new(
            "powercfg /$Option exited 0 but did not create $target.$detail", $target)
        $Cmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                $exception,
                'ReportNotCreated',
                [System.Management.Automation.ErrorCategory]::InvalidResult,
                $target))
    }
    [System.IO.FileInfo]::new($target)
}
