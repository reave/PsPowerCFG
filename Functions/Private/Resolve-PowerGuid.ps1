function Resolve-PowerGuid {
    <#
    .SYNOPSIS
        Resolves a GUID string, a powercfg alias (SCHEME_CURRENT, SUB_SLEEP,
        STANDBYIDLE, ...) or, for schemes, a scheme name, to a GUID. Throws a
        terminating error in the calling cmdlet when it cannot.
    .EXAMPLE
        $subGuid = Resolve-PowerGuid -Cmdlet $PSCmdlet -Value 'SUB_SLEEP' -Kind Subgroup

        Returns 238c9fa8-0aad-41ed-83f4-97be242c8f20, the sleep subgroup GUID.
    #>
    [CmdletBinding()]
    [OutputType([guid])]
    param(
        # The caller's $PSCmdlet, so the error is attributed to the public function.
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCmdlet]$Cmdlet,

        # GUID string, powercfg alias or (for -Kind Scheme) exact scheme name.
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value,

        # What the value names. Only Scheme also matches by name; it also picks the error id.
        [Parameter(Mandatory = $true)]
        [ValidateSet('Scheme', 'Subgroup', 'Setting')]
        [string]$Kind
    )

    $g = [PsPowerCfg.PowerApi]::ResolveGuid($Value)
    if ($null -ne $g) {
        [guid]$g
        return
    }

    if ($Kind -eq 'Scheme') {
        $match = @([PsPowerCfg.PowerApi]::GetSchemes() | Where-Object -FilterScript { $_.Name -eq $Value })
        if ($match.Count -eq 1) {
            $match[0].Guid
            return
        }
    }

    $exception = [System.ArgumentException]::new(
        "'$Value' is not a $($Kind.ToLowerInvariant()) GUID or a known alias (see Get-PowerAlias).")
    $Cmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
            $exception,
            "Unknown$Kind",
            [System.Management.Automation.ErrorCategory]::InvalidArgument,
            $Value))
}
