@{
    RootModule           = 'PsPowerCFG.psm1'
    ModuleVersion        = '1.2.0'
    GUID                 = '4c864518-13d1-4a7e-a7e3-7c6080b2e6e8'
    Author               = 'reave'
    Copyright            = '(c) reave. All rights reserved.'
    Description          = 'powercfg.exe functionality for Windows PowerShell 5.1 and PowerShell 7, implemented on powrprof.dll and .NET APIs.'

    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')

    TypesToProcess       = @('PsPowerCFG.types.ps1xml')
    FormatsToProcess     = @('PsPowerCFG.format.ps1xml')

    # Explicit lists (no wildcards) so command discovery and autoload do not
    # have to import the module to find out what it exports.
    FunctionsToExport    = @(
        'Get-PowerScheme'
        'Get-ActivePowerScheme'
        'Set-ActivePowerScheme'
        'Copy-PowerScheme'
        'Rename-PowerScheme'
        'Remove-PowerScheme'
        'Import-PowerScheme'
        'Export-PowerScheme'
        'Restore-DefaultPowerScheme'
        'Export-SystemPowerReport'
        'Export-SystemSleepDiagnostics'
        'Export-SRUMDB'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @('Get-PowerSchemes')

    PrivateData          = @{
        PSData = @{
            Tags       = @('powercfg', 'power', 'powrprof', 'Windows', 'PSEdition_Desktop', 'PSEdition_Core')
            LicenseUri = 'https://github.com/reave/PsPowerCFG/blob/master/LICENSE'
            ProjectUri = 'https://github.com/reave/PsPowerCFG'
        }
    }
}
