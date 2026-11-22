function Copy-PowerScheme {
    <#
    .SYNOPSIS
    Duplicates a power scheme. Equivalent to powercfg /duplicatescheme.
    .DESCRIPTION
    Calls PowerDuplicateScheme, then optionally PowerWriteFriendlyName and
    PowerWriteDescription on the copy.
    .PARAMETER Guid
    Source scheme GUID. Accepts pipeline input from Get-PowerScheme.
    .PARAMETER DestinationGuid
    GUID for the new scheme. A new GUID is generated when omitted.
    .PARAMETER NewName
    Name for the copy. Without it the copy keeps the source name, as powercfg does.
    .PARAMETER Description
    Description for the copy.
    .EXAMPLE
    Get-PowerScheme -Name Balanced | Copy-PowerScheme -NewName 'Balanced (no sleep)'
    .OUTPUTS
    PsPowerCfg.PowerScheme
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PsPowerCfg.PowerScheme])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('ID', 'SchemeGuid')]
        [guid]$Guid,

        [guid]$DestinationGuid,

        [ValidateNotNullOrEmpty()]
        [string]$NewName,

        [string]$Description
    )

    process {
        if (-not $PSCmdlet.ShouldProcess("$Guid", 'Duplicate power scheme')) { return }
        $destination = if ($PSBoundParameters.ContainsKey('DestinationGuid')) { [Nullable[guid]]$DestinationGuid } else { $null }
        $name = if ($NewName) { $NewName } else { $null }
        $desc = if ($PSBoundParameters.ContainsKey('Description')) { [string]$Description } else { $null }
        $r = [PsPowerCfg.Safe]::DuplicateScheme($Guid, $destination, $name, $desc)
        if ($r.Failed) {
            $PSCmdlet.WriteError((New-NativeErrorRecord -Result $r -ErrorId 'CopyPowerSchemeFailed' -TargetObject $Guid))
            return
        }
        $r.Value
    }
}
