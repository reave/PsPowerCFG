function Set-PowerSecurityDescriptor {
    <#
    .SYNOPSIS
        Sets the SDDL security descriptor of a power scheme, setting or action. Equivalent to powercfg /setsecuritydescriptor.
    .DESCRIPTION
        Calls PowerWriteSecurityDescriptor. The SDDL is parsed with
        ConvertStringSecurityDescriptorToSecurityDescriptor first, so a malformed
        string is rejected before anything is written. Requires an elevated
        session. Prompts for confirmation (ConfirmImpact High): a wrong descriptor
        can lock standard users or even administrators out of power settings.
        Save the current value with Get-PowerSecurityDescriptor first.
    .PARAMETER Guid
        Scheme or setting GUID, or an alias.
    .PARAMETER Action
        ActionSetActive, ActionCreate or ActionDefault.
    .PARAMETER Sddl
        Security descriptor in SDDL form.
    .EXAMPLE
        Set-PowerSecurityDescriptor -Action ActionSetActive -Sddl 'O:BAG:SYD:P(A;CI;KR;;;BU)(A;CI;KA;;;BA)(A;CI;KA;;;SY)(A;CI;KA;;;CO)'

        Stops standard users from changing the active scheme.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'Guid')]
    param(
        [Parameter(ParameterSetName = 'Guid', Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('SchemeGuid')]
        [string]$Guid,

        [Parameter(ParameterSetName = 'Action', Mandatory = $true)]
        [ValidateSet('ActionSetActive', 'ActionCreate', 'ActionDefault')]
        [string]$Action,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [string]$Sddl
    )

    begin {
        Assert-IsAdmin -Cmdlet $PSCmdlet
    }

    process {
        $parseError = [PsPowerCfg.PowerApi]::ValidateSddl($Sddl)
        if ($null -ne $parseError) {
            $exception = [System.ArgumentException]::new("Invalid SDDL: $parseError")
            $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                    $exception, 'InvalidSddl', [System.Management.Automation.ErrorCategory]::InvalidArgument, $Sddl))
            return
        }

        $t = Resolve-PowerSecurityTarget -Cmdlet $PSCmdlet -Guid $Guid -Action $Action
        if (-not $PSCmdlet.ShouldProcess($t.Label, "Set security descriptor to $Sddl")) { return }
        $r = [PsPowerCfg.Safe]::WriteSecurityDescriptor($t.Accessor, $t.Guid, $Sddl)
        if ($r.Failed) {
            $PSCmdlet.WriteError((New-NativeErrorRecord -Result $r -ErrorId 'SetPowerSecurityDescriptorFailed' -TargetObject $t.Label))
        }
    }
}
