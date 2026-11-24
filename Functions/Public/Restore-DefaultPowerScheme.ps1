function Restore-DefaultPowerScheme {
    <#
    .SYNOPSIS
        Restores power schemes to their Windows defaults. Equivalent to
        powercfg /restoredefaultschemes.
    .DESCRIPTION
        With -Guid: calls PowerRestoreIndividualDefaultPowerScheme. Only that
        built-in scheme's settings are reset; other schemes are untouched.

        With -All: calls PowerRestoreDefaultPowerSchemes, which resets every
        built-in scheme AND DELETES ALL CUSTOM SCHEMES. Guards:
          - -All must be passed explicitly; there is no default "restore everything".
          - Every custom scheme is first exported to a .pow file under -BackupPath.
            If any export fails, nothing is restored. The backup needs an elevated
            session.
          - Prompts for confirmation (ConfirmImpact High) and lists what will be
            deleted.
        Skip the backup only with -NoBackup.

        Restore a backup with Import-PowerScheme.
    .EXAMPLE
        Restore-DefaultPowerScheme -Guid 381b4222-f694-41f0-9685-ff5bb260df2e

        Resets only Balanced.
    .EXAMPLE
        Restore-DefaultPowerScheme -All -WhatIf

        Shows which custom schemes would be backed up and deleted.
    .EXAMPLE
        Get-ChildItem -Path "$env:LOCALAPPDATA\PsPowerCFG\backup\20261122-174500\*.pow" | Import-PowerScheme

        Brings the backed-up custom schemes back.
    .OUTPUTS
        With -All, System.IO.FileInfo for each backup file written.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'All',
        Justification = 'The switch only selects the All parameter set.')]
    # No DefaultParameterSetName on purpose: with neither -Guid nor -All the call must fail
    # to bind instead of prompting for -Guid or falling through to the full reset.
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [OutputType([System.IO.FileInfo])]
    param(
        # A built-in scheme to reset on its own.
        [Parameter(ParameterSetName = 'One', Mandatory = $true, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [Alias('ID', 'SchemeGuid')]
        [guid]$Guid,

        # Reset every scheme and delete custom schemes.
        [Parameter(ParameterSetName = 'All', Mandatory = $true)]
        [switch]$All,

        # Folder for the .pow backups. Default:
        # %LOCALAPPDATA%\PsPowerCFG\backup\<yyyyMMdd-HHmmss>
        [Parameter(ParameterSetName = 'All')]
        [string]$BackupPath,

        # Do not export custom schemes before deleting them.
        [Parameter(ParameterSetName = 'All')]
        [switch]$NoBackup
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'One') {
            if ($script:BuiltInPowerSchemes -notcontains $Guid) {
                Write-Warning -Message "$Guid is not a built-in Windows scheme; Windows may reject the restore."
            }
            if (-not $PSCmdlet.ShouldProcess("$Guid", 'Reset power scheme to Windows defaults')) { return }
            $r = [PsPowerCfg.Safe]::RestoreDefaultScheme($Guid)
            if ($r.Failed) {
                $errorId = 'RestoreDefaultPowerSchemeFailed'
                $record = New-NativeErrorRecord -Result $r -ErrorId $errorId -TargetObject $Guid
                $PSCmdlet.WriteError($record)
            }
            return
        }

        # The .pow backup uses powercfg /export, which needs elevation. Fail
        # before prompting rather than after.
        if (-not $NoBackup) { Assert-IsAdmin -Cmdlet $PSCmdlet }

        $custom = @(foreach ($s in [PsPowerCfg.PowerApi]::GetSchemes()) {
                if ($script:BuiltInPowerSchemes -notcontains $s.Guid) { $s }
            })
        $names = 'none'
        if ($custom.Count) { $names = @(foreach ($s in $custom) { "'$($s.Name)'" }) -join ', ' }
        $backupNote = 'custom schemes exported first'
        if ($NoBackup -or -not $custom.Count) { $backupNote = 'no backup' }
        $action = ("Reset all schemes to Windows defaults and DELETE $($custom.Count) custom scheme(s): " +
            "$names ($backupNote)")
        if (-not $PSCmdlet.ShouldProcess('all power schemes', $action)) { return }

        if ($custom.Count -and -not $NoBackup) {
            if (-not $BackupPath) {
                $localAppData = [System.Environment+SpecialFolder]::LocalApplicationData
                $root = [System.Environment]::GetFolderPath($localAppData)
                $stamp = [datetime]::Now.ToString('yyyyMMdd-HHmmss')
                $BackupPath = [System.IO.Path]::Combine($root, 'PsPowerCFG', 'backup', $stamp)
            }
            $dir = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($BackupPath)
            [void][System.IO.Directory]::CreateDirectory($dir)

            # Export-PowerScheme throws a terminating error on failure, which
            # stops here before anything is deleted.
            foreach ($s in $custom) {
                $safe = $s.Name
                foreach ($c in [System.IO.Path]::GetInvalidFileNameChars()) { $safe = $safe.Replace($c, '_') }
                $exportParams = @{
                    Guid        = $s.Guid
                    Path        = [System.IO.Path]::Combine($dir, "$safe-$($s.Guid).pow")
                    Confirm     = $false
                    WhatIf      = $false
                    ErrorAction = 'Stop'
                }
                Export-PowerScheme @exportParams
            }
            Write-Verbose -Message "Backed up $($custom.Count) custom scheme(s) to $dir"
        }

        $r = [PsPowerCfg.Safe]::RestoreDefaultSchemes()
        if ($r.Failed) {
            $errorId = 'RestoreDefaultPowerSchemeFailed'
            $record = New-NativeErrorRecord -Result $r -ErrorId $errorId -TargetObject 'all'
            $PSCmdlet.WriteError($record)
        }
    }
}
