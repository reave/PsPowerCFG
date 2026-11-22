function Restore-DefaultPowerScheme {
    <#
    .SYNOPSIS
    Restores power schemes to their Windows defaults. Equivalent to powercfg /restoredefaultschemes.
    .DESCRIPTION
    Without -Guid, calls PowerRestoreDefaultPowerSchemes: every scheme is reset
    to its default settings AND ALL CUSTOM SCHEMES ARE DELETED. Export anything
    you want to keep first (Export-PowerScheme).

    With -Guid, calls PowerRestoreIndividualDefaultPowerScheme: only that
    built-in scheme's settings are reset; other schemes are untouched.

    Prompts for confirmation by default (ConfirmImpact High).
    .PARAMETER Guid
    A built-in scheme to reset on its own.
    .EXAMPLE
    Restore-DefaultPowerScheme -Guid 381b4222-f694-41f0-9685-ff5bb260df2e

    Resets only Balanced.
    .EXAMPLE
    Restore-DefaultPowerScheme -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'One', Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('ID', 'SchemeGuid')]
        [guid]$Guid
    )

    process {
        try {
            if ($PSCmdlet.ParameterSetName -eq 'One') {
                if ($PSCmdlet.ShouldProcess("$Guid", 'Reset power scheme to Windows defaults')) {
                    [PsPowerCfg.PowerApi]::RestoreDefaultScheme($Guid)
                }
            }
            else {
                $count = @([PsPowerCfg.PowerApi]::GetSchemes()).Count
                if ($PSCmdlet.ShouldProcess("all $count power schemes", 'Reset to Windows defaults and delete custom schemes')) {
                    [PsPowerCfg.PowerApi]::RestoreDefaultSchemes()
                }
            }
        }
        catch {
            $PSCmdlet.WriteError((New-NativeErrorRecord -ErrorRecord $_ -ErrorId 'RestoreDefaultPowerSchemeFailed' -TargetObject $Guid))
        }
    }
}
