function Invoke-PowerCfg {
    <#
    .SYNOPSIS
    Runs powercfg.exe in-process-launched mode with stdout/stderr captured in
    memory. Used only for options that have no public Win32 API.
    .DESCRIPTION
    Uses System.Diagnostics.Process directly instead of Start-Process: no temp
    files, no shared file names across concurrent runs, and the exit code and
    error text are always surfaced.

    Throws a terminating error in the calling cmdlet on a non-zero exit code.
    Returns stdout as a string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCmdlet]$Cmdlet,

        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,

        [string]$WorkingDirectory
    )

    # Windows PowerShell 5.1 has no ProcessStartInfo.ArgumentList, so build a
    # correctly quoted command line (CommandLineToArgvW rules).
    $quoted = foreach ($arg in $ArgumentList) {
        if ($arg -notmatch '[\s"]' -and $arg.Length -gt 0) { $arg; continue }
        $sb = [System.Text.StringBuilder]::new('"')
        $slashes = 0
        foreach ($ch in $arg.ToCharArray()) {
            if ($ch -eq '\') { $slashes++; continue }
            if ($ch -eq '"') { [void]$sb.Append('\', $slashes * 2 + 1) }
            elseif ($slashes) { [void]$sb.Append('\', $slashes) }
            $slashes = 0
            [void]$sb.Append($ch)
        }
        [void]$sb.Append('\', $slashes * 2).Append('"')
        $sb.ToString()
    }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = [System.IO.Path]::Combine([System.Environment]::SystemDirectory, 'powercfg.exe')
    $psi.Arguments = $quoted -join ' '
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }

    Write-Verbose "powercfg.exe $($psi.Arguments)"
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi
    try {
        [void]$process.Start()
        # Read stderr asynchronously so neither pipe can fill and deadlock.
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $stdout = $process.StandardOutput.ReadToEnd()
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $exitCode = $process.ExitCode
    }
    finally {
        $process.Dispose()
    }

    if ($exitCode -ne 0) {
        $message = (($stderr, $stdout) | Where-Object { $_ -and $_.Trim() } | Select-Object -First 1)
        if (-not $message) { $message = 'no output' }
        $exception = [System.ComponentModel.Win32Exception]::new(
            $exitCode, "powercfg.exe $($psi.Arguments) failed with exit code $exitCode`: $($message.Trim())")
        $record = [System.Management.Automation.ErrorRecord]::new(
            $exception, 'PowerCfgFailed', [System.Management.Automation.ErrorCategory]::InvalidResult, $ArgumentList)
        $Cmdlet.ThrowTerminatingError($record)
    }
    $stdout
}
