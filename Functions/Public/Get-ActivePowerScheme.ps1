function Get-ActivePowerScheme {
    <#
    .SYNOPSIS
        Gets the active power scheme. Equivalent to powercfg /getactivescheme.
    .DESCRIPTION
        Calls PowerGetActiveScheme in powrprof.dll directly.
    .EXAMPLE
        Get-ActivePowerScheme

        Shows the name and GUID of the active scheme.
    .EXAMPLE
        (Get-ActivePowerScheme).Guid

        Returns only the active scheme's GUID, for passing to other commands.
    .OUTPUTS
        PsPowerCfg.PowerScheme
    #>
    [CmdletBinding()]
    [OutputType([PsPowerCfg.PowerScheme])]
    param()

    [PsPowerCfg.PowerApi]::GetActivePowerScheme()
}
