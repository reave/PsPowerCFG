function Enable-PowerDeviceWake {
    <#
    .SYNOPSIS
    Allows a device to wake the system from sleep. Equivalent to powercfg /deviceenableawake.
    .DESCRIPTION
    Calls DevicePowerSetDeviceState, then re-reads the wake_armed list and
    writes an error if the device's state did not change. Only devices in
    Get-PowerDevice -Query WakeProgrammable can be changed. Requires an
    elevated session.
    .PARAMETER Name
    Device name as Get-PowerDevice prints it. Wildcards are supported and
    match against the wake-programmable devices; each match is confirmed
    separately.
    .PARAMETER PassThru
    Return the device after the change.
    .EXAMPLE
    Enable-PowerDeviceWake -Name 'HID-compliant mouse'
    .EXAMPLE
    Get-PowerDevice -Query WakeProgrammable -Name '*Ethernet*' | Enable-PowerDeviceWake -WhatIf
    .OUTPUTS
    PsPowerCfg.PowerDevice
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType([PsPowerCfg.PowerDevice])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [SupportsWildcards()]
        [string[]]$Name,

        [switch]$PassThru
    )

    begin {
        Assert-IsAdmin -Cmdlet $PSCmdlet
        $list = [PsPowerCfg.Safe]::GetDevices([PsPowerCfg.PowerDeviceQuery]::WakeProgrammable)
        if ($list.Failed) {
            $PSCmdlet.ThrowTerminatingError((New-NativeErrorRecord -Result $list -ErrorId 'GetPowerDeviceFailed'))
        }
        $programmable = @($list.Value)
    }

    process {
        foreach ($n in $Name) {
            Set-PowerDeviceWakeState -Cmdlet $PSCmdlet -Name $n -Enable $true -Programmable $programmable -PassThru:$PassThru
        }
    }
}
