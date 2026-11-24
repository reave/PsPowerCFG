function Import-PowerScheme {
    <#
    .SYNOPSIS
        Imports a power scheme from a .pow file. Equivalent to powercfg /import.
    .DESCRIPTION
        Calls PowerImportPowerScheme. Requires an elevated session.
    .PARAMETER Path
        Path to a .pow file created by Export-PowerScheme or powercfg /export.
    .PARAMETER DestinationGuid
        GUID for the imported scheme. A new GUID is generated when omitted.
    .PARAMETER NewName
        Rename the imported scheme.
    .EXAMPLE
        Import-PowerScheme -Path C:\Temp\scheme.pow -NewName 'Imported'
    .OUTPUTS
        PsPowerCfg.PowerScheme
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PsPowerCfg.PowerScheme])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName')]
        [string]$Path,

        [guid]$DestinationGuid,

        [ValidateNotNullOrEmpty()]
        [string]$NewName
    )

    begin {
        Assert-IsAdmin -Cmdlet $PSCmdlet
    }

    process {
        $full = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)
        if (-not [System.IO.File]::Exists($full)) {
            $exception = [System.IO.FileNotFoundException]::new("Power scheme file not found: $full", $full)
            $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                    $exception, 'PowerSchemeFileNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $full))
            return
        }
        if (-not $PSCmdlet.ShouldProcess($full, 'Import power scheme')) { return }
        $destination = if ($PSBoundParameters.ContainsKey('DestinationGuid')) { [Nullable[guid]]$DestinationGuid } else { $null }
        $name = if ($NewName) { $NewName } else { $null }
        $r = [PsPowerCfg.Safe]::ImportScheme($full, $destination, $name)
        if ($r.Failed) {
            $PSCmdlet.WriteError((New-NativeErrorRecord -Result $r -ErrorId 'ImportPowerSchemeFailed' -TargetObject $full))
            return
        }
        $r.Value
    }
}
