function New-NativeErrorRecord {
    <#
    .SYNOPSIS
        Turns an exception from the native layer into an ErrorRecord with a
        category that matches the Win32 error (access denied, not found, ...).
    #>
    [CmdletBinding(DefaultParameterSetName = 'Result')]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        # A failed [PsPowerCfg.NativeResult] from the [PsPowerCfg.Safe] layer.
        [Parameter(Mandatory = $true, ParameterSetName = 'Result')]
        [PsPowerCfg.NativeResult]$Result,

        [Parameter(Mandatory = $true, ParameterSetName = 'Record')]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter(Mandatory = $true)]
        [string]$ErrorId,

        [object]$TargetObject
    )

    $exception = if ($Result) { $Result.Error } else { $ErrorRecord.Exception }
    # .NET exceptions thrown from a static method call arrive wrapped.
    while ($exception -is [System.Management.Automation.MethodInvocationException] -and $exception.InnerException) {
        $exception = $exception.InnerException
    }

    $category = [System.Management.Automation.ErrorCategory]::InvalidOperation
    if ($exception -is [System.ComponentModel.Win32Exception]) {
        switch ($exception.NativeErrorCode) {
            2 { $category = [System.Management.Automation.ErrorCategory]::ObjectNotFound }     # ERROR_FILE_NOT_FOUND
            3 { $category = [System.Management.Automation.ErrorCategory]::ObjectNotFound }     # ERROR_PATH_NOT_FOUND
            5 { $category = [System.Management.Automation.ErrorCategory]::PermissionDenied }   # ERROR_ACCESS_DENIED
            87 { $category = [System.Management.Automation.ErrorCategory]::InvalidArgument }   # ERROR_INVALID_PARAMETER
            183 { $category = [System.Management.Automation.ErrorCategory]::ResourceExists }   # ERROR_ALREADY_EXISTS
        }
    }
    [System.Management.Automation.ErrorRecord]::new($exception, $ErrorId, $category, $TargetObject)
}
