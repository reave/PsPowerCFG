Function Test-IsAdmin {
    <#
    .SYNOPSIS
    Test if current running user is an administrator
    .DESCRIPTION
    Test if current running user is an administrator
    .EXAMPLE
    If (Test-IsAdmin) {
        Write-Output "User is an Admin."
    }
    .NOTES
    #>
    [CmdletBinding()]
    Param()
    Process {
        ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    }
}