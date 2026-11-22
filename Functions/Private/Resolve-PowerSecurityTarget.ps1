function Resolve-PowerSecurityTarget {
    <#
    .SYNOPSIS
    Maps -Guid / -Action to the POWER_DATA_ACCESSOR + GUID pair that
    PowerReadSecurityDescriptor / PowerWriteSecurityDescriptor take.
    .NOTES
    ActionSetActive = ACCESS_ACTIVE_SCHEME (19), ActionCreate =
    ACCESS_CREATE_SCHEME (20), ActionDefault = ACCESS_DEFAULT_SECURITY_DESCRIPTOR
    (14). A scheme GUID uses ACCESS_SCHEME (16); a setting GUID uses
    ACCESS_INDIVIDUAL_SETTING (18).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCmdlet]$Cmdlet,

        [string]$Guid,

        [string]$Action
    )

    if ($Action) {
        $accessor = switch ($Action) {
            'ActionSetActive' { 19 }
            'ActionCreate' { 20 }
            'ActionDefault' { 14 }
        }
        return [pscustomobject]@{ Accessor = [uint32]$accessor; Guid = $null; Label = $Action }
    }

    $g = Resolve-PowerGuid -Cmdlet $Cmdlet -Value $Guid -Kind Scheme
    $isScheme = @([PsPowerCfg.PowerApi]::EnumerateSchemes()) -contains $g
    $accessor = if ($isScheme) { 16 } else { 18 }
    [pscustomobject]@{ Accessor = [uint32]$accessor; Guid = [Nullable[guid]]$g; Label = "$g" }
}
