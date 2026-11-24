function Test-IsAdmin {
    <#
    .SYNOPSIS
        Returns $true when the current process token is elevated (member of
        BUILTIN\Administrators).
    .EXAMPLE
        if (Test-IsAdmin) { 'elevated' }

        Outputs 'elevated' only in an Administrator session.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    try {
        $administrator = [System.Security.Principal.WindowsBuiltInRole]::Administrator
        ([System.Security.Principal.WindowsPrincipal]$identity).IsInRole($administrator)
    } finally {
        $identity.Dispose()
    }
}
