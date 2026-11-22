function Get-PowerBatteryState {
    <#
    .SYNOPSIS
    Reports AC/battery status, charge and estimated runtime.
    .DESCRIPTION
    Calls CallNtPowerInformation(SystemBatteryState), which combines all
    batteries into one view. Capacities are in mWh on most systems, and Rate
    is in mW: positive while charging, negative while discharging.
    EstimatedTime is empty while on AC or while Windows has no estimate yet.

    For per-battery design capacity, chemistry and cycle count, use
    powercfg /batteryreport.
    .EXAMPLE
    Get-PowerBatteryState
    .EXAMPLE
    if (-not (Get-PowerBatteryState).AcOnLine) { 'On battery' }
    .OUTPUTS
    PsPowerCfg.PowerBatteryState
    #>
    [CmdletBinding()]
    [OutputType([PsPowerCfg.PowerBatteryState])]
    param()

    $r = [PsPowerCfg.Safe]::GetBatteryState()
    if ($r.Failed) {
        $PSCmdlet.WriteError((New-NativeErrorRecord -Result $r -ErrorId 'GetPowerBatteryStateFailed'))
        return
    }
    $r.Value
}
