function Resolve-OutputPath {
    <#
    .SYNOPSIS
    Resolves a user-supplied output path against the current PowerShell
    location (not the process working directory) and optionally forces an
    extension.
    .DESCRIPTION
    [System.IO.FileInfo] parameters resolve relative paths against
    [Environment]::CurrentDirectory, which is usually not $PWD. This uses the
    provider path resolver instead.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCmdlet]$Cmdlet,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [string]$Extension
    )

    $full = $Cmdlet.GetUnresolvedProviderPathFromPSPath($Path)
    if ($Extension -and -not [string]::Equals([System.IO.Path]::GetExtension($full), $Extension, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Verbose "Changing output extension to $Extension"
        $full = [System.IO.Path]::ChangeExtension($full, $Extension)
    }

    $dir = [System.IO.Path]::GetDirectoryName($full)
    if ($dir -and -not [System.IO.Directory]::Exists($dir)) {
        [void][System.IO.Directory]::CreateDirectory($dir)
    }
    $full
}
