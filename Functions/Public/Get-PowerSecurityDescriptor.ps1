function Get-PowerSecurityDescriptor {
    <#
    .SYNOPSIS
    Gets the SDDL security descriptor of a power scheme, setting or action. Equivalent to powercfg /getsecuritydescriptor.
    .DESCRIPTION
    Calls PowerReadSecurityDescriptor.
    .PARAMETER Guid
    Scheme or setting GUID, or an alias. Accepts Guid from Get-PowerScheme.
    .PARAMETER Action
    ActionSetActive, ActionCreate or ActionDefault.
    .EXAMPLE
    Get-PowerSecurityDescriptor -Action ActionSetActive
    .EXAMPLE
    Get-PowerScheme | Get-PowerSecurityDescriptor
    .OUTPUTS
    PSCustomObject with Target and Sddl.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Guid')]
    param(
        [Parameter(ParameterSetName = 'Guid', Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('SchemeGuid')]
        [string]$Guid,

        [Parameter(ParameterSetName = 'Action', Mandatory = $true)]
        [ValidateSet('ActionSetActive', 'ActionCreate', 'ActionDefault')]
        [string]$Action
    )

    process {
        $t = Resolve-PowerSecurityTarget -Cmdlet $PSCmdlet -Guid $Guid -Action $Action
        try {
            [pscustomobject]@{
                PSTypeName = 'PsPowerCfg.PowerSecurityDescriptor'
                Target     = $t.Label
                Sddl       = [PsPowerCfg.PowerApi]::ReadSecurityDescriptor($t.Accessor, $t.Guid)
            }
        }
        catch {
            $PSCmdlet.WriteError((New-NativeErrorRecord -ErrorRecord $_ -ErrorId 'GetPowerSecurityDescriptorFailed' -TargetObject $t.Label))
        }
    }
}
