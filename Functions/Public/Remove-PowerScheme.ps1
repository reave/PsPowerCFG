function Remove-PowerScheme {
    <#
    .SYNOPSIS
    Deletes a power scheme. Equivalent to powercfg /delete.
    .DESCRIPTION
    Calls PowerDeleteScheme. The active scheme cannot be deleted; activate a
    different scheme first. Prompts for confirmation by default (ConfirmImpact
    High) because built-in schemes can be deleted too and only come back via
    Restore-DefaultPowerScheme.
    .PARAMETER Guid
    Scheme GUID(s). Accepts pipeline input from Get-PowerScheme.
    .EXAMPLE
    Get-PowerScheme -Name 'Test*' | Remove-PowerScheme -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('ID', 'SchemeGuid')]
        [guid[]]$Guid
    )

    process {
        foreach ($g in $Guid) {
            if ($g -eq [PsPowerCfg.PowerApi]::GetActiveScheme()) {
                $exception = [System.InvalidOperationException]::new("Power scheme $g is active and cannot be deleted. Activate another scheme first.")
                $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                        $exception, 'PowerSchemeIsActive', [System.Management.Automation.ErrorCategory]::InvalidOperation, $g))
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
