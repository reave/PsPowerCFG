function Invoke-PowerCfgReport {
    <#
    .SYNOPSIS
    Shared implementation for the powercfg report options that have no public
    API (/systempowerreport, /systemsleepdiagnostics, /batteryreport, ...).
    .OUTPUTS
    System.IO.FileInfo for the generated report.
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCmdlet]$Cmdlet,

        # powercfg option without the slash, e.g. 'systempowerreport'.
        [Parameter(Mandatory = $true)]
        [string]$Option,

        # Default base file name (no extension) when -OutFile is not given.
        [Parameter(Mandatory = $true)]
        [string]$DefaultName,

        [string]$OutFile,

        [switch]$Xml,

        [int]$Duration,

        # Existing XML report to convert to HTML.
        [string]$TransformXml
    )

    if ($TransformXml) {
        $source = $Cmdlet.GetUnresolvedProviderPathFromPSPath($TransformXml)
        if (-not [System.IO.File]::Exists($source)) {
            $exception = [System.IO.FileNotFoundException]::new("XML report not found: $source", $source)
            $Cmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                    $exception, 'ReportNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $source))
        }
        if (-not $OutFile) { $OutFile = [System.IO.Path]::ChangeExtension($source, '.html') }
        $target = Resolve-OutputPath -Cmdlet $Cmdlet -Path $OutFile -Extension '.html'
        $arguments = @("/$Option", '/transformxml', $source, '/output', $target)
    }
    else {
        $extension = if ($Xml) { '.xml' } else { '.html' }
        if (-not $OutFile) { $OutFile = $DefaultName + $extension }
        $target = Resolve-OutputPath -Cmdlet $Cmdlet -Path $OutFile -Extension $extension
        $arguments = @("/$Option", '/output', $target)
        if ($Xml) { $arguments += '/xml' }
        if ($Duration -gt 0) { $arguments += @('/duration', [string]$Duration) }
    }

    [void](Invoke-PowerCfg -Cmdlet $Cmdlet -ArgumentList $arguments -WorkingDirectory ([System.IO.Path]::GetDirectoryName($target)))

    if (-not [System.IO.File]::Exists($target)) {
        $exception = [System.IO.FileNotFoundException]::new("powercfg /$Option reported success but did not create $target", $target)
        $Cmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                $exception, 'ReportNotCreated', [System.Management.Automation.ErrorCategory]::InvalidResult, $target))
    }
    [System.IO.FileInfo]::new($target)
}
