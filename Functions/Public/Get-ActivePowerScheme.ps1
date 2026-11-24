function Get-ActivePowerScheme {
    <#
    .SYNOPSIS
        Gets the active power scheme. Equivalent to powercfg /getactivescheme.
    .DESCRIPTION
        Calls PowerGetActiveScheme in powrprof.dll directly.
    .EXAMPLE
        Get-ActivePowerScheme
    .EXAMPLE
        (Get-ActivePowerScheme).Guid
    .OUTPUTS
        PsPowerCfg.PowerScheme
    #>
    [CmdletBinding()]
    [OutputType([PsPowerCfg.PowerScheme])]
    param()

    [PsPowerCfg.PowerApi]::GetActivePowerScheme()
}
