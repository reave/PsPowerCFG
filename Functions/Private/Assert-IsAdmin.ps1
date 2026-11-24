function Assert-IsAdmin {
    <#
    .SYNOPSIS
        Throws a terminating error in the calling cmdlet when not elevated.
    .EXAMPLE
        Assert-IsAdmin -Cmdlet $PSCmdlet

        Stops the calling public function with an ElevationRequired error unless the
        session runs as Administrator.
    #>
    [CmdletBinding()]
    param(
        # The caller's $PSCmdlet, so the error is attributed to the public function.
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCmdlet]$Cmdlet
    )

    if (-not (Test-IsAdmin)) {
        $exception = [System.UnauthorizedAccessException]::new(
            ("$($Cmdlet.MyInvocation.MyCommand.Name) requires an elevated session. " +
            'Run PowerShell as Administrator.'))
        $record = [System.Management.Automation.ErrorRecord]::new(
            $exception,
            'ElevationRequired',
            [System.Management.Automation.ErrorCategory]::PermissionDenied,
            $null)
        $Cmdlet.ThrowTerminatingError($record)
    }
}
