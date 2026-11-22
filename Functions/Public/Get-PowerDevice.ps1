function Get-PowerDevice {
    <#
    .SYNOPSIS
    Lists devices by power capability. Equivalent to powercfg /devicequery.
    .DESCRIPTION
    Calls DevicePowerEnumDevices for the query, plus the wake_programmable
    and wake_armed lists so every result says whether it can be armed to wake
    the system and whether it is armed now. The device list is opened once
    for all three queries.
    .PARAMETER Query
    The powercfg /devicequery flag: WakeFromS1Supported, WakeFromS2Supported,
    WakeFromS3Supported, WakeFromAny, S1Supported, S2Supported, S3Supported,
    S4Supported, WakeProgrammable, WakeArmed or AllDevices (the default).
    .PARAMETER Name
    Filter by device name. Wildcards are supported.
    .EXAMPLE
    Get-PowerDevice -Query WakeArmed
    .EXAMPLE
    Get-PowerDevice -Query WakeProgrammable -Name '*mouse*' | Disable-PowerDeviceWake -WhatIf
    .OUTPUTS
    PsPowerCfg.PowerDevice
    #>
    [CmdletBinding()]
    [OutputType([PsPowerCfg.PowerDevice])]
    param(
        [Parameter(Position = 0)]
        [PsPowerCfg.PowerDeviceQuery]$Query = [PsPowerCfg.PowerDeviceQuery]::AllDevices,

        [SupportsWildcards()]
        [string]$Name = '*'
    )

    $r = [PsPowerCfg.Safe]::GetDevices($Query)
    if ($r.Failed) {
        $PSCmdlet.WriteError((New-NativeErrorRecord -Result $r -ErrorId 'GetPowerDeviceFailed' -TargetObject $Query))
        return
    }
    $pattern = [System.Management.Automation.WildcardPattern]::new($Name, [System.Management.Automation.WildcardOptions]::IgnoreCase)
    foreach ($d in $r.Value) {
        # -eq as well: names with [ ] do not match themselves as patterns.
        if ($d.Name -eq $Name -or $pattern.IsMatch($d.Name)) { $d }
    }
}
