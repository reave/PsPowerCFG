function Set-PowerHibernate {
    <#
    .SYNOPSIS
        Turns hibernate on or off, or sets the hiberfile size or type. Equivalent to powercfg /hibernate.
    .DESCRIPTION
        Runs powercfg /hibernate. This is a wrapper on purpose: the one public
        API, CallNtPowerInformation(SystemReserveHiberFile), only creates or
        deletes hiberfil.sys. powercfg also updates HibernateEnabled, the size
        and type registry values and fast startup, and Microsoft documents those
        values only through powercfg. Doing it by hand risks a state powercfg
        itself would not produce.

        Turning hibernate off deletes hiberfil.sys and disables fast startup and
        hybrid sleep. Requires an elevated session.
    .PARAMETER Enable
        powercfg /hibernate on.
    .PARAMETER Disable
        powercfg /hibernate off.
    .PARAMETER SizePercent
        powercfg /hibernate /size: hiberfile size as a percentage of RAM. 0 lets
        Windows manage the size, which a Reduced hiberfile needs. Also turns
        hibernate on.
    .PARAMETER Type
        powercfg /hibernate /type: Full, or Reduced (enough for fast startup
        only).
    .PARAMETER PassThru
        Return Get-PowerHibernate after the change.
    .EXAMPLE
        Set-PowerHibernate -Disable
    .EXAMPLE
        Set-PowerHibernate -SizePercent 0; Set-PowerHibernate -Type Reduced
    .OUTPUTS
        PsPowerCfg.PowerHibernate
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Enable')]
    [OutputType('PsPowerCfg.PowerHibernate')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Enable')]
        [switch]$Enable,

        [Parameter(Mandatory = $true, ParameterSetName = 'Disable')]
        [switch]$Disable,

        [Parameter(Mandatory = $true, ParameterSetName = 'Size')]
        [ValidateRange(0, 100)]
        [int]$SizePercent,

        [Parameter(Mandatory = $true, ParameterSetName = 'Type')]
        [ValidateSet('Full', 'Reduced')]
        [string]$Type,

        [switch]$PassThru
    )

    Assert-IsAdmin -Cmdlet $PSCmdlet

    switch ($PSCmdlet.ParameterSetName) {
        'Enable' { $arguments = @('/hibernate', 'on'); $action = 'Turn hibernate on' }
        'Disable' { $arguments = @('/hibernate', 'off'); $action = 'Turn hibernate off (deletes hiberfil.sys; disables fast startup and hybrid sleep)' }
        'Size' { $arguments = @('/hibernate', '/size', "$SizePercent"); $action = "Set hiberfile size to $SizePercent% of RAM and turn hibernate on" }
        'Type' { $arguments = @('/hibernate', '/type', $Type.ToLowerInvariant()); $action = "Set hiberfile type to $Type" }
    }
    if (-not $PSCmdlet.ShouldProcess('hibernate', $action)) { return }

    $stdout = Invoke-PowerCfg -Cmdlet $PSCmdlet -ArgumentList $arguments
    $said = if ($stdout -and $stdout.Trim()) { $stdout.Trim() } else { $null }
    if ($said) { Write-Verbose "powercfg said: $said" }

    # powercfg exits 0 for some refusals (for example /type reduced with a
    # custom size), so check the result instead of trusting the exit code.
    $after = Get-PowerHibernate
    $ok = switch ($PSCmdlet.ParameterSetName) {
        'Enable' { $after.Enabled }
        'Disable' { -not $after.Enabled }
        'Size' { $SizePercent -eq 0 -or [int]$after.HiberFileSizePercent -eq $SizePercent }
        'Type' { "$($after.HiberFileType)" -eq $Type }
    }
    if (-not $ok) {
        $detail = if ($said) { " powercfg said: $said" } else { '' }
        $exception = [System.InvalidOperationException]::new("powercfg $($arguments -join ' ') exited 0, but the change did not take effect.$detail")
        $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                $exception, 'SetPowerHibernateFailed', [System.Management.Automation.ErrorCategory]::InvalidResult, $arguments))
        return
    }
    if ($PassThru) { $after }
}
