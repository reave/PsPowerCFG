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
    .EXAMPLE
        $target = Resolve-OutputPath -Cmdlet $PSCmdlet -Path 'reports\sleep' -Extension '.html'

        Returns the full path of reports\sleep.html under the current PowerShell
        location and creates the reports folder if it is missing.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The caller's $PSCmdlet, used for its provider path resolver.
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCmdlet]$Cmdlet,

        # Output path as the user typed it. Relative paths resolve against $PWD.
        [Parameter(Mandatory = $true)]
        [string]$Path,

        # Extension to force, with the dot (for example '.html'). Omit to keep the path's own.
        [string]$Extension
    )

    $full = $Cmdlet.GetUnresolvedProviderPathFromPSPath($Path)
    $currentExtension = [System.IO.Path]::GetExtension($full)
    $ignoreCase = [System.StringComparison]::OrdinalIgnoreCase
    if ($Extension -and -not [string]::Equals($currentExtension, $Extension, $ignoreCase)) {
        Write-Verbose -Message "Changing output extension to $Extension"
        $full = [System.IO.Path]::ChangeExtension($full, $Extension)
    }

    $dir = [System.IO.Path]::GetDirectoryName($full)
    if ($dir -and -not [System.IO.Directory]::Exists($dir)) {
        [void][System.IO.Directory]::CreateDirectory($dir)
    }
    $full
}
