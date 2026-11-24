function Remove-PowerRequestOverride {
    <#
    .SYNOPSIS
        Removes a power request override. Equivalent to powercfg /requestsoverride <type> <name> with no request types.
    .DESCRIPTION
        Runs powercfg /requestsoverride for the caller with no request types,
        which deletes its override, then confirms the registry value is gone.
        Requires an elevated session.
    .PARAMETER CallerType
        Process, Service or Driver.
    .PARAMETER Name
        The caller name, as Get-PowerRequestOverride shows it.
    .EXAMPLE
        Get-PowerRequestOverride -Name wmplayer.exe | Remove-PowerRequestOverride
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Process', 'Service', 'Driver')]
        [string]$CallerType,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    begin {
        Assert-IsAdmin -Cmdlet $PSCmdlet
    }

    process {
        $existing = Get-PowerRequestOverride -CallerType $CallerType | Where-Object { $_.Name -eq $Name }
        if (-not $existing) {
            $exception = [System.Management.Automation.ItemNotFoundException]::new("No request override for $CallerType $Name.")
            $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                    $exception, 'PowerRequestOverrideNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $Name))
            return
        }
        if (-not $PSCmdlet.ShouldProcess("$CallerType $Name", 'Remove power request override')) { return }

        [void](Invoke-PowerCfg -Cmdlet $PSCmdlet -ArgumentList @('/requestsoverride', $CallerType.ToLowerInvariant(), $Name))
        if (Get-PowerRequestOverride -CallerType $CallerType | Where-Object { $_.Name -eq $Name }) {
            $exception = [System.InvalidOperationException]::new("powercfg /requestsoverride exited 0, but the override for $CallerType $Name is still there.")
            $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                    $exception, 'RemovePowerRequestOverrideFailed', [System.Management.Automation.ErrorCategory]::InvalidResult, $Name))
        }
    }
}
