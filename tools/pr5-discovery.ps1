#Requires -RunAsAdministrator
<#
Temporary PR 5 helper: captures powercfg /requests, /waketimers and
/requestsoverride formats. Run from an elevated PowerShell (5.1 or 7):

    .\tools\pr5-discovery.ps1 | Set-Clipboard

Changes it makes, all reverted before it exits:
- holds a display/system power request in this process for a few seconds;
- creates a resumable waitable timer 2 hours ahead, then cancels it;
- sets one request override on the fake process PsPowerCFG-test.exe, then
  removes it and checks the override key is back to its starting state.
This file is removed before PR 5 merges.
#>
Set-StrictMode -Version 3.0
# Continue, not Stop: on 5.1, Stop turns powercfg's stderr into a terminating error.
$ErrorActionPreference = 'Continue'

Add-Type -Namespace PsPowerCfgDisc -Name N -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint f);
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct REASON_CONTEXT { public uint Version; public uint Flags; public string SimpleReasonString; }
[DllImport("kernel32.dll", SetLastError = true)] public static extern IntPtr PowerCreateRequest(ref REASON_CONTEXT c);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool PowerSetRequest(IntPtr h, int t);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool PowerClearRequest(IntPtr h, int t);
[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)] public static extern IntPtr CreateWaitableTimerW(IntPtr a, bool manualReset, string name);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool SetWaitableTimer(IntPtr h, ref long due, int period, IntPtr r, IntPtr a, bool resume);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool CancelWaitableTimer(IntPtr h);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool CloseHandle(IntPtr h);
'@

function Show([string]$title, [scriptblock]$body) {
    "===== $title"
    $out = & $body 2>&1 | Out-String
    $out = $out -replace "`r", ''
    # Make trailing spaces visible.
    ($out -split "`n" | ForEach-Object { $_ -replace '( +)$', '$1<EOL>' }) -join "`n"
    "----- exit $LASTEXITCODE"
}
function Dump-Override {
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Power\PowerRequestOverride')
    if (-not $key) { return 'key missing' }
    function Walk($k, $path) {
        "[$path]"
        foreach ($n in $k.GetValueNames()) { '  {0} ({1}) = {2}' -f $n, $k.GetValueKind($n), (@($k.GetValue($n)) -join ',') }
        foreach ($s in $k.GetSubKeyNames()) { $c = $k.OpenSubKey($s); Walk $c "$path\$s"; $c.Dispose() }
    }
    Walk $key 'PowerRequestOverride'
    $key.Dispose()
}

"PSVersion $($PSVersionTable.PSVersion); OS $([Environment]::OSVersion.Version)"
Show 'requests (idle)' { powercfg.exe /requests }

$ctx = New-Object PsPowerCfgDisc.N+REASON_CONTEXT
$ctx.Version = 0; $ctx.Flags = 1; $ctx.SimpleReasonString = 'PsPowerCFG test'
$req = [PsPowerCfgDisc.N]::PowerCreateRequest([ref]$ctx)
try {
    [void][PsPowerCfgDisc.N]::PowerSetRequest($req, 0)   # DisplayRequired
    [void][PsPowerCfgDisc.N]::PowerSetRequest($req, 1)   # SystemRequired
    [void][PsPowerCfgDisc.N]::PowerSetRequest($req, 3)   # ExecutionRequired
    [void][PsPowerCfgDisc.N]::SetThreadExecutionState([uint32]2147483651)  # ES_CONTINUOUS|ES_DISPLAY_REQUIRED|ES_SYSTEM_REQUIRED
    Show 'requests (held: PowerSetRequest display+system+execution, SetThreadExecutionState display+system)' { powercfg.exe /requests }
}
finally {
    [void][PsPowerCfgDisc.N]::SetThreadExecutionState([uint32]2147483648)  # ES_CONTINUOUS
    foreach ($t in 0, 1, 3) { [void][PsPowerCfgDisc.N]::PowerClearRequest($req, $t) }
    [void][PsPowerCfgDisc.N]::CloseHandle($req)
}
Show 'requests (released)' { powercfg.exe /requests }

Show 'waketimers (idle)' { powercfg.exe /waketimers }
$timer = [PsPowerCfgDisc.N]::CreateWaitableTimerW([IntPtr]::Zero, $true, 'PsPowerCFG test timer')
try {
    $due = -72000000000L   # 2 hours, relative
    [void][PsPowerCfgDisc.N]::SetWaitableTimer($timer, [ref]$due, 0, [IntPtr]::Zero, [IntPtr]::Zero, $true)
    Show 'waketimers (held: resumable timer +2h)' { powercfg.exe /waketimers }
}
finally {
    [void][PsPowerCfgDisc.N]::CancelWaitableTimer($timer)
    [void][PsPowerCfgDisc.N]::CloseHandle($timer)
}
Show 'waketimers (released)' { powercfg.exe /waketimers }

$before = (Dump-Override) -join "`n"
"===== override registry before`n$before"
Show 'requestsoverride (before)' { powercfg.exe /requestsoverride }
try {
    foreach ($types in @('display system awaymode', 'display', 'system', 'awaymode', 'execution', 'display execution')) {
        Show "set: process PsPowerCFG-test.exe $types" { powercfg.exe /requestsoverride process PsPowerCFG-test.exe @($types -split ' ') }
        "===== registry after '$types'"
        Dump-Override
        Show "requestsoverride after '$types'" { powercfg.exe /requestsoverride }
    }
    Show 'set: service PsPowerCFGTestSvc system' { powercfg.exe /requestsoverride service PsPowerCFGTestSvc system }
    "===== registry after service"
    Dump-Override
    Show 'clear service' { powercfg.exe /requestsoverride service PsPowerCFGTestSvc }
}
finally {
    Show 'clear: process PsPowerCFG-test.exe (no types)' { powercfg.exe /requestsoverride process PsPowerCFG-test.exe }
    "===== registry after clear"
    Dump-Override
    $after = (Dump-Override) -join "`n"
    if ($after -ne $before) {
        'NOT BACK TO BEFORE: removing leftover PsPowerCFG test values'
        foreach ($sub in 'Process', 'Service', 'Driver', '') {
            $path = 'SYSTEM\CurrentControlSet\Control\Power\PowerRequestOverride' + $(if ($sub) { "\$sub" })
            $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($path, $true)
            if ($k) {
                foreach ($n in $k.GetValueNames()) { if ($n -like 'PsPowerCFG*') { $k.DeleteValue($n); "deleted $path\$n" } }
                $k.Dispose()
            }
        }
        $final = (Dump-Override) -join "`n"
        "back to before: $($final -eq $before)"
    }
    else { 'override key back to before: True' }
}
