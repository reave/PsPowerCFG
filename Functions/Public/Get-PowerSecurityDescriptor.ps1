function Get-PowerSecurityDescriptor {
    <#
    .SYNOPSIS
        Gets the SDDL security descriptor of a power scheme, setting or action.
        Equivalent to powercfg /getsecuritydescriptor.
    .DESCRIPTION
        Calls PowerReadSecurityDescriptor.
    .EXAMPLE
        Get-PowerSecurityDescriptor -Action ActionSetActive

        Shows who may change the active scheme, as an SDDL string.
    .EXAMPLE
        Get-PowerScheme | Get-PowerSecurityDescriptor

        Shows the security descriptor of every power scheme.
    .OUTPUTS
        PSCustomObject with Target and Sddl.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Guid')]
    [OutputType('PsPowerCfg.PowerSecurityDescriptor')]
    param(
        # Scheme or setting GUID, or an alias. Accepts Guid from Get-PowerScheme.
        [Parameter(ParameterSetName = 'Guid', Mandatory = $true, Position = 0,
            ValueFromPipelineByPropertyName = $true)]
        [Alias('SchemeGuid')]
        [string]$Guid,

        # ActionSetActive, ActionCreate or ActionDefault.
        [Parameter(ParameterSetName = 'Action', Mandatory = $true)]
        [ValidateSet('ActionSetActive', 'ActionCreate', 'ActionDefault')]
        [string]$Action
    )

    process {
        $t = Resolve-PowerSecurityTarget -Cmdlet $PSCmdlet -Guid $Guid -Action $Action
        $r = [PsPowerCfg.Safe]::ReadSecurityDescriptor($t.Accessor, $t.Guid)
        if ($r.Failed) {
            $errorId = 'GetPowerSecurityDescriptorFailed'
            $record = New-NativeErrorRecord -Result $r -ErrorId $errorId -TargetObject $t.Label
            $PSCmdlet.WriteError($record)
            return
        }
        [pscustomobject]@{
            PSTypeName = 'PsPowerCfg.PowerSecurityDescriptor'
            Target     = $t.Label
            Sddl       = [string]$r.Value
        }
    }
}
