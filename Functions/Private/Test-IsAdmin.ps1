function Test-IsAdmin {
    <#
    .SYNOPSIS
    Returns $true when the current process token is elevated (member of BUILTIN\Administrators).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    try {
        ([System.Security.Principal.WindowsPrincipal]$identity).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    finally {
        $identity.Dispose()
    }
}
