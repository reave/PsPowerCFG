function Remove-PowerSetting {
    <#
    .SYNOPSIS
        Deletes a power setting definition. Equivalent to powercfg /deletesetting.
    .DESCRIPTION
        Calls PowerRemovePowerSetting. This removes the setting from EVERY scheme
        and is meant for settings that drivers or OEM tools registered. Windows'
        own settings (anything Get-PowerAlias knows) are refused unless -Force.
        Requires an elevated session. Prompts for confirmation (ConfirmImpact High).
    .EXAMPLE
        Get-PowerSetting -IncludeHidden -Name 'Contoso*' | Remove-PowerSetting

        Removes, after a confirmation prompt for each, the settings an OEM tool named
        Contoso registered. SubgroupGuid and Guid bind from the pipeline objects.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        # Subgroup GUID or alias.
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('SubgroupGuid')]
        [string]$Subgroup,

        # Setting GUID or alias.
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [Alias('Guid', 'SettingGuid')]
        [string]$Setting,

        # Allow removing a built-in Windows setting.
        [switch]$Force
    )

    begin {
        Assert-IsAdmin -Cmdlet $PSCmdlet
    }

    process {
        $subGuid = Resolve-PowerGuid -Cmdlet $PSCmdlet -Value $Subgroup -Kind Subgroup
        $setGuid = Resolve-PowerGuid -Cmdlet $PSCmdlet -Value $Setting -Kind Setting
        $alias = [PsPowerCfg.PowerApi]::GetAliasName($setGuid)
        if ($alias -and -not $Force) {
            $exception = [System.InvalidOperationException]::new(
                "$alias ($setGuid) is a built-in Windows setting. Pass -Force to remove it from every scheme.")
            $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                    $exception,
                    'PowerSettingIsBuiltIn',
                    [System.Management.Automation.ErrorCategory]::InvalidOperation,
                    $setGuid))
            return
        }
        $friendly = [PsPowerCfg.Safe]::ReadFriendlyName($null, $subGuid, $setGuid)
        $label = if ($friendly) { '{0} ({1})' -f $friendly, $setGuid } else { "$setGuid" }
        if (-not $PSCmdlet.ShouldProcess($label, 'Remove power setting from all schemes')) { return }
        $r = [PsPowerCfg.Safe]::RemoveSetting($subGuid, $setGuid)
        if ($r.Failed) {
            $record = New-NativeErrorRecord -Result $r -ErrorId 'RemovePowerSettingFailed' -TargetObject $setGuid
            $PSCmdlet.WriteError($record)
        }
    }
}
