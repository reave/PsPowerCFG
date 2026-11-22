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
        try {
            $destination = if ($PSBoundParameters.ContainsKey('DestinationGuid')) { [Nullable[guid]]$DestinationGuid } else { $null }
            $new = [PsPowerCfg.PowerApi]::DuplicateScheme($Guid, $destination)
            if ($NewName) { [PsPowerCfg.PowerApi]::WriteFriendlyName($new, $null, $null, $NewName) }
            if ($PSBoundParameters.ContainsKey('Description')) { [PsPowerCfg.PowerApi]::WriteDescription($new, $null, $null, $Description) }
            [PsPowerCfg.PowerApi]::GetScheme($new)
        }
        catch {
            $PSCmdlet.WriteError((New-NativeErrorRecord -ErrorRecord $_ -ErrorId 'CopyPowerSchemeFailed' -TargetObject $Guid))
        }
    }
}
