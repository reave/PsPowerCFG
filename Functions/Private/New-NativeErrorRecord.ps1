function New-NativeErrorRecord {
    <#
    .SYNOPSIS
        Turns an exception from the native layer into an ErrorRecord with a
        category that matches the Win32 error (access denied, not found, ...).
    .EXAMPLE
        $record = New-NativeErrorRecord -Result $r -ErrorId 'CopyPowerSchemeFailed' -TargetObject $Guid
        $PSCmdlet.WriteError($record)

        Writes a non-terminating error for a failed [PsPowerCfg.Safe] call. A Win32
        ERROR_ACCESS_DENIED becomes category PermissionDenied, and so on.
    .NOTES
        The New verb only builds an object in memory; it changes no system state, so
        the function has no ShouldProcess support.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Creates an in-memory ErrorRecord only.')]
    [CmdletBinding(DefaultParameterSetName = 'Result')]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        # A failed [PsPowerCfg.NativeResult] from the [PsPowerCfg.Safe] layer.
        [Parameter(Mandatory = $true, ParameterSetName = 'Result')]
        [PsPowerCfg.NativeResult]$Result,

        # An ErrorRecord caught from a direct [PsPowerCfg.PowerApi] call.
        [Parameter(Mandatory = $true, ParameterSetName = 'Record')]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        # FullyQualifiedErrorId for the new record, e.g. 'CopyPowerSchemeFailed'.
        [Parameter(Mandatory = $true)]
        [string]$ErrorId,

        # The object the failed operation was acting on.
        [object]$TargetObject
    )

    $exception = if ($Result) { $Result.Error } else { $ErrorRecord.Exception }
    # .NET exceptions thrown from a static method call arrive wrapped.
    while ($exception -is [System.Management.Automation.MethodInvocationException] -and
        $exception.InnerException) {
        $exception = $exception.InnerException
    }

    $categoryName = 'InvalidOperation'
    if ($exception -is [System.ComponentModel.Win32Exception]) {
        switch ($exception.NativeErrorCode) {
            2 { $categoryName = 'ObjectNotFound' }      # ERROR_FILE_NOT_FOUND
            3 { $categoryName = 'ObjectNotFound' }      # ERROR_PATH_NOT_FOUND
            5 { $categoryName = 'PermissionDenied' }    # ERROR_ACCESS_DENIED
            87 { $categoryName = 'InvalidArgument' }    # ERROR_INVALID_PARAMETER
            183 { $categoryName = 'ResourceExists' }    # ERROR_ALREADY_EXISTS
        }
    }
    $category = [System.Management.Automation.ErrorCategory]$categoryName
    [System.Management.Automation.ErrorRecord]::new($exception, $ErrorId, $category, $TargetObject)
}
