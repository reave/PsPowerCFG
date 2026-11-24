function Resolve-PowerSecurityTarget {
    <#
    .SYNOPSIS
        Maps -Guid / -Action to the POWER_DATA_ACCESSOR + GUID pair that
        PowerReadSecurityDescriptor / PowerWriteSecurityDescriptor take.
    .NOTES
        ActionSetActive = ACCESS_ACTIVE_SCHEME (19), ActionCreate =
        ACCESS_CREATE_SCHEME (20), ActionDefault = ACCESS_DEFAULT_SECURITY_DESCRIPTOR
        (14). Any GUID, scheme or setting, uses ACCESS_SCHEME (16): verified on
        Win11 26100 that 16 returns the SDDL powercfg /getsecuritydescriptor prints
        for a setting, while 17 and 18 fail with ERROR_INVALID_PARAMETER.
    .EXAMPLE
        $target = Resolve-PowerSecurityTarget -Cmdlet $PSCmdlet -Action 'ActionSetActive'

        Returns Accessor 19 (ACCESS_ACTIVE_SCHEME), Guid $null and Label 'ActionSetActive'.
    .OUTPUTS
        PSCustomObject with Accessor, Guid and Label properties.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The caller's $PSCmdlet, so a bad GUID or alias is attributed to the public function.
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCmdlet]$Cmdlet,

        # Scheme or setting GUID, or a powercfg alias. Ignored when -Action is given.
        [string]$Guid,

        # ActionSetActive, ActionCreate or ActionDefault.
        [string]$Action
    )

    if ($Action) {
        $accessor = switch ($Action) {
            'ActionSetActive' { 19 }
            'ActionCreate' { 20 }
            'ActionDefault' { 14 }
        }
        [pscustomobject]@{ Accessor = [uint32]$accessor; Guid = $null; Label = $Action }
        return
    }

    $g = Resolve-PowerGuid -Cmdlet $Cmdlet -Value $Guid -Kind Scheme
    [pscustomobject]@{ Accessor = [uint32]16; Guid = [Nullable[guid]]$g; Label = "$g" }
}
