function Set-PowerSetting {
    <#
    .SYNOPSIS
    Sets a power setting's AC and/or DC value. Equivalent to powercfg /setacvalueindex and /setdcvalueindex.
    .DESCRIPTION
    Calls PowerWriteACValueIndex / PowerWriteDCValueIndex. When the scheme is
    the active one, PowerSetActiveScheme is called afterwards so the change
    takes effect immediately (powercfg does the same).

    Values are validated against the setting's range (Minimum..Maximum) or its
    list of possible values. -Force skips that check.

    Warns when Group Policy overrides the setting, because the written value
    will not take effect while the policy applies.
    .PARAMETER Scheme
    Scheme GUID, alias or name. Default: the active scheme.
    .PARAMETER Subgroup
    Subgroup GUID or alias. Found automatically when omitted.
    .PARAMETER Setting
    Setting GUID or alias.
    .PARAMETER AcValue
    Value (range settings) or possible-value index (index settings) on AC power.
    .PARAMETER DcValue
    Same, on battery.
    .PARAMETER Force
    Skip range/possible-value validation.
    .PARAMETER PassThru
    Return the updated setting.
    .EXAMPLE
    Set-PowerSetting -Setting LIDACTION -AcValue 0 -DcValue 1

    Lid close: do nothing on AC, sleep on battery.
    .EXAMPLE
    Get-PowerSetting -Setting PROCTHROTTLEMAX | Set-PowerSetting -DcValue 80
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PsPowerCfg.PowerSetting])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('SchemeGuid')]
        [string]$Scheme = 'SCHEME_CURRENT',

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('SubgroupGuid')]
        [string]$Subgroup,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('Guid', 'SettingGuid')]
        [string]$Setting,

        [uint32]$AcValue,

        [uint32]$DcValue,

        [switch]$Force,

        [switch]$PassThru
    )

    process {
        $setAc = $PSBoundParameters.ContainsKey('AcValue')
        $setDc = $PSBoundParameters.ContainsKey('DcValue')
        if (-not ($setAc -or $setDc)) {
            $exception = [System.ArgumentException]::new('Specify -AcValue, -DcValue or both.')
            $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                    $exception, 'NoValueSpecified', [System.Management.Automation.ErrorCategory]::InvalidArgument, $null))
        }

        $schemeGuid = Resolve-PowerGuid -Cmdlet $PSCmdlet -Value $Scheme -Kind Scheme
        $setGuid = Resolve-PowerGuid -Cmdlet $PSCmdlet -Value $Setting -Kind Setting
        $subGuid = if ($Subgroup) { Resolve-PowerGuid -Cmdlet $PSCmdlet -Value $Subgroup -Kind Subgroup } else { [PsPowerCfg.PowerApi]::FindSubgroup($schemeGuid, $setGuid) }
        if ($null -eq $subGuid) {
            $exception = [System.Management.Automation.ItemNotFoundException]::new("Setting $Setting was not found in scheme $schemeGuid; pass -Subgroup.")
            $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                    $exception, 'PowerSettingNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $Setting))
            return
        }
        $subGuid = [guid]$subGuid

        $r = [PsPowerCfg.Safe]::GetSetting($schemeGuid, $subGuid, $setGuid)
        if ($r.Failed) {
            $PSCmdlet.WriteError((New-NativeErrorRecord -Result $r -ErrorId 'PowerSettingNotFound' -TargetObject $Setting))
            return
        }
        $current = $r.Value

        if (-not $Force) {
            foreach ($pair in @(@{ On = $setAc; Value = $AcValue; Label = 'AcValue' }, @{ On = $setDc; Value = $DcValue; Label = 'DcValue' })) {
                if (-not $pair.On) { continue }
                $v = $pair.Value
                $bad = $null
                if ($current.IsRange) {
                    if (($null -ne $current.Minimum -and $v -lt $current.Minimum) -or ($null -ne $current.Maximum -and $v -gt $current.Maximum)) {
                        $bad = "must be between $($current.Minimum) and $($current.Maximum) $($current.Units)"
                    }
                }
                elseif ($current.PossibleValues.Count -and $v -ge $current.PossibleValues.Count) {
                    $bad = 'must be one of: ' + (($current.PossibleValues | ForEach-Object { "$($_.Index) ($($_.Name))" }) -join ', ')
                }
                if ($bad) {
                    $exception = [System.ArgumentOutOfRangeException]::new($pair.Label, $v, "$($pair.Label) $v for '$($current.Name)' $bad. Use -Force to write it anyway.")
                    $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                            $exception, 'PowerSettingValueOutOfRange', [System.Management.Automation.ErrorCategory]::InvalidArgument, $v))
                }
            }
        }

        if (($setAc -and $current.AcPolicyManaged) -or ($setDc -and $current.DcPolicyManaged)) {
            Write-Warning "'$($current.Name)' is managed by Group Policy; the value is written but will not take effect while the policy applies."
        }

        $what = @()
        if ($setAc) { $what += "AC=$AcValue" }
        if ($setDc) { $what += "DC=$DcValue" }
        if (-not $PSCmdlet.ShouldProcess("$($current.Name) ($setGuid) in scheme $schemeGuid", "Set $($what -join ', ')")) { return }

        $acv = if ($setAc) { [uint32]$AcValue } else { [uint32]0 }
        $dcv = if ($setDc) { [uint32]$DcValue } else { [uint32]0 }
        $r = [PsPowerCfg.Safe]::WriteSettingValues($schemeGuid, $subGuid, $setGuid, $setAc, $acv, $setDc, $dcv)
        if ($r.Failed) {
            $PSCmdlet.WriteError((New-NativeErrorRecord -Result $r -ErrorId 'SetPowerSettingFailed' -TargetObject $Setting))
            return
        }
        if ($PassThru) { $r.Value }
    }
}
