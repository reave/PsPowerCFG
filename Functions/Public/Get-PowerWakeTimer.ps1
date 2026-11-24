function Get-PowerWakeTimer {
    <#
    .SYNOPSIS
        Lists active timers that can wake the system from sleep. Equivalent to
        powercfg /waketimers.
    .DESCRIPTION
        Windows has no public API for enumerating other processes' wake timers,
        so this runs powercfg /waketimers and parses it. Owner type, owner and
        expiry are parsed from English output ("Timer set by [PROCESS] ... expires
        at ... on ..."). In other display languages each timer comes back with
        only Text filled in. Process paths are converted to drive-letter form in
        Path. Requires an elevated session.
    .EXAMPLE
        Get-PowerWakeTimer

        Lists each wake timer with its owner, expiry time and reason.
    .OUTPUTS
        PsPowerCfg.PowerWakeTimer
    #>
    [CmdletBinding()]
    [OutputType('PsPowerCfg.PowerWakeTimer')]
    param()

    Assert-IsAdmin -Cmdlet $PSCmdlet
    $stdout = Invoke-PowerCfg -Cmdlet $PSCmdlet -ArgumentList '/waketimers'

    $culture = [System.Globalization.CultureInfo]::CurrentCulture
    $assumeLocal = [System.Globalization.DateTimeStyles]::AssumeLocal
    $current = $null
    foreach ($line in ($stdout -split '\r?\n')) {
        if (-not $line.Trim()) { continue }
        if ($line -match '^Timer set by \[(\w+)\] (.+) expires at (.+) on (.+?)\.\s*$') {
            if ($current) { $current }
            $kind = $Matches[1]
            $owner = $Matches[2]
            $expires = $null
            $dt = [datetime]::MinValue
            if ([datetime]::TryParse("$($Matches[4]) $($Matches[3])", $culture, $assumeLocal, [ref]$dt)) {
                $expires = $dt
            }
            $current = [pscustomobject]@{
                PSTypeName = 'PsPowerCfg.PowerWakeTimer'
                OwnerType  = @{ PROCESS = 'Process'; SERVICE = 'Service'; DRIVER = 'Driver' }[$kind]
                Owner      = $owner
                Path       = if ($kind -eq 'PROCESS') { [PsPowerCfg.DevicePath]::ToDosPath($owner) } else { $null }
                Expires    = $expires
                Reason     = $null
                Text       = $line.Trim()
            }
            continue
        }
        if ($current) {
            # Indented detail lines (for example "Reason: ...") belong to the
            # timer above them.
            $detail = $line.Trim()
            $current.Text += "`n" + $detail
            if ($detail -match '^Reason:\s*(.*)$') { $current.Reason = $Matches[1] }
            continue
        }
        if ($line -match '^\s*\[' -or $line -match '\d') {
            # Not English: one object per unrecognized line that names an owner.
            [pscustomobject]@{
                PSTypeName = 'PsPowerCfg.PowerWakeTimer'
                OwnerType  = $null
                Owner      = $null
                Path       = $null
                Expires    = $null
                Reason     = $null
                Text       = $line.Trim()
            }
        }
    }
    if ($current) { $current }
}
