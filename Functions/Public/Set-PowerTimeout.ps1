function Set-PowerTimeout {
    <#
    .SYNOPSIS
        Sets monitor, disk, sleep or hibernate timeouts in minutes. Equivalent to
        powercfg /change.
    .DESCRIPTION
        Thin wrapper over Set-PowerSetting for the four /change settings:
          Monitor   = SUB_VIDEO\VIDEOIDLE      (monitor-timeout-ac/dc)
          Disk      = SUB_DISK\DISKIDLE        (disk-timeout-ac/dc)
          Standby   = SUB_SLEEP\STANDBYIDLE    (standby-timeout-ac/dc)
          Hibernate = SUB_SLEEP\HIBERNATEIDLE  (hibernate-timeout-ac/dc)
        0 means never.
    .EXAMPLE
        Set-PowerTimeout -Type Monitor -AcMinutes 5

        Same as powercfg /change monitor-timeout-ac 5.
    .EXAMPLE
        Set-PowerTimeout -Type Standby -AcMinutes 0 -DcMinutes 15

        Never sleeps on AC; sleeps after 15 minutes on battery.
    .NOTES
        -WhatIf and -Confirm are forwarded to Set-PowerSetting, which makes the
        ShouldProcess call.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '',
        Justification = 'WhatIf/Confirm are forwarded to Set-PowerSetting, which calls ShouldProcess.')]
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PsPowerCfg.PowerSetting])]
    param(
        # Monitor, Disk, Standby or Hibernate.
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet('Monitor', 'Disk', 'Standby', 'Hibernate')]
        [string]$Type,

        # Timeout on AC power, in minutes.
        [ValidateRange(0, 71582788)]
        [uint32]$AcMinutes,

        # Timeout on battery, in minutes.
        [ValidateRange(0, 71582788)]
        [uint32]$DcMinutes,

        # Scheme GUID, alias or name. Default: the active scheme (powercfg /change
        # only ever targets the active scheme).
        [string]$Scheme = 'SCHEME_CURRENT',

        # Return the updated setting.
        [switch]$PassThru
    )

    $map = @{
        Monitor   = @('SUB_VIDEO', 'VIDEOIDLE')
        Disk      = @('SUB_DISK', 'DISKIDLE')
        Standby   = @('SUB_SLEEP', 'STANDBYIDLE')
        Hibernate = @('SUB_SLEEP', 'HIBERNATEIDLE')
    }
    $params = @{
        Scheme   = $Scheme
        Subgroup = $map[$Type][0]
        Setting  = $map[$Type][1]
        PassThru = $PassThru
    }
    if ($PSBoundParameters.ContainsKey('AcMinutes')) { $params.AcValue = [uint32]($AcMinutes * 60) }
    if ($PSBoundParameters.ContainsKey('DcMinutes')) { $params.DcValue = [uint32]($DcMinutes * 60) }
    if ($PSBoundParameters.ContainsKey('WhatIf')) { $params.WhatIf = $PSBoundParameters['WhatIf'] }
    if ($PSBoundParameters.ContainsKey('Confirm')) { $params.Confirm = $PSBoundParameters['Confirm'] }
    Set-PowerSetting @params
}
