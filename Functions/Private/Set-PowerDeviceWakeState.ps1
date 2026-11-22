function Set-PowerDeviceWakeState {
    <#
    .SYNOPSIS
    Shared body of Enable-/Disable-PowerDeviceWake: resolves -Name against the
    wake-programmable devices, confirms, and calls the native setter.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCmdlet]$Cmdlet,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [bool]$Enable,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [PsPowerCfg.PowerDevice[]]$Programmable,

        [switch]$PassThru
    )

    # Exact name first: device names often contain [ ], which are wildcard
    # characters, so "Name [1]" would not match itself as a pattern.
    $targets = @($Programmable | Where-Object { $_.Name -eq $Name })
    if (-not $targets.Count -and [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Name)) {
        $pattern = [System.Management.Automation.WildcardPattern]::new($Name, [System.Management.Automation.WildcardOptions]::IgnoreCase)
        $targets = @($Programmable | Where-Object { $pattern.IsMatch($_.Name) })
    }
    if (-not $targets.Count) {
        $exception = [System.Management.Automation.ItemNotFoundException]::new(
            "No wake-programmable device matches '$Name'. Get-PowerDevice -Query WakeProgrammable lists them.")
        $Cmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                $exception, 'PowerDeviceNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $Name))
        return
    }

    $action = if ($Enable) { 'Allow device to wake the system' } else { 'Stop device from waking the system' }
    foreach ($d in $targets) {
        if ($d.WakeArmed -eq $Enable) {
            Write-Verbose "$($d.Name): already $(if ($Enable) { 'armed' } else { 'disarmed' })"
            if ($PassThru) { $d }
            continue
        }
        if (-not $Cmdlet.ShouldProcess($d.Name, $action)) { continue }
        $r = [PsPowerCfg.Safe]::SetDeviceWake($d.Name, $Enable)
        if ($r.Failed) {
            $Cmdlet.WriteError((New-NativeErrorRecord -Result $r -ErrorId 'SetPowerDeviceWakeFailed' -TargetObject $d.Name))
            continue
        }
        if ($PassThru) { $r.Value }
    }
}
