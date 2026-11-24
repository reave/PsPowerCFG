function Rename-PowerScheme {
    <#
    .SYNOPSIS
        Changes a power scheme's name and optionally its description. Equivalent to
        powercfg /changename.
    .EXAMPLE
        Rename-PowerScheme -Guid 381b4222-f694-41f0-9685-ff5bb260df2e -NewName 'Customized Balanced'

        Renames the Balanced scheme. The description is left as it was.
    .OUTPUTS
        None, or PsPowerCfg.PowerScheme with -PassThru.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PsPowerCfg.PowerScheme])]
    param(
        # Scheme GUID. Accepts pipeline input from Get-PowerScheme.
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('ID', 'SchemeGuid')]
        [guid]$Guid,

        # New friendly name.
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$NewName,

        # New description. Left unchanged when omitted.
        [string]$Description,

        # Return the updated scheme.
        [switch]$PassThru
    )

    process {
        if (-not $PSCmdlet.ShouldProcess("$Guid", "Rename power scheme to '$NewName'")) { return }
        $desc = if ($PSBoundParameters.ContainsKey('Description')) { [string]$Description } else { $null }
        $r = [PsPowerCfg.Safe]::RenameScheme($Guid, $NewName, $desc)
        if ($r.Failed) {
            $record = New-NativeErrorRecord -Result $r -ErrorId 'RenamePowerSchemeFailed' -TargetObject $Guid
            $PSCmdlet.WriteError($record)
            return
        }
        if ($PassThru) { $r.Value }
    }
}
