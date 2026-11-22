#Requires -Version 5.1
Set-StrictMode -Version 3.0

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    throw 'PsPowerCFG requires Windows: it calls powrprof.dll directly.'
}

# ---------------------------------------------------------------------------
# Native layer
#
# Native\PsPowerCfg.Native.cs is compiled once and cached as a DLL under
# %LOCALAPPDATA%\PsPowerCFG\cache, keyed by PowerShell edition, CLR version and
# a hash of the source. Later imports load the cached DLL with no compiler
# invocation (csc.exe on 5.1 costs 1-2 s). If the cache is unusable we fall
# back to an in-memory compile. Re-importing in the same session is a no-op
# because the type already exists.
# ---------------------------------------------------------------------------
function Initialize-PsPowerCfgNative {
    [CmdletBinding()]
    param()

    if ('PsPowerCfg.PowerApi' -as [type]) { return }

    $sourcePath = Join-Path -Path $PSScriptRoot -ChildPath 'Native\PsPowerCfg.Native.cs'
    $source = [System.IO.File]::ReadAllText($sourcePath)

    $dllPath = $null
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($source))
        }
        finally {
            $sha.Dispose()
        }
        $hash = ([System.BitConverter]::ToString($hashBytes, 0, 8)).Replace('-', '').ToLowerInvariant()
        $edition = if ($PSVersionTable.PSEdition -eq 'Core') { 'core' } else { 'desktop' }
        $clr = [System.Environment]::Version
        $cacheRoot = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::LocalApplicationData)
        if ($cacheRoot) {
            $cacheDir = [System.IO.Path]::Combine($cacheRoot, 'PsPowerCFG', 'cache')
            $dllName = 'PsPowerCfg.Native.{0}.{1}{2}.{3}.dll' -f $hash, $edition, $clr.Major, $clr.Minor
            $dllPath = [System.IO.Path]::Combine($cacheDir, $dllName)
        }
    }
    catch {
        Write-Verbose "PsPowerCFG: native cache unavailable: $($_.Exception.Message)"
        $dllPath = $null
    }

    if ($dllPath) {
        try {
            if (-not [System.IO.File]::Exists($dllPath)) {
                [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($dllPath))
                # Compile to a unique temp name, then rename, so concurrent
                # imports never load a half-written file.
                $tmp = '{0}.{1}.tmp' -f $dllPath, [System.Guid]::NewGuid().ToString('N')
                Add-Type -TypeDefinition $source -OutputAssembly $tmp -OutputType Library -ErrorAction Stop
                try {
                    [System.IO.File]::Move($tmp, $dllPath)
                }
                catch {
                    # Another process won the race; use theirs.
                    try { [System.IO.File]::Delete($tmp) } catch { Write-Verbose $_.Exception.Message }
                }
            }
            if (-not ('PsPowerCfg.PowerApi' -as [type])) {
                Add-Type -Path $dllPath -ErrorAction Stop
            }
        }
        catch {
            Write-Verbose "PsPowerCFG: cached native load failed, compiling in memory: $($_.Exception.Message)"
        }
    }

    if (-not ('PsPowerCfg.PowerApi' -as [type])) {
        Add-Type -TypeDefinition $source -ErrorAction Stop
    }
}

Initialize-PsPowerCfgNative
Remove-Item -Path Function:\Initialize-PsPowerCfgNative

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------
$private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Functions\Private') -Filter *.ps1)
$public = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Functions\Public') -Filter *.ps1)

foreach ($file in @($private + $public)) {
    . $file.FullName
}

# Back-compat alias for the pre-1.1 plural name.
Set-Alias -Name Get-PowerSchemes -Value Get-PowerScheme

Export-ModuleMember -Function $public.BaseName -Alias 'Get-PowerSchemes'
