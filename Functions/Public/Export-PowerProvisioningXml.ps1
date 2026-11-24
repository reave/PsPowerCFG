function Export-PowerProvisioningXml {
    <#
    .SYNOPSIS
        Writes a Windows Configuration Designer provisioning XML of customized power settings. Equivalent to powercfg /pxml.
    .DESCRIPTION
        The XML holds every setting on this device with the RUNTIME_OVERRIDE
        altitude, for building a provisioning package (.ppkg) in Windows
        Configuration Designer.

        There is no public Win32 API for this, so this calls powercfg.exe, with
        output captured in memory and the exit code checked. Requires an
        elevated session.
    .PARAMETER OutFile
        XML path. Relative paths resolve against the current PowerShell location.
        Default: .\power-provisioning.xml.
    .PARAMETER Version
        The package Version field. powercfg's default is 1.0.
    .PARAMETER Name
        The package Name field. powercfg's default is CustomOEM.Power.Settings.Control.
    .PARAMETER Id
        The package ID field. powercfg generates a new GUID by default.
    .PARAMETER Owner
        The OwnerType field. powercfg's default is OEM.
    .EXAMPLE
        Export-PowerProvisioningXml -OutFile C:\Temp\power.xml -Name Contoso.Power -Version 1.1
    .OUTPUTS
        System.IO.FileInfo
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Position = 0)]
        [string]$OutFile = 'power-provisioning.xml',

        [ValidatePattern('^\d+(\.\d+){1,3}$')]
        [string]$Version,

        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [guid]$Id,

        [ValidateNotNullOrEmpty()]
        [string]$Owner
    )

    Assert-IsAdmin -Cmdlet $PSCmdlet
    $target = Resolve-OutputPath -Cmdlet $PSCmdlet -Path $OutFile -Extension '.xml'
    $arguments = @('/pxml', '/output', $target)
    if ($Version) { $arguments += @('/version', $Version) }
    if ($Name) { $arguments += @('/name', $Name) }
    if ($PSBoundParameters.ContainsKey('Id')) { $arguments += @('/id', $Id.ToString()) }
    if ($Owner) { $arguments += @('/owner', $Owner) }

    $stdout = Invoke-PowerCfg -Cmdlet $PSCmdlet -ArgumentList $arguments -WorkingDirectory ([System.IO.Path]::GetDirectoryName($target))
    if (-not [System.IO.File]::Exists($target)) {
        $detail = if ($stdout -and $stdout.Trim()) { ' powercfg said: ' + $stdout.Trim() } else { '' }
        $exception = [System.IO.FileNotFoundException]::new("powercfg /pxml exited 0 but did not create $target.$detail", $target)
        $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                $exception, 'ReportNotCreated', [System.Management.Automation.ErrorCategory]::InvalidResult, $target))
    }
    [System.IO.FileInfo]::new($target)
}
