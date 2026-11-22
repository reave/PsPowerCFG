#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
# Run under both editions:
#   powershell.exe -NoProfile -Command "Invoke-Pester .\Tests -Output Detailed"
#   pwsh.exe       -NoProfile -Command "Invoke-Pester .\Tests -Output Detailed"

BeforeDiscovery {
    # -Skip is evaluated during discovery, before any BeforeAll runs, so the
    # elevation check has to happen here.
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    # Tests that create/activate/delete schemes only run when opted in.
    $runMutating = $env:PSPOWERCFG_MUTATING -eq '1'
}

BeforeAll {
    $manifest = Join-Path $PSScriptRoot '..\PsPowerCFG.psd1'
    Import-Module $manifest -Force -ErrorAction Stop

    # Language-neutral ground truth: GUIDs from powercfg.exe output.
    $script:cliGuids = @(powercfg.exe /list | Select-String -Pattern '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' -AllMatches |
            ForEach-Object { [guid]$_.Matches[0].Value })
    $script:cliActive = [guid]((powercfg.exe /getactivescheme | Select-String -Pattern '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}').Matches[0].Value)
}

AfterAll {
    Remove-Module PsPowerCFG -ErrorAction SilentlyContinue
}

Describe 'Module' {
    It 'loads the native type' {
        'PsPowerCfg.PowerApi' -as [type] | Should -Not -BeNullOrEmpty
    }

    It 're-imports without recompiling or throwing' {
        { Import-Module (Join-Path $PSScriptRoot '..\PsPowerCFG.psd1') -Force -ErrorAction Stop } | Should -Not -Throw
    }

    It 'exports exactly the manifest functions' {
        $cmds = (Get-Command -Module PsPowerCFG -CommandType Function).Name | Sort-Object
        $expected = @(
            'Get-PowerScheme', 'Get-ActivePowerScheme', 'Set-ActivePowerScheme', 'Copy-PowerScheme', 'Rename-PowerScheme',
            'Remove-PowerScheme', 'Import-PowerScheme', 'Export-PowerScheme', 'Restore-DefaultPowerScheme',
            'Export-SystemPowerReport', 'Export-SystemSleepDiagnostics', 'Export-SRUMDB',
            'Get-PowerSetting', 'Set-PowerSetting', 'Set-PowerTimeout', 'Remove-PowerSetting', 'Set-PowerSettingAttribute',
            'Get-PowerAlias', 'Get-PowerSecurityDescriptor', 'Set-PowerSecurityDescriptor')
        $cmds | Should -Be ($expected | Sort-Object)
    }

    It 'keeps the Get-PowerSchemes alias' {
        (Get-Alias Get-PowerSchemes).ResolvedCommandName | Should -Be 'Get-PowerScheme'
    }
}

Describe 'Get-PowerScheme' {
    It 'returns the same scheme GUIDs as powercfg /list' {
        $native = @((Get-PowerScheme).Guid | Sort-Object)
        $native | Should -Be @($script:cliGuids | Sort-Object)
    }

    It 'marks exactly one scheme active, matching powercfg /getactivescheme' {
        $active = @(Get-PowerScheme | Where-Object IsActive)
        $active.Count | Should -Be 1
        $active[0].Guid | Should -Be $script:cliActive
    }

    It 'returns non-empty names' {
        Get-PowerScheme | ForEach-Object { $_.Name | Should -Not -BeNullOrEmpty }
    }

    It 'exposes the legacy ID alias property' {
        $s = Get-PowerScheme | Select-Object -First 1
        $s.ID | Should -Be $s.Guid
    }

    It 'filters by wildcard name' {
        $first = Get-PowerScheme | Select-Object -First 1
        $pattern = $first.Name.Substring(0, [Math]::Min(3, $first.Name.Length)) + '*'
        (Get-PowerScheme -Name $pattern).Guid | Should -Contain $first.Guid
    }

    It 'accepts GUIDs from the pipeline' {
        $first = Get-PowerScheme | Select-Object -First 1
        ($first | Get-PowerScheme).Guid | Should -Be $first.Guid
    }

    It 'writes a non-terminating error for an unknown GUID' {
        $r = Get-PowerScheme -Guid ([guid]::NewGuid()) -ErrorVariable err -ErrorAction SilentlyContinue
        $r | Should -BeNullOrEmpty
        $err[0].FullyQualifiedErrorId | Should -BeLike 'PowerSchemeNotFound*'
    }

    It 'is fast (100 calls well under a powercfg spawn each)' {
        $null = Get-PowerScheme
        $sw = [Diagnostics.Stopwatch]::StartNew()
        for ($i = 0; $i -lt 100; $i++) { $null = Get-PowerScheme }
        $sw.Stop()
        Write-Host ("    Get-PowerScheme x100: {0} ms" -f $sw.ElapsedMilliseconds)
        $sw.ElapsedMilliseconds | Should -BeLessThan 2000
    }
}

