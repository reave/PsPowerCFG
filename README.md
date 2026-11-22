# PsPowerCFG

powercfg.exe functionality as a PowerShell module that runs on both Windows PowerShell 5.1 and PowerShell 7.

Scheme and setting operations call `powrprof.dll` directly through a small C# P/Invoke layer, so there is no powercfg.exe process, no text parsing, and output is language-independent. Reports that have no public Windows API (`/systempowerreport`, `/systemsleepdiagnostics`, `/srumutil`) still run powercfg.exe, but through `System.Diagnostics.Process` with output captured in memory and exit codes checked.

## Commands

| Command | powercfg | Implementation |
|---|---|---|
| `Get-PowerScheme` (alias `Get-PowerSchemes`) | `/list` | powrprof.dll |
| `Get-ActivePowerScheme` | `/getactivescheme` | powrprof.dll |
| `Set-ActivePowerScheme` | `/setactive` | powrprof.dll |
| `Copy-PowerScheme` | `/duplicatescheme` | powrprof.dll |
| `Rename-PowerScheme` | `/changename` | powrprof.dll |
| `Remove-PowerScheme` | `/delete` | powrprof.dll |
| `Import-PowerScheme` | `/import` | powrprof.dll (admin) |
| `Export-PowerScheme` | `/export` | powercfg.exe (no public export API for .pow) |
| `Restore-DefaultPowerScheme` | `/restoredefaultschemes` | powrprof.dll |
| `Get-PowerSetting` | `/query`, `/qh` | powrprof.dll |
| `Set-PowerSetting` | `/setacvalueindex`, `/setdcvalueindex` | powrprof.dll |
| `Set-PowerTimeout` | `/change` | powrprof.dll |
| `Remove-PowerSetting` | `/deletesetting` | powrprof.dll (admin) |
| `Set-PowerSettingAttribute` | `/attributes` | powrprof.dll (admin) |
| `Get-PowerAlias` | `/aliases`, `/aliasesh` | built-in table |
| `Get-PowerSecurityDescriptor` | `/getsecuritydescriptor` | powrprof.dll |
| `Set-PowerSecurityDescriptor` | `/setsecuritydescriptor` | powrprof.dll (admin) |
| `Export-SystemPowerReport` | `/systempowerreport`, `/sleepstudy` | powercfg.exe (admin) |
| `Export-SystemSleepDiagnostics` | `/systemsleepdiagnostics` | powercfg.exe (admin) |
| `Export-SRUMDB` | `/srumutil` | powercfg.exe (admin) |
| `Get-PowerCapability` | `/availablesleepstates` | CallNtPowerInformation (no "why unavailable" reasons: undocumented) |
| `Get-PowerDevice` | `/devicequery` | powrprof.dll |
| `Enable-PowerDeviceWake` | `/deviceenableawake` | powrprof.dll (admin) |
| `Disable-PowerDeviceWake` | `/devicedisablewake` | powrprof.dll (admin) |
| `Get-PowerLastWake` | `/lastwake` | System event log via wevtapi.dll (powercfg's wake-history API is undocumented) |
| `Get-PowerHibernate` | `/hibernate` (status) | CallNtPowerInformation + registry |
| `Set-PowerHibernate` | `/hibernate on\|off`, `/size`, `/type` | powercfg.exe (admin; see below) |
| `Get-PowerBatteryState` | none | CallNtPowerInformation |

Every `-Scheme`, `-Subgroup` and `-Setting` parameter accepts a GUID or a powercfg alias (`SCHEME_CURRENT`, `SUB_SLEEP`, `STANDBYIDLE`, ...); `-Scheme` also accepts a scheme name. `-Subgroup` can usually be omitted: it is looked up from the setting.

`Set-PowerHibernate` wraps powercfg on purpose. The only public API, `CallNtPowerInformation(SystemReserveHiberFile)`, just creates or deletes `hiberfil.sys`. powercfg also maintains `HibernateEnabled`, the hiberfile size and type, and fast startup, and those registry values are documented only through powercfg. The function checks the result with `Get-PowerHibernate` rather than trusting powercfg's exit code.

Errors from the native layer are written once. A .NET exception raised in PowerShell code lands in the caller's `-ErrorVariable` even when the function catches it, so functions call the non-throwing `[PsPowerCfg.Safe]` layer and write a single ErrorRecord.

## Native layer and the compile cache

`Native/PsPowerCfg.Native.cs` is compiled with `Add-Type` on first import and cached under `%LOCALAPPDATA%\PsPowerCFG\cache`, keyed by PowerShell edition, CLR version and source hash. Later imports load the cached DLL instead of invoking the compiler. Delete that folder to force a rebuild.

The C# must stay C# 5 syntax, because Windows PowerShell 5.1 compiles it with the .NET Framework compiler.

`Add-Type` is blocked in Constrained Language Mode (WDAC/AppLocker script enforcement), so the module does not import there.

## Breaking changes in 1.1

- `Get-PowerSchemes` is now `Get-PowerScheme`. The old name still works as an alias. Objects now have `Guid`, `Name`, `Description`, and `IsActive`. `ID` remains as an alias of `Guid`.
- Export functions return a `System.IO.FileInfo` instead of a status string, and they write to the current location by default instead of the module folder.
- `Export-SRUMDB` defaults to CSV. Use `-Format Xml`. The `-FormatXML`/`-FormatCSV` switches still work.

## Tests

```powershell
powershell.exe -NoProfile -Command "Invoke-Pester .\Tests -Output Detailed"
pwsh.exe       -NoProfile -Command "Invoke-Pester .\Tests -Output Detailed"
```

Report and import tests only run when elevated. Tests tagged `Mutating` create, activate and delete temporary `PsPowerCFG*` schemes, and (elevated only) disarm and re-arm one wake-armed device. They are skipped unless you opt in with `$env:PSPOWERCFG_MUTATING = '1'`. They restore the original active scheme and delete only schemes whose name starts with `PsPowerCFG` (never a built-in GUID).
