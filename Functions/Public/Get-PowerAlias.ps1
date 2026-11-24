function Get-PowerAlias {
    <#
    .SYNOPSIS
        Lists powercfg aliases and their GUIDs. Equivalent to powercfg /aliases and
        /aliasesh.
    .DESCRIPTION
        Returns the built-in alias table (captured from powercfg /aliasesh on
        Windows 11). Every -Scheme/-Subgroup/-Setting parameter in this module
        accepts these aliases in place of GUIDs.
    .EXAMPLE
        Get-PowerAlias -Kind Subgroup

        Lists the subgroup aliases (SUB_SLEEP, SUB_VIDEO, ...) and their GUIDs.
    .EXAMPLE
        Get-PowerAlias -Name *IDLE*

        Lists every alias containing IDLE, such as STANDBYIDLE and VIDEOIDLE.
    .OUTPUTS
        PsPowerCfg.PowerAlias
    #>
    [CmdletBinding()]
    [OutputType([PsPowerCfg.PowerAlias])]
    param(
        # Filter by alias. Wildcards are supported.
        [Parameter(Position = 0)]
        [SupportsWildcards()]
        [string]$Name = '*',

        # Scheme, OverlayScheme, Profile, Subgroup or Setting.
        [ValidateSet('Scheme', 'OverlayScheme', 'Profile', 'Subgroup', 'Setting')]
        [string]$Kind
    )

    $ignoreCase = [System.Management.Automation.WildcardOptions]::IgnoreCase
    $pattern = [System.Management.Automation.WildcardPattern]::new($Name, $ignoreCase)
    foreach ($a in [PsPowerCfg.PowerApi]::GetAliases()) {
        if ($Kind -and $a.Kind -ne $Kind) { continue }
        if ($pattern.IsMatch($a.Alias)) { $a }
    }
}
