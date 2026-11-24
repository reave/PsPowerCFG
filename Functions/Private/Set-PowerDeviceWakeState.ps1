function Set-PowerDeviceWakeState {
    <#
    .SYNOPSIS
        Shared body of Enable-/Disable-PowerDeviceWake: resolves -Name against the
        wake-programmable devices, confirms, and calls the native setter.
    .EXAMPLE
        Set-PowerDeviceWakeState -Cmdlet $PSCmdlet -Name 'HID*' -Enable $false -Programmable $devices

        Disarms every matching device, asking the public caller's ShouldProcess first.
    .NOTES
        ShouldProcess runs on the public caller's $PSCmdlet (passed as -Cmdlet), so
        -WhatIf and -Confirm come from Enable- or Disable-PowerDeviceWake. This private
        function does not declare SupportsShouldProcess itself.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'ShouldProcess is called on the public caller passed in -Cmdlet.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '',
        Justification = 'ShouldProcess is called on the public caller passed in -Cmdlet.')]
    [CmdletBinding()]
    [OutputType([PsPowerCfg.PowerDevice])]
    param(
        # The public caller's $PSCmdlet. Supplies ShouldProcess and error attribution.
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCmdlet]$Cmdlet,

        # Device name. Exact match first, then wildcard match.
        [Parameter(Mandatory = $true)]
        [string]$Name,

        # $true to arm the device for wake, $false to disarm it.
        [Parameter(Mandatory = $true)]
        [bool]$Enable,

        # The wake-programmable device list, read once by the caller.
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [PsPowerCfg.PowerDevice[]]$Programmable,

        # Output the device after the change.
        [switch]$PassThru
    )

    # Exact name first: device names often contain [ ], which are wildcard
    # characters, so "Name [1]" would not match itself as a pattern.
    $targets = @($Programmable | Where-Object -FilterScript { $_.Name -eq $Name })
    $isPattern = [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Name)
    if (-not $targets.Count -and $isPattern) {
        $ignoreCase = [System.Management.Automation.WildcardOptions]::IgnoreCase
        $pattern = [System.Management.Automation.WildcardPattern]::new($Name, $ignoreCase)
        $targets = @($Programmable | Where-Object -FilterScript { $pattern.IsMatch($_.Name) })
    }
    if (-not $targets.Count) {
        $exception = [System.Management.Automation.ItemNotFoundException]::new(
            "No wake-programmable device matches '$Name'. Get-PowerDevice -Query WakeProgrammable lists them.")
        $Cmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                $exception,
                'PowerDeviceNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $Name))
        return
    }

    $action = if ($Enable) { 'Allow device to wake the system' } else { 'Stop device from waking the system' }
    foreach ($d in $targets) {
        if ($d.WakeArmed -eq $Enable) {
            Write-Verbose -Message "$($d.Name): already $(if ($Enable) { 'armed' } else { 'disarmed' })"
            if ($PassThru) { $d }
            continue
        }
        if (-not $Cmdlet.ShouldProcess($d.Name, $action)) { continue }
        $r = [PsPowerCfg.Safe]::SetDeviceWake($d.Name, $Enable)
        if ($r.Failed) {
            $record = New-NativeErrorRecord -Result $r -ErrorId 'SetPowerDeviceWakeFailed' -TargetObject $d.Name
            $Cmdlet.WriteError($record)
            continue
        }
        if ($PassThru) { $r.Value }
    }
}
