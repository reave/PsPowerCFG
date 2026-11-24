function Set-PowerRequestOverride {
    <#
    .SYNOPSIS
        Makes Windows ignore some power request types from a process, service or driver.
        Equivalent to powercfg /requestsoverride <type> <name> <requests>.
    .DESCRIPTION
        Replaces any existing override for the caller with -Request. For example,
        an override of Display for a media player lets the display turn off while
        it plays.

        Runs powercfg /requestsoverride and then reads the registry back to
        confirm the stored bitmask. Writing the registry directly would skip
        whatever else powercfg does to apply the change, which is not documented.
        Requires an elevated session.
    .EXAMPLE
        Set-PowerRequestOverride -CallerType Process -Name wmplayer.exe -Request Display, System

        Lets the display turn off and the system sleep while wmplayer.exe plays. Any
        earlier override for wmplayer.exe is replaced.
    .OUTPUTS
        PsPowerCfg.PowerRequestOverride
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType('PsPowerCfg.PowerRequestOverride')]
    param(
        # Process, Service or Driver, as Get-PowerRequest reports it.
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Process', 'Service', 'Driver')]
        [string]$CallerType,

        # The caller name: an executable name such as wmplayer.exe for a process,
        # the service name, or the driver name as Get-PowerRequest shows it.
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        # One or more of Display, System, AwayMode, Execution.
        [Parameter(Mandatory = $true, Position = 2, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Display', 'System', 'AwayMode', 'Execution')]
        [string[]]$Request,

        # Return the override after the change.
        [switch]$PassThru
    )

    begin {
        Assert-IsAdmin -Cmdlet $PSCmdlet
    }

    process {
        $expected = 0
        foreach ($r in $Request) { $expected = $expected -bor $script:PowerRequestTypeBits[$r] }
        $requests = @(foreach ($r in $Request | Sort-Object -Unique) { $r.ToLowerInvariant() })
        if (-not $PSCmdlet.ShouldProcess("$CallerType $Name", "Ignore $($Request -join ', ') requests")) { return }

        $arguments = @('/requestsoverride', $CallerType.ToLowerInvariant(), $Name) + $requests
        [void](Invoke-PowerCfg -Cmdlet $PSCmdlet -ArgumentList $arguments)
        $after = Get-PowerRequestOverride -CallerType $CallerType |
            Where-Object -FilterScript { $_.Name -eq $Name }
        if (-not $after -or $after.Mask -ne $expected) {
            $got = if ($after) { $after.Mask } else { 'none' }
            $exception = [System.InvalidOperationException]::new(
                ('powercfg /requestsoverride exited 0, but the stored override for ' +
                "$CallerType $Name is $got, not $expected."))
            $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                    $exception,
                    'SetPowerRequestOverrideFailed',
                    [System.Management.Automation.ErrorCategory]::InvalidResult,
                    $Name))
            return
        }
        if ($PassThru) { $after }
    }
}
