function Remove-PowerScheme {
    <#
    .SYNOPSIS
    Deletes a power scheme. Equivalent to powercfg /delete.
    .DESCRIPTION
    Calls PowerDeleteScheme. The active scheme cannot be deleted; activate a
    different scheme first. Prompts for confirmation by default (ConfirmImpact
    High).

    Built-in Windows schemes (Balanced, High performance, Power saver,
    Ultimate Performance) are refused unless -Force is passed, because the
    only way back is Restore-DefaultPowerScheme.
    .PARAMETER Guid
    Scheme GUID(s). Accepts pipeline input from Get-PowerScheme.
    .PARAMETER Force
    Allow deleting a built-in Windows scheme. Still prompts unless -Confirm:$false.
    .EXAMPLE
    Get-PowerScheme -Name 'Test*' | Remove-PowerScheme -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('ID', 'SchemeGuid')]
        [guid[]]$Guid,

        [switch]$Force
    )

    process {
        foreach ($g in $Guid) {
            if ($g -eq [PsPowerCfg.PowerApi]::GetActiveScheme()) {
                $exception = [System.InvalidOperationException]::new("Power scheme $g is active and cannot be deleted. Activate another scheme first.")
                $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                        $exception, 'PowerSchemeIsActive', [System.Management.Automation.ErrorCategory]::InvalidOperation, $g))
                continue
            }

            if (-not $Force -and $script:BuiltInPowerSchemes -contains $g) {
                $exception = [System.InvalidOperationException]::new("Power scheme $g is a built-in Windows scheme. Pass -Force to delete it; Restore-DefaultPowerScheme brings it back.")
                $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                        $exception, 'PowerSchemeIsBuiltIn', [System.Management.Automation.ErrorCategory]::InvalidOperation, $g))
                continue
            }

            $label = $g.ToString()
            try { $label = '{0} ({1})' -f [PsPowerCfg.PowerApi]::ReadFriendlyName($g, $null, $null), $g } catch { Write-Verbose $_.Exception.Message }
            if (-not $PSCmdlet.ShouldProcess($label, 'Delete power scheme')) { continue }
            try {
                [PsPowerCfg.PowerApi]::DeleteScheme($g)
            }
            catch {
                $PSCmdlet.WriteError((New-NativeErrorRecord -ErrorRecord $_ -ErrorId 'RemovePowerSchemeFailed' -TargetObject $g))
            }
        }
    }
}
