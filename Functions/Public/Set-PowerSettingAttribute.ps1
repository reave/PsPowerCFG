function Set-PowerSettingAttribute {
    <#
    .SYNOPSIS
    Shows or hides a power setting in Control Panel and powercfg /q. Equivalent to powercfg /attributes.
    .DESCRIPTION
    Reads the attributes with PowerReadSettingAttributes and sets or clears
    ATTRIBUTE_HIDE (0x1) with PowerWriteSettingAttributes. Other attribute bits
    are preserved. Requires an elevated session. Read the current state from
    Get-PowerSetting -IncludeHidden (IsHidden, Attributes).
    .PARAMETER Subgroup
    Subgroup GUID or alias. Found automatically when omitted.
    .PARAMETER Setting
    Setting GUID or alias.
    .PARAMETER Hidden
    $true hides the setting (+ATTRIB_HIDE), $false shows it (-ATTRIB_HIDE).
    .EXAMPLE
    Set-PowerSettingAttribute -Setting PERFBOOSTMODE -Hidden $false

    Unhides "Processor performance boost mode" in Control Panel.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('SubgroupGuid')]
        [string]$Subgroup,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('Guid', 'SettingGuid')]
        [string]$Setting,

        [Parameter(Mandatory = $true)]
        [bool]$Hidden
    )

    begin {
        Assert-IsAdmin -Cmdlet $PSCmdlet
    }

    process {
        $setGuid = Resolve-PowerGuid -Cmdlet $PSCmdlet -Value $Setting -Kind Setting
        $subGuid = if ($Subgroup) { Resolve-PowerGuid -Cmdlet $PSCmdlet -Value $Subgroup -Kind Subgroup } else { [PsPowerCfg.PowerApi]::FindSubgroup([PsPowerCfg.PowerApi]::GetActiveScheme(), $setGuid) }
        if ($null -eq $subGuid) {
            $exception = [System.Management.Automation.ItemNotFoundException]::new("Setting $Setting was not found; pass -Subgroup.")
            $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                    $exception, 'PowerSettingNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $Setting))
            return
        }
        $subGuid = [guid]$subGuid

        $attrs = [PsPowerCfg.PowerApi]::ReadSettingAttributes($subGuid, $setGuid)
        $new = if ($Hidden) { $attrs -bor 1 } else { $attrs - ($attrs -band 1) }
        if ($new -eq $attrs) { return }
        $verb = if ($Hidden) { 'Hide' } else { 'Show' }
        if (-not $PSCmdlet.ShouldProcess("$setGuid", "$verb power setting")) { return }
        try {
            [PsPowerCfg.PowerApi]::WriteSettingAttributes($subGuid, $setGuid, [uint32]$new)
        }
        catch {
            $PSCmdlet.WriteError((New-NativeErrorRecord -ErrorRecord $_ -ErrorId 'SetPowerSettingAttributeFailed' -TargetObject $setGuid))
        }
    }
}