Describe 'Get-ActivePowerScheme' {
    It 'matches powercfg /getactivescheme' {
        (Get-ActivePowerScheme).Guid | Should -Be $script:cliActive
    }

    It 'reports IsActive' {
        (Get-ActivePowerScheme).IsActive | Should -BeTrue
    }
}

Describe 'Scheme management' -Tag 'Mutating' -Skip:(-not $runMutating) {
    BeforeAll {
        $script:originalActive = [PsPowerCfg.PowerApi]::GetActiveScheme()
        $script:created = [System.Collections.Generic.List[guid]]::new()
        $script:tmp = Join-Path ([IO.Path]::GetTempPath()) ('PsPowerCFG-scheme-' + [guid]::NewGuid().ToString('N'))
        [void][IO.Directory]::CreateDirectory($script:tmp)
        $script:source = Get-ActivePowerScheme
    }
    AfterAll {
        [PsPowerCfg.PowerApi]::SetActiveScheme($script:originalActive)
        $builtIn = @(
            [guid]'381b4222-f694-41f0-9685-ff5bb260df2e', [guid]'8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c',
            [guid]'a1841308-3541-4fab-bc81-f71556f20b4a', [guid]'e9a42b02-d5df-448d-aa00-03f14749eb61')
        # Only ever delete schemes this suite named; never a built-in GUID.
        $leftovers = [PsPowerCfg.PowerApi]::GetSchemes() | Where-Object {
            $_.Name -like 'PsPowerCFG*' -and $builtIn -notcontains $_.Guid -and $_.Guid -ne $script:originalActive
        }
        foreach ($s in $leftovers) {
            try { [PsPowerCfg.PowerApi]::DeleteScheme($s.Guid) } catch { Write-Warning "cleanup $($s.Name): $($_.Exception.Message)" }
        }
        Remove-Item -LiteralPath $script:tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Copy-PowerScheme duplicates with a new name and description' {
        $copy = $script:source | Copy-PowerScheme -NewName 'PsPowerCFG test copy' -Description 'temporary'
        $script:created.Add($copy.Guid)
        $copy.Guid | Should -Not -Be $script:source.Guid
        $copy.Name | Should -Be 'PsPowerCFG test copy'
        $copy.Description | Should -Be 'temporary'
        (Get-PowerScheme).Guid | Should -Contain $copy.Guid
    }

    It 'Copy-PowerScheme honors -DestinationGuid' {
        $dest = [guid]::NewGuid()
        $copy = Copy-PowerScheme -Guid $script:source.Guid -DestinationGuid $dest -NewName 'PsPowerCFG test dest'
        $script:created.Add($copy.Guid)
        $copy.Guid | Should -Be $dest
        $copy.Name | Should -Be 'PsPowerCFG test dest'
    }

    It 'Rename-PowerScheme changes the name' {
        $r = Rename-PowerScheme -Guid $script:created[0] -NewName 'PsPowerCFG renamed' -PassThru
        $r.Name | Should -Be 'PsPowerCFG renamed'
        (powercfg.exe /list | Out-String) | Should -Match 'PsPowerCFG renamed'
    }

    It 'Set-ActivePowerScheme activates by GUID and by name' {
        Set-ActivePowerScheme -Guid $script:created[0]
        (Get-ActivePowerScheme).Guid | Should -Be $script:created[0]
        $p = Set-ActivePowerScheme -Name $script:source.Name -PassThru
        $p.Guid | Should -Be $script:source.Guid
        $p.IsActive | Should -BeTrue
    }

    It 'Remove-PowerScheme refuses the active scheme' {
        Remove-PowerScheme -Guid (Get-ActivePowerScheme).Guid -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
        $err[0].FullyQualifiedErrorId | Should -BeLike 'PowerSchemeIsActive*'
    }

    It 'Remove-PowerScheme -WhatIf deletes nothing' {
        Remove-PowerScheme -Guid $script:created[0] -WhatIf
        (Get-PowerScheme).Guid | Should -Contain $script:created[0]
    }

    It 'Export-PowerScheme writes a .pow file' -Skip:(-not $isAdmin) {
        $f = Export-PowerScheme -Guid $script:created[0] -Path (Join-Path $script:tmp 'x.pow')
        $f | Should -BeOfType [IO.FileInfo]
        $f.Length | Should -BeGreaterThan 0
    }

    It 'Import-PowerScheme round-trips an export' -Skip:(-not $isAdmin) {
        $s = Import-PowerScheme -Path (Join-Path $script:tmp 'x.pow') -NewName 'PsPowerCFG imported'
        $script:created.Add($s.Guid)
        $s.Name | Should -Be 'PsPowerCFG imported'
        (Get-PowerScheme).Guid | Should -Contain $s.Guid
    }

    It 'Remove-PowerScheme deletes from the pipeline' {
        $victim = Copy-PowerScheme -Guid $script:source.Guid -NewName 'PsPowerCFG delete me'
        $script:created.Add($victim.Guid)
        $victim | Remove-PowerScheme -Confirm:$false
        (Get-PowerScheme).Guid | Should -Not -Contain $victim.Guid
    }

    It 'Export-PowerScheme and Restore -All throw ElevationRequired when not elevated' -Skip:$isAdmin {
        { Export-PowerScheme -Guid $script:source.Guid -Path (Join-Path $script:tmp 'n.pow') } | Should -Throw -ErrorId 'ElevationRequired,Export-PowerScheme'
        { Restore-DefaultPowerScheme -All -WhatIf } | Should -Throw -ErrorId 'ElevationRequired,Restore-DefaultPowerScheme'
    }

    It 'Remove-PowerScheme refuses a built-in scheme without -Force' {
        $builtIn = Get-PowerScheme | Where-Object { -not $_.IsActive -and $_.Guid -in @([guid]'381b4222-f694-41f0-9685-ff5bb260df2e', [guid]'8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c', [guid]'a1841308-3541-4fab-bc81-f71556f20b4a') } | Select-Object -First 1
        if (-not $builtIn) { Set-ItResult -Skipped -Because 'no inactive built-in scheme'; return }
        Remove-PowerScheme -Guid $builtIn.Guid -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
        $err[0].FullyQualifiedErrorId | Should -BeLike 'PowerSchemeIsBuiltIn*'
        (Get-PowerScheme).Guid | Should -Contain $builtIn.Guid
    }

    It 'Restore-DefaultPowerScheme requires -All for the full reset' {
        (Get-Command Restore-DefaultPowerScheme).ParameterSets.Name | Should -Not -Contain '__AllParameterSets'
        { Restore-DefaultPowerScheme -Confirm:$false -ErrorAction Stop } | Should -Throw
    }

    It 'Restore-DefaultPowerScheme -All -WhatIf changes nothing and writes no backup' -Skip:(-not $isAdmin) {
        $before = @((Get-PowerScheme).Guid | Sort-Object)
        $out = Restore-DefaultPowerScheme -All -BackupPath (Join-Path $script:tmp 'bk') -WhatIf
        $out | Should -BeNullOrEmpty
        Test-Path (Join-Path $script:tmp 'bk') | Should -BeFalse
        @((Get-PowerScheme).Guid | Sort-Object) | Should -Be $before
    }
}

