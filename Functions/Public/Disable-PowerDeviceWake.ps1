function Disable-PowerDeviceWake {
    <#
    .SYNOPSIS
        Stops a device from waking the system from sleep. Equivalent to powercfg /devicedisablewake.
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
        Disable-PowerDeviceWake -Name 'HID-compliant mouse'
    .EXAMPLE
        Get-PowerDevice -Query WakeProgrammable -Name '*Ethernet*' | Disable-PowerDeviceWake -WhatIf
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
            Set-PowerDeviceWakeState -Cmdlet $PSCmdlet -Name $n -Enable $false -Programmable $programmable -PassThru:$PassThru
        }
    }
}
