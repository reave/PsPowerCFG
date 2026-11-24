function Read-PowerRegistry {
    <#
    .SYNOPSIS
        Reads named values under an HKLM key into a hashtable; missing values and
        a missing key come back as $null. Uses Microsoft.Win32.Registry directly.
    .EXAMPLE
        Read-PowerRegistry -Path 'SYSTEM\CurrentControlSet\Control\Power' -Name 'HibernateEnabled'

        Returns @{ HibernateEnabled = <value> }, or $null as the value when the key or
        value is missing.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        # Key path under HKEY_LOCAL_MACHINE, without the hive.
        [Parameter(Mandatory = $true)]
        [string]$Path,

        # Value names to read. Each becomes a key in the returned hashtable.
        [Parameter(Mandatory = $true)]
        [string[]]$Name
    )

    $values = @{}
    foreach ($n in $Name) { $values[$n] = $null }
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($Path, $false)
    if ($null -eq $key) {
        $values
        return
    }
    try {
        foreach ($n in $Name) { $values[$n] = $key.GetValue($n, $null) }
    } finally {
        $key.Dispose()
    }
    $values
}
