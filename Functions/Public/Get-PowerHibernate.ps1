function Get-PowerHibernate {
    <#
    .SYNOPSIS
    Reports whether hibernate is on, the hiberfile type and size, and fast startup.
    .DESCRIPTION
    Combines CallNtPowerInformation(SystemPowerCapabilities) with the
    registry values powercfg /hibernate writes under
    HKLM\SYSTEM\CurrentControlSet\Control\Power (HibernateEnabled,
    HiberFileSizePercent, HiberFileType) and the fast startup switch
    (HiberbootEnabled under ...\Session Manager\Power). The size of
    hiberfil.sys is read from its directory entry; the file itself is locked.
    .EXAMPLE
    Get-PowerHibernate
    .OUTPUTS
    PsPowerCfg.PowerHibernate
    #>
    [CmdletBinding()]
    [OutputType('PsPowerCfg.PowerHibernate')]
    param()

    $r = [PsPowerCfg.Safe]::GetCapabilities()
    if ($r.Failed) {
        $PSCmdlet.WriteError((New-NativeErrorRecord -Result $r -ErrorId 'GetPowerHibernateFailed'))
        return
    }
    $caps = $r.Value

    $power = Read-PowerRegistry -Path 'SYSTEM\CurrentControlSet\Control\Power' -Name 'HibernateEnabled', 'HiberFileSizePercent', 'HiberFileType'
    $session = Read-PowerRegistry -Path 'SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled'

    $file = [System.IO.Path]::Combine([System.Environment]::GetEnvironmentVariable('SystemDrive') + '\', 'hiberfil.sys')
    $enabled = if ($null -ne $power['HibernateEnabled']) { [int]$power['HibernateEnabled'] -ne 0 } else { $caps.HiberFilePresent }
    $fastStartup = if ($null -ne $session['HiberbootEnabled']) { [int]$session['HiberbootEnabled'] -ne 0 } else { $null }

    [pscustomobject]@{
        PSTypeName            = 'PsPowerCfg.PowerHibernate'
        Enabled               = $enabled
        Available             = $caps.HibernateSupported
        HiberFilePresent      = $caps.HiberFilePresent
        HiberFileType         = $caps.HiberFileType
        HiberFileSizePercent  = $power['HiberFileSizePercent']
        HiberFilePath         = $file
        HiberFileSize         = [PsPowerCfg.PowerInfo]::FileLength($file)
        HybridSleepAvailable  = $caps.HybridSleep
        FastStartupAvailable  = $caps.FastStartup
        FastStartupEnabled    = $fastStartup
    }
}
