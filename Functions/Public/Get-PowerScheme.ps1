function Get-PowerScheme {
    <#
    .SYNOPSIS
    Lists the power schemes (power plans) on the computer. Equivalent to powercfg /list.
    .DESCRIPTION
    Enumerates power schemes directly through powrprof.dll (PowerEnumerate,
    PowerReadFriendlyName, PowerReadDescription, PowerGetActiveScheme). No
    powercfg.exe process, no text parsing, and names come back in the display
    language of the OS.
    .PARAMETER Name
    Filter by scheme name. Wildcards are supported.
    .PARAMETER Guid
    Return only the schemes with these GUIDs.
    .EXAMPLE
    Get-PowerScheme

    Lists every power scheme and marks the active one.
    .EXAMPLE
    Get-PowerScheme -Name 'High*'
    .EXAMPLE
    Get-PowerScheme | Where-Object IsActive
    .OUTPUTS
    PsPowerCfg.PowerScheme
    .NOTES
    The objects also expose an ID alias property for compatibility with the
    pre-1.1 Get-PowerSchemes output.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    [OutputType([PsPowerCfg.PowerScheme])]
    param(
        [Parameter(ParameterSetName = 'Name', Position = 0)]
        [SupportsWildcards()]
        [string[]]$Name,

        [Parameter(ParameterSetName = 'Guid', Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('ID', 'SchemeGuid')]
        [guid[]]$Guid
    )

    begin {
        $schemes = [PsPowerCfg.PowerApi]::GetSchemes()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Guid') {
            foreach ($g in $Guid) {
                $match = $false
                foreach ($s in $schemes) {
                    if ($s.Guid -eq $g) { $s; $match = $true }
                }
                if (-not $match) {
                    $exception = [System.Management.Automation.ItemNotFoundException]::new("Power scheme $g was not found.")
                    $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                            $exception, 'PowerSchemeNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $g))
                }
            }
            return
        }

        if (-not $Name) { return $schemes }

        $patterns = foreach ($n in $Name) {
            [System.Management.Automation.WildcardPattern]::new($n, [System.Management.Automation.WildcardOptions]::IgnoreCase)
        }
        foreach ($s in $schemes) {
            foreach ($p in $patterns) {
                if ($p.IsMatch($s.Name)) { $s; break }
            }
        }
    }
}
