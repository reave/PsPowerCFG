function Set-ActivePowerScheme {
    <#
    .SYNOPSIS
        Makes a power scheme active. Equivalent to powercfg /setactive.
    .DESCRIPTION
        Calls PowerSetActiveScheme in powrprof.dll. Does not require elevation
        unless the scheme's ActionSetActive security descriptor says otherwise.
    .PARAMETER Guid
        GUID of the scheme to activate. Accepts pipeline input from Get-PowerScheme.
    .PARAMETER Name
        Name of the scheme to activate (exact match, case-insensitive). Must match
        exactly one scheme.
    .PARAMETER PassThru
        Return the now-active scheme.
    .EXAMPLE
        Set-ActivePowerScheme -Name 'High performance'
    .EXAMPLE
        Get-PowerScheme -Name 'Balanced' | Set-ActivePowerScheme -PassThru
    .OUTPUTS
        None, or PsPowerCfg.PowerScheme with -PassThru.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Guid')]
    [OutputType([PsPowerCfg.PowerScheme])]
    param(
        [Parameter(ParameterSetName = 'Guid', Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('ID', 'SchemeGuid')]
        [guid]$Guid,

        [Parameter(ParameterSetName = 'Name', Mandatory = $true)]
        [string]$Name,

        [switch]$PassThru
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Name') {
            $found = @([PsPowerCfg.PowerApi]::GetSchemes() | Where-Object { $_.Name -eq $Name })
            if ($found.Count -ne 1) {
                $exception = [System.Management.Automation.ItemNotFoundException]::new(
                    "Expected exactly one power scheme named '$Name', found $($found.Count).")
                $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                        $exception, 'PowerSchemeNameNotUnique', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $Name))
                return
            }
            $Guid = $found[0].Guid
        }

        if (-not $PSCmdlet.ShouldProcess("$Guid", 'Set active power scheme')) { return }
        $r = [PsPowerCfg.Safe]::SetActiveScheme($Guid)
        if ($r.Failed) {
            $PSCmdlet.WriteError((New-NativeErrorRecord -Result $r -ErrorId 'SetActivePowerSchemeFailed' -TargetObject $Guid))
            return
        }
        if ($PassThru) { $r.Value }
    }
}
