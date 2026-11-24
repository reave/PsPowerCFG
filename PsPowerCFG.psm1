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
    <#
    .SYNOPSIS
        Loads the native layer (PsPowerCfg.* types) from the per-user DLL cache,
        compiling it first when needed.
    .EXAMPLE
        Initialize-PsPowerCfgNative

        Runs once while the module imports, then is removed from the module scope.
    .NOTES
        Add-Type is used instead of a shipped binary because the project has no
        code-signing certificate yet. See the block comment above for the cache.
    #>
    [CmdletBinding()]
    param()

    $sourcePath = Join-Path -Path $PSScriptRoot -ChildPath 'Native\PsPowerCfg.Native.cs'
    $source = [System.IO.File]::ReadAllText($sourcePath)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($source))
    } finally {
        $sha.Dispose()
    }
    $hash = ([System.BitConverter]::ToString($hashBytes, 0, 8)).Replace('-', '').ToLowerInvariant()

    $loaded = 'PsPowerCfg.PowerApi' -as [type]
    if ($loaded) {
        $field = $loaded.GetField('LoadedSourceHash')
        $loadedHash = if ($field) { $field.GetValue($null) } else { $null }
        if ($loadedHash -eq $hash) { return }
        $loadedLabel = if ($loadedHash) { $loadedHash } else { 'pre-1.2' }
        $message = ('PsPowerCFG: this session already has a different build of the native layer loaded ' +
            "($loadedLabel, module needs $hash). " +
            '.NET cannot unload it. Start a new PowerShell session and import the module again.')
        throw [System.Management.Automation.ErrorRecord]::new(
            [System.InvalidOperationException]::new($message),
            'NativeLayerMismatch',
            [System.Management.Automation.ErrorCategory]::ResourceUnavailable,
            $loadedHash)
    }

    $dllPath = $null
    try {
        $edition = if ($PSVersionTable.PSEdition -eq 'Core') { 'core' } else { 'desktop' }
        $clr = [System.Environment]::Version
        $localAppData = [System.Environment+SpecialFolder]::LocalApplicationData
        $cacheRoot = [System.Environment]::GetFolderPath($localAppData)
        if ($cacheRoot) {
            $cacheDir = [System.IO.Path]::Combine($cacheRoot, 'PsPowerCFG', 'cache')
            $dllName = 'PsPowerCfg.Native.{0}.{1}{2}.{3}.dll' -f $hash, $edition, $clr.Major, $clr.Minor
            $dllPath = [System.IO.Path]::Combine($cacheDir, $dllName)
        }
    } catch {
        Write-Verbose -Message "PsPowerCFG: native cache unavailable: $($_.Exception.Message)"
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
                } catch {
                    # Another process won the race; use theirs.
                    try { [System.IO.File]::Delete($tmp) } catch { Write-Verbose -Message $_.Exception.Message }
                }
            }
            if (-not ('PsPowerCfg.PowerApi' -as [type])) {
                Add-Type -Path $dllPath -ErrorAction Stop
            }

            # Drop DLLs from older source versions for this edition/CLR. A file
            # still loaded by another session is locked; skip it and retry on a
            # later import.
            $suffix = '.{0}{1}.{2}.dll' -f $edition, $clr.Major, $clr.Minor
            foreach ($stale in [System.IO.Directory]::GetFiles($cacheDir, 'PsPowerCfg.Native.*' + $suffix)) {
                if ($stale -ne $dllPath) {
                    try {
                        [System.IO.File]::Delete($stale)
                    } catch {
                        Write-Verbose -Message "PsPowerCFG: stale cache in use: $stale"
                    }
                }
            }
        } catch {
            $reason = $_.Exception.Message
            Write-Verbose -Message "PsPowerCFG: cached native load failed, compiling in memory: $reason"
        }
    }

    if (-not ('PsPowerCfg.PowerApi' -as [type])) {
        Add-Type -TypeDefinition $source -ErrorAction Stop
    }
    [PsPowerCfg.PowerApi]::LoadedSourceHash = $hash
}

Initialize-PsPowerCfgNative
Remove-Item -Path Function:\Initialize-PsPowerCfgNative

# Type data is added here with -Force instead of TypesToProcess, so importing a
# second copy of the module from another folder does not fail with
# "The member ID is already present".
Update-TypeData -TypeName PsPowerCfg.PowerScheme -MemberType AliasProperty -MemberName ID -Value Guid -Force

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------
$private = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Functions\Private') -Filter *.ps1)
$public = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Functions\Public') -Filter *.ps1)

foreach ($file in @($private + $public)) {
    . $file.FullName
}

# Back-compat alias for the pre-1.1 plural name.
Set-Alias -Name Get-PowerSchemes -Value Get-PowerScheme

Export-ModuleMember -Function $public.BaseName -Alias 'Get-PowerSchemes'
