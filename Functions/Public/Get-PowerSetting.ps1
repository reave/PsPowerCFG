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
    .PARAMETER Scheme
    Scheme GUID, alias or name. Default: the active scheme. Accepts Guid from
    Get-PowerScheme objects on the pipeline.
    .PARAMETER Subgroup
    Limit to one subgroup.
    .PARAMETER Setting
    Limit to one setting. The subgroup is found automatically when omitted.
    .PARAMETER Name
    Filter by setting name or alias. Wildcards are supported.
    .PARAMETER IncludeHidden
    Include settings with ATTRIBUTE_HIDE.
    .EXAMPLE
    Get-PowerSetting -Subgroup SUB_SLEEP
    .EXAMPLE
    Get-PowerSetting -Setting STANDBYIDLE | Select-Object Name, AcValue, DcValue, Units
    .EXAMPLE
    Get-PowerScheme | Get-PowerSetting -Name '*lid*'
    .EXAMPLE
    Get-PowerSetting -IncludeHidden | Where-Object AcPolicyManaged

    Settings that Group Policy currently overrides.
    .OUTPUTS
    PsPowerCfg.PowerSetting
    #>
    [CmdletBinding()]
    [OutputType([PsPowerCfg.PowerSetting])]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('SchemeGuid', 'Guid')]
        [string]$Scheme = 'SCHEME_CURRENT',

        [Parameter(Position = 1)]
        [string]$Subgroup,

        [Parameter(Position = 2)]
        [string]$Setting,

        [SupportsWildcards()]
        [string[]]$Name,

        [switch]$IncludeHidden
    )

    process {
        $schemeGuid = Resolve-PowerGuid -Cmdlet $PSCmdlet -Value $Scheme -Kind Scheme
        $subGuid = if ($Subgroup) { [Nullable[guid]](Resolve-PowerGuid -Cmdlet $PSCmdlet -Value $Subgroup -Kind Subgroup) } else { $null }
        $setGuid = if ($Setting) { [Nullable[guid]](Resolve-PowerGuid -Cmdlet $PSCmdlet -Value $Setting -Kind Setting) } else { $null }

        if ($null -ne $setGuid -and $null -eq $subGuid) {
            $subGuid = [PsPowerCfg.PowerApi]::FindSubgroup($schemeGuid, $setGuid.Value)
            if ($null -eq $subGuid) {
                $exception = [System.Management.Automation.ItemNotFoundException]::new("Setting $Setting was not found in scheme $schemeGuid.")
                $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                        $exception, 'PowerSettingNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $Setting))
                return
            }
        }

        try {
            $settings = [PsPowerCfg.PowerApi]::GetSettings($schemeGuid, $subGuid, $setGuid, $IncludeHidden.IsPresent)
        }
        catch {
            $PSCmdlet.WriteError((New-NativeErrorRecord -ErrorRecord $_ -ErrorId 'GetPowerSettingFailed' -TargetObject $schemeGuid))
            return
        }

        if (-not $Name) { return $settings }
        $patterns = foreach ($n in $Name) {
            [System.Management.Automation.WildcardPattern]::new($n, [System.Management.Automation.WildcardOptions]::IgnoreCase)
        }
        foreach ($s in $settings) {
            foreach ($p in $patterns) {
                if ($p.IsMatch($s.Name) -or ($s.Alias -and $p.IsMatch($s.Alias))) { $s; break }
            }
        }
    }
}
