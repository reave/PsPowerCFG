function Get-PowerRequestOverride {
    <#
    .SYNOPSIS
        Lists power request overrides. Equivalent to powercfg /requestsoverride with no arguments.
    .DESCRIPTION
        An override makes Windows ignore the listed request types (Display,
        System, AwayMode, Execution) from a process, service or driver.

        Read straight from HKLM\SYSTEM\CurrentControlSet\Control\Power\
        PowerRequestOverride\<Process|Service|Driver>, where powercfg stores each
        caller as a DWORD bitmask: Display = 1, System = 2, AwayMode = 4,
        Execution = 8 (verified against powercfg on Windows 11 26100). Does not
        need elevation.
    .EXAMPLE
        Get-PowerRequestOverride

        Lists every override, with the request types Windows ignores for each caller.
    .OUTPUTS
        PsPowerCfg.PowerRequestOverride
    #>
    [CmdletBinding()]
    [OutputType('PsPowerCfg.PowerRequestOverride')]
    param(
        # Only return overrides for these caller types.
        [ValidateSet('Process', 'Service', 'Driver')]
        [string[]]$CallerType = @('Service', 'Process', 'Driver'),

        # Filter by caller name. Wildcards are supported.
        [SupportsWildcards()]
        [string]$Name = '*'
    )

    $ignoreCase = [System.Management.Automation.WildcardOptions]::IgnoreCase
    $pattern = [System.Management.Automation.WildcardPattern]::new($Name, $ignoreCase)
    foreach ($kind in $CallerType) {
        $keyPath = "$script:PowerRequestOverrideKey\$kind"
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($keyPath, $false)
        if ($null -eq $key) { continue }
        try {
            foreach ($n in $key.GetValueNames()) {
                if (-not ($n -eq $Name -or $pattern.IsMatch($n))) { continue }
                $mask = [int]$key.GetValue($n, 0)
                $types = foreach ($t in $script:PowerRequestTypeBits.GetEnumerator()) {
                    if ($mask -band $t.Value) { $t.Key }
                }
                [pscustomobject]@{
                    PSTypeName = 'PsPowerCfg.PowerRequestOverride'
                    CallerType = $kind
                    Name       = $n
                    Request    = [string[]]@($types)
                    Mask       = $mask
                }
            }
        } finally {
            $key.Dispose()
        }
    }
}
