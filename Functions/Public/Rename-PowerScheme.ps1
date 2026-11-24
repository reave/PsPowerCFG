function Rename-PowerScheme {
    <#
    .SYNOPSIS
        Changes a power scheme's name and optionally its description. Equivalent to powercfg /changename.
    .PARAMETER Guid
        Scheme GUID. Accepts pipeline input from Get-PowerScheme.
    .PARAMETER NewName
        New friendly name.
    .PARAMETER Description
        New description. Left unchanged when omitted.
    .PARAMETER PassThru
        Return the updated scheme.
    .EXAMPLE
        Rename-PowerScheme -Guid 381b4222-f694-41f0-9685-ff5bb260df2e -NewName 'Customized Balanced'
    .OUTPUTS
        None, or PsPowerCfg.PowerScheme with -PassThru.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PsPowerCfg.PowerScheme])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('ID', 'SchemeGuid')]
        [guid]$Guid,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$NewName,

        [string]$Description,

        [switch]$PassThru
    )

    process {
        if (-not $PSCmdlet.ShouldProcess("$Guid", "Rename power scheme to '$NewName'")) { return }
        $desc = if ($PSBoundParameters.ContainsKey('Description')) { [string]$Description } else { $null }
        $r = [PsPowerCfg.Safe]::RenameScheme($Guid, $NewName, $desc)
        if ($r.Failed) {
            $PSCmdlet.WriteError((New-NativeErrorRecord -Result $r -ErrorId 'RenamePowerSchemeFailed' -TargetObject $Guid))
            return
        }
        if ($PassThru) { $r.Value }
    }
}
