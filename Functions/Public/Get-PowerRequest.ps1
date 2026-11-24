function Get-PowerRequest {
    <#
    .SYNOPSIS
        Lists the application and driver power requests keeping the display or system awake. Equivalent to powercfg /requests.
    .DESCRIPTION
        Windows has no public API for enumerating other processes' power
        requests, so this runs powercfg /requests and parses it. The request-type
        headers (DISPLAY:, SYSTEM:, ...) and the [PROCESS]/[SERVICE]/[DRIVER]
        tags are not translated, so parsing works in any display language; the
        reason text is whatever the caller supplied. Process paths are converted
        from \Device\HarddiskVolumeN form to drive letters in Path; Name keeps
        powercfg's text. Requires an elevated session.
    .PARAMETER Type
        Only return requests of these types.
    .EXAMPLE
        Get-PowerRequest
    .EXAMPLE
        Get-PowerRequest -Type Display, System | Format-Table Type, CallerType, Path, Reason
    .OUTPUTS
        PsPowerCfg.PowerRequest
    #>
    [CmdletBinding()]
    [OutputType('PsPowerCfg.PowerRequest')]
    param(
        [ValidateSet('Display', 'System', 'AwayMode', 'Execution', 'PerfBoost', 'ActiveLockScreen')]
        [string[]]$Type
    )

    Assert-IsAdmin -Cmdlet $PSCmdlet
    $stdout = Invoke-PowerCfg -Cmdlet $PSCmdlet -ArgumentList '/requests'

    $names = @{
        DISPLAY = 'Display'; SYSTEM = 'System'; AWAYMODE = 'AwayMode'; EXECUTION = 'Execution'
        PERFBOOST = 'PerfBoost'; ACTIVELOCKSCREEN = 'ActiveLockScreen'
    }
    $section = $null
    $current = $null
    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($line in ($stdout -split '\r?\n')) {
        if ($line -match '^([A-Z]+):\s*$') {
            $section = if ($names.ContainsKey($Matches[1])) { $names[$Matches[1]] } else { $Matches[1] }
            $current = $null
            continue
        }
        if ($line -match '^\[(PROCESS|SERVICE|DRIVER)\] (.+?)\s*$') {
            $kind = $Matches[1]
            $name = $Matches[2]
            $current = [pscustomobject]@{
                PSTypeName = 'PsPowerCfg.PowerRequest'
                Type       = $section
                CallerType = @{ PROCESS = 'Process'; SERVICE = 'Service'; DRIVER = 'Driver' }[$kind]
                Name       = $name
                Path       = if ($kind -eq 'PROCESS') { [PsPowerCfg.DevicePath]::ToDosPath($name) } else { $null }
                Reason     = $null
            }
            $results.Add($current)
            continue
        }
        # Any other non-empty line under an entry is its reason ("None." and
        # its translations appear only directly under a header).
        if ($current -and $line.Trim()) {
            $current.Reason = if ($current.Reason) { $current.Reason + "`n" + $line.Trim() } else { $line.Trim() }
        }
    }
    foreach ($r in $results) {
        if (-not $Type -or $Type -contains $r.Type) { $r }
    }
}
