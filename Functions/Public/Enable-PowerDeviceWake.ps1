function Enable-PowerDeviceWake {
    <#
    .SYNOPSIS
        Allows a device to wake the system from sleep. Equivalent to powercfg /deviceenableawake.
    .DESCRIPTION
        Calls DevicePowerSetDeviceState, then re-reads the wake_armed list and
        writes an error if the device's state did not change. Only devices in
        Get-PowerDevice -Query WakeProgrammable can be changed. Requires an
        elevated session.
    .EXAMPLE
        Enable-PowerDeviceWake -Name 'HID-compliant mouse'

        Lets the mouse wake the system, after a confirmation prompt.
    .EXAMPLE
        Get-PowerDevice -Query WakeProgrammable -Name '*Ethernet*' | Enable-PowerDeviceWake -WhatIf

        Shows which network adapters would be armed, without changing them.
    .OUTPUTS
        PsPowerCfg.PowerDevice
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '',
        Justification = 'Set-PowerDeviceWakeState calls ShouldProcess on the $PSCmdlet passed to it.')]
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType([PsPowerCfg.PowerDevice])]
    param(
        # Device name as Get-PowerDevice prints it. Wildcards are supported and
        # match against the wake-programmable devices; each match is confirmed
        # separately.
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [SupportsWildcards()]
        [string[]]$Name,

        # Return the device after the change.
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
            $stateParams = @{
                Cmdlet       = $PSCmdlet
                Name         = $n
                Enable       = $true
                Programmable = $programmable
                PassThru     = $PassThru
            }
            Set-PowerDeviceWakeState @stateParams
        }
    }
}
