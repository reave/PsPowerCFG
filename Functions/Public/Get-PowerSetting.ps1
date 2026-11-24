function Get-PowerSetting {
    <#
    .SYNOPSIS
        Gets power settings and their AC/DC values. Equivalent to powercfg /query and /qh.
    .DESCRIPTION
        Reads settings directly from powrprof.dll: PowerEnumerate for subgroups and
        settings, PowerReadACValueIndex/PowerReadDCValueIndex for values,
        PowerReadValueMin/Max/Increment/UnitsSpecifier for range settings,
        PowerReadPossibleFriendlyName for index settings, PowerReadSettingAttributes
        for visibility and PowerSettingAccessCheck for Group Policy overrides.

        -Scheme, -Subgroup and -Setting take a GUID or a powercfg alias
        (SCHEME_CURRENT, SUB_SLEEP, STANDBYIDLE, ...). -Scheme also takes a scheme
        name. Hidden settings are skipped unless -IncludeHidden (like /qh).
    .EXAMPLE
        Get-PowerSetting -Subgroup SUB_SLEEP

        Lists the visible sleep settings of the active scheme with their AC and DC values.
    .EXAMPLE
        Get-PowerSetting -Setting STANDBYIDLE | Select-Object -Property Name, AcValue, DcValue, Units

        Shows the sleep-after timeout of the active scheme, in seconds.
    .EXAMPLE
        Get-PowerScheme | Get-PowerSetting -Name '*lid*'

        Shows the lid settings of every scheme.
    .EXAMPLE
        Get-PowerSetting -IncludeHidden | Where-Object -Property AcPolicyManaged

        Settings that Group Policy currently overrides.
    .OUTPUTS
        PsPowerCfg.PowerSetting
    #>
    [CmdletBinding()]
    [OutputType([PsPowerCfg.PowerSetting])]
    param(
        # Scheme GUID, alias or name. Default: the active scheme. Accepts Guid from
        # Get-PowerScheme objects on the pipeline.
        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('SchemeGuid', 'Guid')]
        [string]$Scheme = 'SCHEME_CURRENT',

        # Limit to one subgroup.
        [Parameter(Position = 1)]
        [string]$Subgroup,

        # Limit to one setting. The subgroup is found automatically when omitted.
        [Parameter(Position = 2)]
        [string]$Setting,

        # Filter by setting name or alias. Wildcards are supported.
        [SupportsWildcards()]
        [string[]]$Name,

        # Include settings with ATTRIBUTE_HIDE.
        [switch]$IncludeHidden
    )

    process {
        $schemeGuid = Resolve-PowerGuid -Cmdlet $PSCmdlet -Value $Scheme -Kind Scheme
        $subGuid = $null
        if ($Subgroup) {
            $subGuid = [Nullable[guid]](Resolve-PowerGuid -Cmdlet $PSCmdlet -Value $Subgroup -Kind Subgroup)
        }
        $setGuid = $null
        if ($Setting) {
            $setGuid = [Nullable[guid]](Resolve-PowerGuid -Cmdlet $PSCmdlet -Value $Setting -Kind Setting)
        }

        if ($null -ne $setGuid -and $null -eq $subGuid) {
            $subGuid = [PsPowerCfg.PowerApi]::FindSubgroup($schemeGuid, [guid]$setGuid)
            if ($null -eq $subGuid) {
                $exception = [System.Management.Automation.ItemNotFoundException]::new(
                    "Setting $Setting was not found in scheme $schemeGuid.")
                $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                        $exception,
                        'PowerSettingNotFound',
                        [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                        $Setting))
                return
            }
        }

        $r = [PsPowerCfg.Safe]::GetSettings($schemeGuid, $subGuid, $setGuid, $IncludeHidden.IsPresent)
        if ($r.Failed) {
            $record = New-NativeErrorRecord -Result $r -ErrorId 'GetPowerSettingFailed' -TargetObject $schemeGuid
            $PSCmdlet.WriteError($record)
            return
        }
        $settings = $r.Value

        if (-not $Name) {
            $settings
            return
        }
        $ignoreCase = [System.Management.Automation.WildcardOptions]::IgnoreCase
        $patterns = foreach ($n in $Name) {
            [System.Management.Automation.WildcardPattern]::new($n, $ignoreCase)
        }
        foreach ($s in $settings) {
            foreach ($p in $patterns) {
                if ($p.IsMatch($s.Name) -or ($s.Alias -and $p.IsMatch($s.Alias))) { $s; break }
            }
        }
    }
}
