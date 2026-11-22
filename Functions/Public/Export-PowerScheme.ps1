function Export-PowerScheme {
    <#
    .SYNOPSIS
    Exports a power scheme to a .pow file. Equivalent to powercfg /export.
    .DESCRIPTION
    Windows has no public API that writes the .pow format (PowerImportPowerScheme
    exists, an export counterpart does not), so this runs powercfg.exe /export
    with output captured in memory and the exit code checked. The file can be
    re-imported with Import-PowerScheme or powercfg /import. Requires an
    elevated session (powercfg /export fails with 0x522 otherwise).
    .PARAMETER Guid
    Scheme GUID. Accepts pipeline input from Get-PowerScheme.
    .PARAMETER Path
    Destination file. Relative paths resolve against the current PowerShell
    location. Default: .\<scheme name>.pow
    .EXAMPLE
    Get-ActivePowerScheme | Export-PowerScheme -Path C:\Temp\active.pow
    .OUTPUTS
    System.IO.FileInfo
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('ID', 'SchemeGuid')]
        [guid]$Guid,

        [Parameter(Position = 1)]
        [string]$Path
    )

    begin {
        Assert-IsAdmin -Cmdlet $PSCmdlet
    }

    process {
        if (-not $Path) {
            $name = [PsPowerCfg.PowerApi]::ReadFriendlyName($Guid, $null, $null)
            foreach ($c in [System.IO.Path]::GetInvalidFileNameChars()) { $name = $name.Replace($c, '_') }
            $Path = "$name.pow"
        }
        $target = Resolve-OutputPath -Cmdlet $PSCmdlet -Path $Path
        if (-not $PSCmdlet.ShouldProcess("$Guid -> $target", 'Export power scheme')) { return }

        $stdout = Invoke-PowerCfg -Cmdlet $PSCmdlet -ArgumentList @('/export', $target, $Guid.ToString())
        if (-not [System.IO.File]::Exists($target)) {
            $detail = if ($stdout -and $stdout.Trim()) { ' powercfg said: ' + $stdout.Trim() } else { '' }
            $exception = [System.IO.FileNotFoundException]::new("powercfg /export exited 0 but did not create $target.$detail", $target)
            $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                    $exception, 'ExportNotCreated', [System.Management.Automation.ErrorCategory]::InvalidResult, $target))
        }
        [System.IO.FileInfo]::new($target)
    }
}
