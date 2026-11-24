# PsPowerCFG

**PsPowerCFG** brings `powercfg.exe` functionality to PowerShell as a module that runs on both
Windows PowerShell 5.1 and PowerShell 7.

Scheme and setting operations call `powrprof.dll` directly through a small C# P/Invoke layer. No
`powercfg.exe` process starts, no text is parsed, and output doesn't depend on the display
language. Reports that have no public Windows API (`/systempowerreport`, `/systemsleepdiagnostics`,
`/srumutil`) still run `powercfg.exe`, but through **System.Diagnostics.Process** with output
captured in memory and exit codes checked.

## Commands

| Command | powercfg | Implementation |
|---|---|---|
| `Get-PowerScheme` (alias `Get-PowerSchemes`) | `/list` | `powrprof.dll` |
| `Get-ActivePowerScheme` | `/getactivescheme` | `powrprof.dll` |
| `Set-ActivePowerScheme` | `/setactive` | `powrprof.dll` |
| `Copy-PowerScheme` | `/duplicatescheme` | `powrprof.dll` |
| `Rename-PowerScheme` | `/changename` | `powrprof.dll` |
| `Remove-PowerScheme` | `/delete` | `powrprof.dll` |
| `Import-PowerScheme` | `/import` | `powrprof.dll` (admin) |
| `Export-PowerScheme` | `/export` | `powercfg.exe` (no public export API for `.pow`) |
| `Restore-DefaultPowerScheme` | `/restoredefaultschemes` | `powrprof.dll` |
| `Get-PowerSetting` | `/query`, `/qh` | `powrprof.dll` |
| `Set-PowerSetting` | `/setacvalueindex`, `/setdcvalueindex` | `powrprof.dll` |
| `Set-PowerTimeout` | `/change` | `powrprof.dll` |
| `Remove-PowerSetting` | `/deletesetting` | `powrprof.dll` (admin) |
| `Set-PowerSettingAttribute` | `/attributes` | `powrprof.dll` (admin) |
| `Get-PowerAlias` | `/aliases`, `/aliasesh` | built-in table |
| `Get-PowerSecurityDescriptor` | `/getsecuritydescriptor` | `powrprof.dll` |
| `Set-PowerSecurityDescriptor` | `/setsecuritydescriptor` | `powrprof.dll` (admin) |
| `Export-SystemPowerReport` | `/systempowerreport`, `/sleepstudy` | `powercfg.exe` (admin) |
| `Export-SystemSleepDiagnostics` | `/systemsleepdiagnostics` | `powercfg.exe` (admin) |
| `Export-SrumDb` | `/srumutil` | `powercfg.exe` (admin) |
| `Get-PowerCapability` | `/availablesleepstates` | **CallNtPowerInformation** (no "why unavailable" reasons: undocumented) |
| `Get-PowerDevice` | `/devicequery` | `powrprof.dll` |
| `Enable-PowerDeviceWake` | `/deviceenableawake` | `powrprof.dll` (admin) |
| `Disable-PowerDeviceWake` | `/devicedisablewake` | `powrprof.dll` (admin) |
| `Get-PowerLastWake` | `/lastwake` | System event log via `wevtapi.dll` (powercfg's wake-history API is undocumented) |
| `Get-PowerHibernate` | `/hibernate` (status) | **CallNtPowerInformation** and the registry |
| `Set-PowerHibernate` | `/hibernate on\|off`, `/size`, `/type` | `powercfg.exe` (admin; see below) |
| `Get-PowerBatteryState` | none | **CallNtPowerInformation** |
| `Export-EnergyReport` | `/energy` | `powercfg.exe` (admin) |
| `Export-BatteryReport` | `/batteryreport` | `powercfg.exe` |
| `Export-PowerProvisioningXml` | `/pxml` | `powercfg.exe` (admin) |
| `Get-PowerRequest` | `/requests` | `powercfg.exe`, parsed (admin; no public API lists other processes' requests) |
| `Get-PowerWakeTimer` | `/waketimers` | `powercfg.exe`, parsed (admin; no public API; fields parsed from English output only) |
| `Get-PowerRequestOverride` | `/requestsoverride` (list) | registry |
| `Set-PowerRequestOverride`, `Remove-PowerRequestOverride` | `/requestsoverride <type> <name> [...]` | `powercfg.exe`, result verified in the registry (admin) |

Every **Scheme**, **Subgroup**, and **Setting** parameter accepts a GUID or a powercfg alias such as
`SCHEME_CURRENT`, `SUB_SLEEP`, or `STANDBYIDLE`. **Scheme** also accepts a scheme name. You can
usually omit **Subgroup** because it's looked up from the setting.

```powershell
Set-PowerSetting -Scheme SCHEME_CURRENT -Setting STANDBYIDLE -AcValue 1800
```

`Set-PowerHibernate` wraps `powercfg.exe` on purpose. The only public API,
**CallNtPowerInformation** with **SystemReserveHiberFile**, only creates or deletes
`hiberfil.sys`. powercfg also maintains **HibernateEnabled**, the hiberfile size and type, and fast
startup, and those registry values are documented only through powercfg. The function checks the
result with `Get-PowerHibernate` instead of trusting the exit code of `powercfg.exe`.

Errors from the native layer are written once. A .NET exception raised in PowerShell code lands in
the caller's **ErrorVariable** even when the function catches it, so functions call the
non-throwing **PsPowerCfg.Safe** class and write a single **ErrorRecord**.

## Native layer and the compile cache

`Add-Type` compiles `Native/PsPowerCfg.Native.cs` on first import and caches the result under
`$env:LOCALAPPDATA\PsPowerCFG\cache`, keyed by PowerShell edition, CLR version, and source hash.
Later imports load the cached DLL instead of starting the compiler. To force a rebuild, delete that
folder.

The C# must stay C# 5 syntax, because Windows PowerShell 5.1 compiles it with the .NET Framework
compiler.

`Add-Type` is blocked in Constrained Language Mode (WDAC or AppLocker script enforcement), so the
module doesn't import there.

## Changes in 1.6.0

- `Export-SRUMDB` is now `Export-SrumDb`. PowerShell command names aren't case-sensitive, so
  existing scripts keep working.
- The `Export-SrumDb` switches **FormatXML** and **FormatCSV** are now **FormatXml** and
  **FormatCsv**, and the `Export-BatteryReport`, `Export-SystemPowerReport`, and
  `Export-SystemSleepDiagnostics` switch **ReformatXML** is now **ReformatXml**. Parameter names
  aren't case-sensitive either.
- Comment-based help documents each parameter next to its declaration, and every example has an
  explanation.

## Breaking changes in 1.1

- `Get-PowerSchemes` is now `Get-PowerScheme`. The old name still works as an alias. Objects now
  have the properties **Guid**, **Name**, **Description**, and **IsActive**. **ID** remains as an
  alias of **Guid**.
- Export functions return a **System.IO.FileInfo** object instead of a status string, and they
  write to the current location by default instead of the module folder.
- `Export-SRUMDB` defaults to CSV. To get XML, use `-Format Xml`. The **FormatXML** and
  **FormatCSV** switches still work.

## Tests

Run the Pester tests in both editions:

```powershell
powershell.exe -NoProfile -Command "Invoke-Pester -Path .\Tests -Output Detailed"
pwsh.exe -NoProfile -Command "Invoke-Pester -Path .\Tests -Output Detailed"
```

Report and import tests only run when elevated. Tests tagged `Mutating` create, activate, and
delete temporary `PsPowerCFG*` schemes. When elevated, they also disarm and re-arm one wake-armed
device. They're skipped unless you opt in:

```powershell
$env:PSPOWERCFG_MUTATING = '1'
```

They restore the original active scheme and delete only schemes whose name starts with
`PsPowerCFG`, never a built-in GUID.

## Contributing

Code and documentation follow the rules in [Code and documentation style](STYLE.md). Before you
submit a change, run the style check. No output means the code is clean.

```powershell
pwsh.exe -NoProfile -File .\Tests\Invoke-StyleCheck.ps1
```
