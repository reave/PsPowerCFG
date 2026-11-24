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

        Shows whether hibernate and fast startup are on, and the hiberfile type, size and path.
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

    $powerKey = 'SYSTEM\CurrentControlSet\Control\Power'
    $power = Read-PowerRegistry -Path $powerKey -Name 'HibernateEnabled', 'HiberFileSizePercent', 'HiberFileType'
    $sessionKey = 'SYSTEM\CurrentControlSet\Control\Session Manager\Power'
    $session = Read-PowerRegistry -Path $sessionKey -Name 'HiberbootEnabled'

    $systemDrive = [System.Environment]::GetEnvironmentVariable('SystemDrive') + '\'
    $file = [System.IO.Path]::Combine($systemDrive, 'hiberfil.sys')
    $enabled = $caps.HiberFilePresent
    if ($null -ne $power['HibernateEnabled']) { $enabled = [int]$power['HibernateEnabled'] -ne 0 }
    $fastStartup = $null
    if ($null -ne $session['HiberbootEnabled']) { $fastStartup = [int]$session['HiberbootEnabled'] -ne 0 }

    [pscustomobject]@{
        PSTypeName           = 'PsPowerCfg.PowerHibernate'
        Enabled              = $enabled
        Available            = $caps.HibernateSupported
        HiberFilePresent     = $caps.HiberFilePresent
        HiberFileType        = $caps.HiberFileType
        HiberFileSizePercent = $power['HiberFileSizePercent']
        HiberFilePath        = $file
        HiberFileSize        = [PsPowerCfg.PowerInfo]::FileLength($file)
        HybridSleepAvailable = $caps.HybridSleep
        FastStartupAvailable = $caps.FastStartup
        FastStartupEnabled   = $fastStartup
    }
}
