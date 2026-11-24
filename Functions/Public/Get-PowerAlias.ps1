function Get-PowerAlias {
    <#
    .SYNOPSIS
        Lists powercfg aliases and their GUIDs. Equivalent to powercfg /aliases and /aliasesh.
    .DESCRIPTION
        Returns the built-in alias table (captured from powercfg /aliasesh on
        Windows 11). Every -Scheme/-Subgroup/-Setting parameter in this module
        accepts these aliases in place of GUIDs.
    .PARAMETER Name
        Filter by alias. Wildcards are supported.
    .PARAMETER Kind
        Scheme, OverlayScheme, Profile, Subgroup or Setting.
    .EXAMPLE
        Get-PowerAlias -Kind Subgroup
    .EXAMPLE
        Get-PowerAlias *IDLE*
    .OUTPUTS
        PsPowerCfg.PowerAlias
    #>
    [CmdletBinding()]
    [OutputType([PsPowerCfg.PowerAlias])]
    param(
        [Parameter(Position = 0)]
        [SupportsWildcards()]
        [string]$Name = '*',

        [ValidateSet('Scheme', 'OverlayScheme', 'Profile', 'Subgroup', 'Setting')]
        [string]$Kind
    )

    $pattern = [System.Management.Automation.WildcardPattern]::new($Name, [System.Management.Automation.WildcardOptions]::IgnoreCase)
    foreach ($a in [PsPowerCfg.PowerApi]::GetAliases()) {
        if ($Kind -and $a.Kind -ne $Kind) { continue }
        if ($pattern.IsMatch($a.Alias)) { $a }
    }
}