Describe 'Get-PowerAlias' {
    It 'loads the alias table' {
        @(Get-PowerAlias).Count | Should -BeGreaterThan 150
    }
    It 'classifies subgroups and settings' {
        (Get-PowerAlias SUB_SLEEP).Kind | Should -Be 'Subgroup'
        $s = Get-PowerAlias STANDBYIDLE
        $s.Kind | Should -Be 'Setting'
        $s.SubgroupGuid | Should -Be ([guid]'238c9fa8-0aad-41ed-83f4-97be242c8f20')
    }
    It 'matches every alias powercfg /aliases prints' {
        $cli = powercfg.exe /aliases | ForEach-Object {
            if ($_ -match '^\s*([0-9a-f-]{36})\s+(\S+)\s*$') { [pscustomobject]@{ Guid = [guid]$Matches[1]; Alias = $Matches[2] } }
        }
        $ours = @{}
        Get-PowerAlias | ForEach-Object { $ours[$_.Alias] = $_.Guid }
        foreach ($c in $cli) { $ours[$c.Alias] | Should -Be $c.Guid -Because $c.Alias }
    }
}

Describe 'Get-PowerSetting' {
    BeforeAll {
        $script:active = [PsPowerCfg.PowerApi]::GetActiveScheme()
        $script:all = @(Get-PowerSetting -IncludeHidden)

        # powercfg /qh blocks: GUID line, then values; the last two 0x.. values
        # in each setting block are AC and DC. Language-neutral.
        $script:cli = @{}
        $current = $null
        foreach ($line in (powercfg.exe /qh $script:active)) {
            $g = [regex]::Matches($line, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
            if ($g.Count -and $line -match '^\s{4}\S') {
                $current = [guid]$g[0].Value
                $script:cli[$current] = [System.Collections.Generic.List[uint32]]::new()
                continue
            }
            if ($g.Count) { $current = $null; continue }
            if ($current -and $line -match '0x([0-9a-fA-F]{8})\s*$') {
                $script:cli[$current].Add([Convert]::ToUInt32($Matches[1], 16))
            }
        }
    }

    It 'returns visible settings by default and more with -IncludeHidden' {
        $visible = @(Get-PowerSetting)
        $visible.Count | Should -BeGreaterThan 5
        $visible | ForEach-Object { $_.IsHidden | Should -BeFalse }
        $script:all.Count | Should -BeGreaterOrEqual $visible.Count
    }

    It 'covers the same settings as powercfg /qh' {
        @($script:all.Guid | Sort-Object -Unique) | Should -Be @($script:cli.Keys | Sort-Object)
    }

    It 'reports the same AC/DC values as powercfg /qh' {
        foreach ($s in $script:all) {
            $vals = $script:cli[$s.Guid]
            if ($vals.Count -lt 2) { continue }
            $s.AcValue | Should -Be $vals[$vals.Count - 2] -Because "$($s.Name) AC"
            $s.DcValue | Should -Be $vals[$vals.Count - 1] -Because "$($s.Name) DC"
        }
    }

    It 'finds the subgroup from a setting alias' {
        $s = Get-PowerSetting -Setting STANDBYIDLE
        $s.SubgroupAlias | Should -Be 'SUB_SLEEP'
        $s.IsRange | Should -BeTrue
        $s.Units | Should -Not -BeNullOrEmpty
    }

    It 'describes index settings with possible values' {
        $s = Get-PowerSetting -Subgroup SUB_BUTTONS -Setting PBUTTONACTION
        $s.IsRange | Should -BeFalse
        $s.PossibleValues.Count | Should -BeGreaterThan 1
        $s.AcValueName | Should -Not -BeNullOrEmpty
    }

    It 'accepts scheme aliases, names and pipeline input' {
        (Get-PowerSetting -Scheme SCHEME_BALANCED -Setting STANDBYIDLE).SchemeGuid | Should -Be ([guid]'381b4222-f694-41f0-9685-ff5bb260df2e')
        $p = Get-PowerScheme | Select-Object -First 1
        (Get-PowerSetting -Scheme $p.Name -Setting VIDEOIDLE).SchemeGuid | Should -Be $p.Guid
        ($p | Get-PowerSetting -Setting VIDEOIDLE).SchemeGuid | Should -Be $p.Guid
    }

    It 'filters by -Name on name or alias' {
        (Get-PowerSetting -Name 'VIDEOIDLE').Alias | Should -Be 'VIDEOIDLE'
    }

    It 'throws UnknownSetting for garbage' {
        { Get-PowerSetting -Setting 'NOT_A_SETTING' } | Should -Throw -ErrorId 'UnknownSetting,Get-PowerSetting'
    }

    It 'is fast (full /qh equivalent)' {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $null = Get-PowerSetting -IncludeHidden
        $sw.Stop()
        $cliSw = [Diagnostics.Stopwatch]::StartNew()
        $null = powercfg.exe /qh
        $cliSw.Stop()
        Write-Host ("    Get-PowerSetting -IncludeHidden: {0} ms ({1} settings); powercfg /qh: {2} ms" -f $sw.ElapsedMilliseconds, $script:all.Count, $cliSw.ElapsedMilliseconds)
        $sw.ElapsedMilliseconds | Should -BeLessThan 5000
    }
}

Describe 'Get-PowerSecurityDescriptor' {
    It 'matches powercfg /getsecuritydescriptor for <_>' -ForEach @('ActionSetActive', 'ActionCreate', 'ActionDefault') {
        $cli = (powercfg.exe /getsecuritydescriptor $_ | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { Set-ItResult -Skipped -Because "powercfg failed: $cli"; return }
        (Get-PowerSecurityDescriptor -Action $_).Sddl | Should -Be $cli
    }
    It 'matches powercfg for the active scheme' {
        $g = [PsPowerCfg.PowerApi]::GetActiveScheme()
        $cli = (powercfg.exe /getsecuritydescriptor $g | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { Set-ItResult -Skipped -Because "powercfg failed: $cli"; return }
        (Get-PowerSecurityDescriptor -Guid $g).Sddl | Should -Be $cli
    }
    # CONSOLELOCK ships with its own descriptor under
    # HKLM\SYSTEM\CurrentControlSet\Control\Power\SecurityDescriptors, unlike
    # most settings, which fall back to the Default one. Matching it shows we
    # read the setting's descriptor rather than echoing the scheme's.
    It 'matches powercfg for a setting with its own descriptor (CONSOLELOCK)' {
        $cli = (powercfg.exe /getsecuritydescriptor 0e796bdb-100d-47d6-a2d5-f7d2daa51f51 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { Set-ItResult -Skipped -Because "powercfg failed: $cli"; return }
        (Get-PowerSecurityDescriptor -Guid CONSOLELOCK).Sddl | Should -Be $cli
    }
}

Describe 'Setting changes' -Tag 'Mutating' -Skip:(-not $runMutating) {
    BeforeAll {
        $script:originalActive = [PsPowerCfg.PowerApi]::GetActiveScheme()
        $script:copy = Copy-PowerScheme -Guid $script:originalActive -NewName 'PsPowerCFG settings test'
    }
    AfterAll {
        [PsPowerCfg.PowerApi]::SetActiveScheme($script:originalActive)
        Get-PowerScheme | Where-Object { $_.Name -like 'PsPowerCFG*' -and $_.Guid -ne $script:originalActive } |
            ForEach-Object { try { [PsPowerCfg.PowerApi]::DeleteScheme($_.Guid) } catch { Write-Warning $_.Exception.Message } }
    }

    It 'Set-PowerSetting writes AC and DC values (verified with powercfg)' {
        $r = Set-PowerSetting -Scheme $script:copy.Guid -Setting STANDBYIDLE -AcValue 1234 -DcValue 600 -PassThru
        $r.AcValue | Should -Be 1234
        $r.DcValue | Should -Be 600
        $q = powercfg.exe /q $script:copy.Guid SUB_SLEEP STANDBYIDLE | Out-String
        $q | Should -Match '0x000004d2'
        $q | Should -Match '0x00000258'
    }

    It 'Set-PowerSetting rejects out-of-range values unless -Force' {
        $s = Get-PowerSetting -Scheme $script:copy.Guid -Subgroup SUB_BUTTONS -Setting PBUTTONACTION
        { Set-PowerSetting -Scheme $script:copy.Guid -Setting PBUTTONACTION -AcValue 999 } | Should -Throw -ErrorId 'PowerSettingValueOutOfRange,Set-PowerSetting'
        (Get-PowerSetting -Scheme $script:copy.Guid -Subgroup SUB_BUTTONS -Setting PBUTTONACTION).AcValue | Should -Be $s.AcValue
    }

    It 'Set-PowerSetting -WhatIf writes nothing' {
        Set-PowerSetting -Scheme $script:copy.Guid -Setting STANDBYIDLE -AcValue 42 -WhatIf
        (Get-PowerSetting -Scheme $script:copy.Guid -Setting STANDBYIDLE).AcValue | Should -Be 1234
    }

    It 'Set-PowerTimeout converts minutes to seconds' {
        $r = Set-PowerTimeout -Scheme $script:copy.Guid -Type Monitor -AcMinutes 7 -DcMinutes 3 -PassThru
        $r.AcValue | Should -Be 420
        $r.DcValue | Should -Be 180
    }

    It 'Set-PowerSetting on the active scheme applies immediately' {
        Set-ActivePowerScheme -Guid $script:copy.Guid
        Set-PowerTimeout -Type Disk -AcMinutes 11
        (powercfg.exe /q SCHEME_CURRENT SUB_DISK DISKIDLE | Out-String) | Should -Match '0x00000294'
        Set-ActivePowerScheme -Guid $script:originalActive
    }

    It 'Set-PowerSettingAttribute toggles ATTRIBUTE_HIDE and restores it' -Skip:(-not $isAdmin) {
        $target = Get-PowerSetting -Setting PERFBOOSTMODE -IncludeHidden
        $was = $target.IsHidden
        try {
            Set-PowerSettingAttribute -Setting PERFBOOSTMODE -Hidden (-not $was)
            (Get-PowerSetting -Setting PERFBOOSTMODE -IncludeHidden).IsHidden | Should -Be (-not $was)
        }
        finally {
            Set-PowerSettingAttribute -Setting PERFBOOSTMODE -Hidden $was
        }
        (Get-PowerSetting -Setting PERFBOOSTMODE -IncludeHidden).IsHidden | Should -Be $was
    }

    It 'Remove-PowerSetting refuses built-in settings without -Force' -Skip:(-not $isAdmin) {
        Remove-PowerSetting -Subgroup SUB_SLEEP -Setting STANDBYIDLE -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
        $err[0].FullyQualifiedErrorId | Should -BeLike 'PowerSettingIsBuiltIn*'
        (Get-PowerSetting -Setting STANDBYIDLE) | Should -Not -BeNullOrEmpty
    }

    It 'Set-PowerSecurityDescriptor rejects invalid SDDL and honors -WhatIf' -Skip:(-not $isAdmin) {
        $before = (Get-PowerSecurityDescriptor -Action ActionSetActive).Sddl
        Set-PowerSecurityDescriptor -Action ActionSetActive -Sddl 'not sddl' -ErrorVariable err -ErrorAction SilentlyContinue
        $err[0].FullyQualifiedErrorId | Should -BeLike 'InvalidSddl*'
        Set-PowerSecurityDescriptor -Action ActionSetActive -Sddl 'O:BAG:SYD:P(A;CI;KA;;;BA)' -WhatIf
        (Get-PowerSecurityDescriptor -Action ActionSetActive).Sddl | Should -Be $before
    }
}

Describe 'Report functions' {
    BeforeAll {
        $script:out = Join-Path ([IO.Path]::GetTempPath()) ('PsPowerCFG-tests-' + [guid]::NewGuid().ToString('N'))
        [void][IO.Directory]::CreateDirectory($script:out)
    }
    AfterAll {
        Remove-Item -LiteralPath $script:out -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'not elevated' -Skip:$isAdmin {
        It 'Export-SystemPowerReport throws ElevationRequired' {
            { Export-SystemPowerReport -OutFile (Join-Path $script:out 'x.html') } | Should -Throw -ErrorId 'ElevationRequired,Export-SystemPowerReport'
        }
    }

    Context 'elevated' -Skip:(-not $isAdmin) {
        It 'Export-SystemPowerReport writes HTML and returns FileInfo' {
            $f = Export-SystemPowerReport -OutFile (Join-Path $script:out 'spr') -Duration 1
            $f | Should -BeOfType [IO.FileInfo]
            $f.Extension | Should -Be '.html'
            $f.Exists | Should -BeTrue
        }

        It 'Export-SystemPowerReport XML round-trips through -ReformatXML' {
            $x = Export-SystemPowerReport -FormatXML -OutFile (Join-Path $script:out 'spr.xml') -Duration 1
            $x.Extension | Should -Be '.xml'
            $h = Export-SystemPowerReport -ReformatXML -FilePath $x.FullName
            $h.FullName | Should -Be ([IO.Path]::ChangeExtension($x.FullName, '.html'))
            $h.Exists | Should -BeTrue
        }

        It 'Export-SystemSleepDiagnostics writes HTML, or fails loudly where Windows deprecated it' {
            try {
                $f = Export-SystemSleepDiagnostics -OutFile (Join-Path $script:out 'ssd.html') -ErrorAction Stop
                $f.Exists | Should -BeTrue
            }
            catch {
                $_.FullyQualifiedErrorId | Should -BeLike 'ReportNotCreated*'
                $_.Exception.Message | Should -BeLike '*powercfg said:*'
                Set-ItResult -Skipped -Because "powercfg /systemsleepdiagnostics is deprecated on this build: $($_.Exception.Message)"
            }
        }

        It 'Export-SRUMDB writes CSV by default' {
            $f = Export-SRUMDB -OutFile (Join-Path $script:out 'srum')
            $f.Extension | Should -Be '.csv'
            $f.Exists | Should -BeTrue
        }

        It 'resolves relative paths against $PWD, not the process directory' {
            Push-Location $script:out
            try {
                (Export-SystemPowerReport -OutFile 'rel.html' -Duration 1).DirectoryName | Should -Be $script:out.TrimEnd('\')
            }
            finally { Pop-Location }
        }
    }
}
