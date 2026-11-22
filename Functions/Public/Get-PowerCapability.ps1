function Get-PowerCapability {
    <#
    .SYNOPSIS
    Reports the sleep states and power hardware the system supports. Equivalent to powercfg /availablesleepstates.
    .DESCRIPTION
    Calls CallNtPowerInformation(SystemPowerCapabilities) and returns the
    SYSTEM_POWER_CAPABILITIES structure: S1-S3 standby, S0 low power idle
    (Modern Standby), hibernate, hybrid sleep, fast startup, the hiberfile
    type, buttons, lid and wake capabilities.

    powercfg /availablesleepstates also prints why a state is unavailable
    (for example a hypervisor or a legacy driver). Those reasons come from a
    kernel information class with no public documentation, so they are not
    reported here.
    .EXAMPLE
    Get-PowerCapability
    .EXAMPLE
    (Get-PowerCapability).StandbyS0LowPowerIdle
    .OUTPUTS
    PsPowerCfg.PowerCapabilities
    #>
    [CmdletBinding()]
    [OutputType([PsPowerCfg.PowerCapabilities])]
    param()

    $r = [PsPowerCfg.Safe]::GetCapabilities()
    if ($r.Failed) {
        $PSCmdlet.WriteError((New-NativeErrorRecord -Result $r -ErrorId 'GetPowerCapabilityFailed'))
        return
    }
    $r.Value
}
