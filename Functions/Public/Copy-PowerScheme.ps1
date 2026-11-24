function Copy-PowerScheme {
    <#
    .SYNOPSIS
        Duplicates a power scheme. Equivalent to powercfg /duplicatescheme.
    .DESCRIPTION
        Calls PowerDuplicateScheme, then optionally PowerWriteFriendlyName and
        PowerWriteDescription on the copy.
    .EXAMPLE
        Get-PowerScheme -Name Balanced | Copy-PowerScheme -NewName 'Balanced (no sleep)'

        Creates a copy of Balanced under a new GUID, names it, and returns the new scheme.
    .OUTPUTS
        PsPowerCfg.PowerScheme
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PsPowerCfg.PowerScheme])]
    param(
        # Source scheme GUID. Accepts pipeline input from Get-PowerScheme.
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [Alias('ID', 'SchemeGuid')]
        [guid]$Guid,

        # GUID for the new scheme. A new GUID is generated when omitted.
        [guid]$DestinationGuid,

        # Name for the copy. Without it the copy keeps the source name, as powercfg does.
        [ValidateNotNullOrEmpty()]
        [string]$NewName,

        # Description for the copy.
        [string]$Description
    )

    process {
        if (-not $PSCmdlet.ShouldProcess("$Guid", 'Duplicate power scheme')) { return }
        $destination = $null
        if ($PSBoundParameters.ContainsKey('DestinationGuid')) { $destination = [Nullable[guid]]$DestinationGuid }
        $name = if ($NewName) { $NewName } else { $null }
        $desc = if ($PSBoundParameters.ContainsKey('Description')) { [string]$Description } else { $null }
        $r = [PsPowerCfg.Safe]::DuplicateScheme($Guid, $destination, $name, $desc)
        if ($r.Failed) {
            $record = New-NativeErrorRecord -Result $r -ErrorId 'CopyPowerSchemeFailed' -TargetObject $Guid
            $PSCmdlet.WriteError($record)
            return
        }
        $r.Value
    }
}
