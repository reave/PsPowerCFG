function Resolve-PowerGuid {
    <#
    .SYNOPSIS
        Resolves a GUID string, a powercfg alias (SCHEME_CURRENT, SUB_SLEEP,
        STANDBYIDLE, ...) or, for schemes, a scheme name, to a GUID. Throws a
        terminating error in the calling cmdlet when it cannot.
    #>
    [CmdletBinding()]
    [OutputType([guid])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCmdlet]$Cmdlet,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Scheme', 'Subgroup', 'Setting')]
        [string]$Kind
    )

    $g = [PsPowerCfg.PowerApi]::ResolveGuid($Value)
    if ($null -ne $g) { return [guid]$g }

    if ($Kind -eq 'Scheme') {
        $match = @([PsPowerCfg.PowerApi]::GetSchemes() | Where-Object { $_.Name -eq $Value })
        if ($match.Count -eq 1) { return $match[0].Guid }
    }

    $exception = [System.ArgumentException]::new("'$Value' is not a $($Kind.ToLowerInvariant()) GUID or a known alias (see Get-PowerAlias).")
    $Cmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
            $exception, "Unknown$Kind", [System.Management.Automation.ErrorCategory]::InvalidArgument, $Value))
}
