function Read-PowerRegistry {
    <#
    .SYNOPSIS
    Reads named values under an HKLM key into a hashtable; missing values and
    a missing key come back as $null. Uses Microsoft.Win32.Registry directly.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string[]]$Name
    )

    $values = @{}
    foreach ($n in $Name) { $values[$n] = $null }
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($Path, $false)
    if ($null -eq $key) { return $values }
    try {
        foreach ($n in $Name) { $values[$n] = $key.GetValue($n, $null) }
    }
    finally {
        $key.Dispose()
    }
    $values
}
