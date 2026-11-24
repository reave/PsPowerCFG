#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
# Run under both editions:
#   powershell.exe -NoProfile -Command "Invoke-Pester -Path .\Tests -Output Detailed"
#   pwsh.exe -NoProfile -Command "Invoke-Pester -Path .\Tests -Output Detailed"

# Write-Host prints the timing lines in Pester's output, where Write-Information
# would be hidden. $isAdmin, $runMutating, $hasAnalyzer and $queries are used by -Skip and
# -ForEach during discovery, which the analyzer cannot see.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeDiscovery {
    # -Skip is evaluated during discovery, before any BeforeAll runs, so the
    # elevation check has to happen here.
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    # Tests that create/activate/delete schemes only run when opted in.
    $runMutating = $env:PSPOWERCFG_MUTATING -eq '1'
    # The style test needs PSScriptAnalyzer, which is optional.
    $hasAnalyzer = [bool](Get-Module -ListAvailable -Name PSScriptAnalyzer)
}

BeforeAll {
    $manifest = Join-Path -Path $PSScriptRoot -ChildPath '..\PsPowerCFG.psd1'
    Import-Module -Name $manifest -Force -ErrorAction Stop

    # Language-neutral ground truth: GUIDs from powercfg.exe output.
    $script:guidPattern = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
    $script:cliGuids = @(powercfg.exe /list | Select-String -Pattern $script:guidPattern -AllMatches |
            ForEach-Object -Process { [guid]$_.Matches[0].Value })
    $activeLine = powercfg.exe /getactivescheme | Select-String -Pattern $script:guidPattern
    $script:cliActive = [guid]$activeLine.Matches[0].Value
}

AfterAll {
    Remove-Module -Name PsPowerCFG -ErrorAction SilentlyContinue
}

Describe 'Module' {
    It 'loads the native type' {
        'PsPowerCfg.PowerApi' -as [type] | Should -Not -BeNullOrEmpty
    }

    It 're-imports without recompiling or throwing' {
        $manifest = Join-Path -Path $PSScriptRoot -ChildPath '..\PsPowerCFG.psd1'
        { Import-Module -Name $manifest -Force -ErrorAction Stop } | Should -Not -Throw
    }

    It 'exports exactly the manifest functions' {
        $cmds = (Get-Command -Module PsPowerCFG -CommandType Function).Name | Sort-Object
        $expected = @(
            'Get-PowerScheme', 'Get-ActivePowerScheme', 'Set-ActivePowerScheme', 'Copy-PowerScheme',
            'Rename-PowerScheme', 'Remove-PowerScheme', 'Import-PowerScheme', 'Export-PowerScheme',
            'Restore-DefaultPowerScheme',
            'Export-SystemPowerReport', 'Export-SystemSleepDiagnostics', 'Export-SrumDb',
            'Get-PowerSetting', 'Set-PowerSetting', 'Set-PowerTimeout', 'Remove-PowerSetting',
            'Set-PowerSettingAttribute',
            'Get-PowerAlias', 'Get-PowerSecurityDescriptor', 'Set-PowerSecurityDescriptor',
            'Get-PowerCapability', 'Get-PowerDevice', 'Enable-PowerDeviceWake', 'Disable-PowerDeviceWake',
            'Get-PowerLastWake', 'Get-PowerHibernate', 'Set-PowerHibernate', 'Get-PowerBatteryState',
            'Export-EnergyReport', 'Export-BatteryReport', 'Export-PowerProvisioningXml',
            'Get-PowerRequest', 'Get-PowerWakeTimer',
            'Get-PowerRequestOverride', 'Set-PowerRequestOverride', 'Remove-PowerRequestOverride')
        $cmds | Should -Be ($expected | Sort-Object)
    }

    It 'exports names with the casing the manifest lists' {
        # Command names are case-insensitive, so the test above passes on case alone.
        # This one checks the casing users see in Get-Command and tab completion.
        $manifest = Import-PowerShellDataFile -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\PsPowerCFG.psd1')
        foreach ($name in $manifest.FunctionsToExport) {
            (Get-Command -Name $name -Module PsPowerCFG).Name | Should -BeExactly $name
        }
    }

    It 'keeps the Get-PowerSchemes alias' {
        (Get-Alias -Name Get-PowerSchemes).ResolvedCommandName | Should -Be 'Get-PowerScheme'
    }
}

Describe 'Code style' -Skip:(-not $hasAnalyzer) {
    It 'passes PSScriptAnalyzer with the repository settings' {
        $root = Join-Path -Path $PSScriptRoot -ChildPath '..'
        $settings = Join-Path -Path $root -ChildPath 'PSScriptAnalyzerSettings.psd1'
        $analyzerErrors = $null
        $analyzerParams = @{
            Path          = $root
            Recurse       = $true
            Settings      = $settings
            ErrorVariable = 'analyzerErrors'
            ErrorAction   = 'SilentlyContinue'
        }
        $findings = Invoke-ScriptAnalyzer @analyzerParams
        # The manifest Description must be one constant string, so its line stays long.
        $findings = @($findings | Where-Object -FilterScript {
                -not ($_.RuleName -eq 'PSAvoidLongLines' -and $_.ScriptName -eq 'PsPowerCFG.psd1')
            })
        $report = foreach ($f in $findings) { '{0}:{1} {2}' -f $f.ScriptName, $f.Line, $f.RuleName }
        $report | Should -BeNullOrEmpty
        # PSScriptAnalyzer 1.25 on PowerShell 7.7 sometimes fails inside its own command lookup
        # (NullReferenceException in PSProvideCommentHelp, or "Get-Command is not recognized").
        # The rule that failed checked nothing, so the result is inconclusive rather than a pass.
        if ($analyzerErrors) {
            $crashes = foreach ($e in $analyzerErrors) { '{0} ({1})' -f $e, $e.TargetObject }
            Set-ItResult -Inconclusive -Because ('analyzer errors: ' + ($crashes -join '; '))
        }
    }
}

Describe 'Get-PowerScheme' {
    It 'returns the same scheme GUIDs as powercfg /list' {
        $native = @((Get-PowerScheme).Guid | Sort-Object)
        $native | Should -Be @($script:cliGuids | Sort-Object)
    }

    It 'marks exactly one scheme active, matching powercfg /getactivescheme' {
        $active = @(Get-PowerScheme | Where-Object -Property IsActive)
        $active.Count | Should -Be 1
        $active[0].Guid | Should -Be $script:cliActive
    }

    It 'returns non-empty names' {
        Get-PowerScheme | ForEach-Object -Process { $_.Name | Should -Not -BeNullOrEmpty }
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
        Write-Host -Object ('    Get-PowerScheme x100: {0} ms' -f $sw.ElapsedMilliseconds)
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
        $tmpName = 'PsPowerCFG-scheme-' + [guid]::NewGuid().ToString('N')
        $script:tmp = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath $tmpName
        [void][IO.Directory]::CreateDirectory($script:tmp)
        $script:source = Get-ActivePowerScheme
    }
    AfterAll {
        [PsPowerCfg.PowerApi]::SetActiveScheme($script:originalActive)
        $builtIn = @(
            [guid]'381b4222-f694-41f0-9685-ff5bb260df2e', [guid]'8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c',
            [guid]'a1841308-3541-4fab-bc81-f71556f20b4a', [guid]'e9a42b02-d5df-448d-aa00-03f14749eb61')
        # Only ever delete schemes this suite named; never a built-in GUID.
        $leftovers = [PsPowerCfg.PowerApi]::GetSchemes() | Where-Object -FilterScript {
            $_.Name -like 'PsPowerCFG*' -and $builtIn -notcontains $_.Guid -and $_.Guid -ne $script:originalActive
        }
        foreach ($s in $leftovers) {
            try {
                [PsPowerCfg.PowerApi]::DeleteScheme($s.Guid)
            } catch {
                Write-Warning -Message "cleanup $($s.Name): $($_.Exception.Message)"
            }
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
        $active = (Get-ActivePowerScheme).Guid
        Remove-PowerScheme -Guid $active -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
        $err[0].FullyQualifiedErrorId | Should -BeLike 'PowerSchemeIsActive*'
    }

    It 'Remove-PowerScheme -WhatIf deletes nothing' {
        Remove-PowerScheme -Guid $script:created[0] -WhatIf
        (Get-PowerScheme).Guid | Should -Contain $script:created[0]
    }

    It 'Export-PowerScheme writes a .pow file' -Skip:(-not $isAdmin) {
        $f = Export-PowerScheme -Guid $script:created[0] -Path (Join-Path -Path $script:tmp -ChildPath 'x.pow')
        $f | Should -BeOfType [IO.FileInfo]
        $f.Length | Should -BeGreaterThan 0
    }

    It 'Import-PowerScheme round-trips an export' -Skip:(-not $isAdmin) {
        $pow = Join-Path -Path $script:tmp -ChildPath 'x.pow'
        $s = Import-PowerScheme -Path $pow -NewName 'PsPowerCFG imported'
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
        $pow = Join-Path -Path $script:tmp -ChildPath 'n.pow'
        { Export-PowerScheme -Guid $script:source.Guid -Path $pow } |
            Should -Throw -ErrorId 'ElevationRequired,Export-PowerScheme'
        { Restore-DefaultPowerScheme -All -WhatIf } |
            Should -Throw -ErrorId 'ElevationRequired,Restore-DefaultPowerScheme'
    }

    It 'Remove-PowerScheme refuses a built-in scheme without -Force' {
        $builtInGuids = @(
            [guid]'381b4222-f694-41f0-9685-ff5bb260df2e'
            [guid]'8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
            [guid]'a1841308-3541-4fab-bc81-f71556f20b4a'
        )
        $builtIn = Get-PowerScheme |
            Where-Object -FilterScript { -not $_.IsActive -and $_.Guid -in $builtInGuids } |
            Select-Object -First 1
        if (-not $builtIn) { Set-ItResult -Skipped -Because 'no inactive built-in scheme'; return }
        Remove-PowerScheme -Guid $builtIn.Guid -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
        $err[0].FullyQualifiedErrorId | Should -BeLike 'PowerSchemeIsBuiltIn*'
        (Get-PowerScheme).Guid | Should -Contain $builtIn.Guid
    }

    It 'Restore-DefaultPowerScheme requires -All for the full reset' {
        $sets = (Get-Command -Name Restore-DefaultPowerScheme).ParameterSets.Name
        $sets | Should -Not -Contain '__AllParameterSets'
        { Restore-DefaultPowerScheme -Confirm:$false -ErrorAction Stop } | Should -Throw
    }

    It 'Restore-DefaultPowerScheme -All -WhatIf changes nothing and writes no backup' -Skip:(-not $isAdmin) {
        $before = @((Get-PowerScheme).Guid | Sort-Object)
        $out = Restore-DefaultPowerScheme -All -BackupPath (Join-Path -Path $script:tmp -ChildPath 'bk') -WhatIf
        $out | Should -BeNullOrEmpty
        Test-Path -Path (Join-Path -Path $script:tmp -ChildPath 'bk') | Should -BeFalse
        @((Get-PowerScheme).Guid | Sort-Object) | Should -Be $before
    }
}

Describe 'Get-PowerAlias' {
    It 'loads the alias table' {
        @(Get-PowerAlias).Count | Should -BeGreaterThan 150
    }
    It 'classifies subgroups and settings' {
        (Get-PowerAlias -Name SUB_SLEEP).Kind | Should -Be 'Subgroup'
        $s = Get-PowerAlias -Name STANDBYIDLE
        $s.Kind | Should -Be 'Setting'
        $s.SubgroupGuid | Should -Be ([guid]'238c9fa8-0aad-41ed-83f4-97be242c8f20')
    }
    It 'matches every alias powercfg /aliases prints' {
        $cli = powercfg.exe /aliases | ForEach-Object -Process {
            if ($_ -match '^\s*([0-9a-f-]{36})\s+(\S+)\s*$') {
                [pscustomobject]@{ Guid = [guid]$Matches[1]; Alias = $Matches[2] }
            }
        }
        $ours = @{}
        Get-PowerAlias | ForEach-Object -Process { $ours[$_.Alias] = $_.Guid }
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
        $visible | ForEach-Object -Process { $_.IsHidden | Should -BeFalse }
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
        $balanced = [guid]'381b4222-f694-41f0-9685-ff5bb260df2e'
        (Get-PowerSetting -Scheme SCHEME_BALANCED -Setting STANDBYIDLE).SchemeGuid | Should -Be $balanced
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
        $timing = '    Get-PowerSetting -IncludeHidden: {0} ms ({1} settings); powercfg /qh: {2} ms' -f
        $sw.ElapsedMilliseconds, $script:all.Count, $cliSw.ElapsedMilliseconds
        Write-Host -Object $timing
        $sw.ElapsedMilliseconds | Should -BeLessThan 5000
    }
}

Describe 'Get-PowerSecurityDescriptor' {
    It 'matches powercfg /getsecuritydescriptor for <_>' -ForEach @(
        'ActionSetActive'
        'ActionCreate'
        'ActionDefault'
    ) {
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
        $leftovers = Get-PowerScheme |
            Where-Object -FilterScript { $_.Name -like 'PsPowerCFG*' -and $_.Guid -ne $script:originalActive }
        foreach ($s in $leftovers) {
            try {
                [PsPowerCfg.PowerApi]::DeleteScheme($s.Guid)
            } catch {
                Write-Warning -Message $_.Exception.Message
            }
        }
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
        { Set-PowerSetting -Scheme $script:copy.Guid -Setting PBUTTONACTION -AcValue 999 } |
            Should -Throw -ErrorId 'PowerSettingValueOutOfRange,Set-PowerSetting'
        $after = Get-PowerSetting -Scheme $script:copy.Guid -Subgroup SUB_BUTTONS -Setting PBUTTONACTION
        $after.AcValue | Should -Be $s.AcValue
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
        } finally {
            Set-PowerSettingAttribute -Setting PERFBOOSTMODE -Hidden $was
        }
        (Get-PowerSetting -Setting PERFBOOSTMODE -IncludeHidden).IsHidden | Should -Be $was
    }

    It 'Remove-PowerSetting refuses built-in settings without -Force' -Skip:(-not $isAdmin) {
        $removeParams = @{
            Subgroup      = 'SUB_SLEEP'
            Setting       = 'STANDBYIDLE'
            Confirm       = $false
            ErrorVariable = 'err'
            ErrorAction   = 'SilentlyContinue'
        }
        Remove-PowerSetting @removeParams
        $err[0].FullyQualifiedErrorId | Should -BeLike 'PowerSettingIsBuiltIn*'
        (Get-PowerSetting -Setting STANDBYIDLE) | Should -Not -BeNullOrEmpty
    }

    It 'Set-PowerSecurityDescriptor rejects invalid SDDL and honors -WhatIf' -Skip:(-not $isAdmin) {
        $before = (Get-PowerSecurityDescriptor -Action ActionSetActive).Sddl
        $quiet = @{ ErrorVariable = 'err'; ErrorAction = 'SilentlyContinue' }
        Set-PowerSecurityDescriptor -Action ActionSetActive -Sddl 'not sddl' @quiet
        $err[0].FullyQualifiedErrorId | Should -BeLike 'InvalidSddl*'
        Set-PowerSecurityDescriptor -Action ActionSetActive -Sddl 'O:BAG:SYD:P(A;CI;KA;;;BA)' -WhatIf
        (Get-PowerSecurityDescriptor -Action ActionSetActive).Sddl | Should -Be $before
    }
}

Describe 'Error reporting' {
    # A .NET exception caught inside a function still lands in the caller's
    # -ErrorVariable, so native failures must not throw into PowerShell code.
    It 'writes exactly one error for a native failure (Set-ActivePowerScheme)' {
        $quiet = @{ ErrorVariable = 'err'; ErrorAction = 'SilentlyContinue' }
        Set-ActivePowerScheme -Guid ([guid]::NewGuid()) -Confirm:$false @quiet
        $err.Count | Should -Be 1
        $err[0].FullyQualifiedErrorId | Should -BeLike 'SetActivePowerSchemeFailed*'
    }
    It 'writes exactly one error for a native failure (Get-PowerSetting)' {
        Get-PowerSetting -Scheme ([guid]::NewGuid().ToString()) -ErrorVariable err -ErrorAction SilentlyContinue
        $err.Count | Should -Be 1
    }
}

Describe 'Get-PowerCapability' {
    BeforeAll {
        $script:caps = Get-PowerCapability
        $script:cliA = (powercfg.exe /availablesleepstates | Out-String)
        # The available block runs from the first line up to the
        # "not available" header. English output only.
        $script:english = $script:cliA -match 'sleep states are available'
        if ($script:english) {
            $script:available = ($script:cliA -split 'sleep states are not available')[0]
        }
    }
    It 'returns the full SYSTEM_POWER_CAPABILITIES buffer' {
        $script:caps | Should -BeOfType ([PsPowerCfg.PowerCapabilities])
        $script:caps.Raw.Length | Should -Be 76
    }
    It 'reports HiberFilePresent the same as the file system' {
        $file = [IO.Path]::Combine($env:SystemDrive + '\', 'hiberfil.sys')
        $script:caps.HiberFilePresent | Should -Be ([IO.File]::Exists($file))
    }
    It 'agrees with powercfg /availablesleepstates on <Label>' -ForEach @(
        @{ Label = 'S1'; Property = 'StandbyS1'; Pattern = 'S1' }
        @{ Label = 'S2'; Property = 'StandbyS2'; Pattern = 'S2' }
        @{ Label = 'S3'; Property = 'StandbyS3'; Pattern = 'S3' }
        @{ Label = 'S0 low power idle'; Property = 'StandbyS0LowPowerIdle'; Pattern = 'S0 Low Power Idle' }
        @{ Label = 'Hybrid sleep'; Property = 'HybridSleep'; Pattern = 'Hybrid Sleep' }
        @{ Label = 'Fast startup'; Property = 'FastStartup'; Pattern = 'Fast Startup' }
    ) {
        if (-not $script:english) { Set-ItResult -Skipped -Because 'powercfg output is not English'; return }
        $expected = $script:available -match $Pattern
        $script:caps.$Property | Should -Be $expected -Because "powercfg /a said:`n$script:cliA"
    }
    It 'agrees with powercfg /availablesleepstates on Hibernate (supported and turned on)' {
        if (-not $script:english) { Set-ItResult -Skipped -Because 'powercfg output is not English'; return }
        $ours = $script:caps.HibernateSupported -and (Get-PowerHibernate).Enabled
        $expected = $script:available -match '(?m)^\s*Hibernate'
        $ours | Should -Be $expected -Because "powercfg /a said:`n$script:cliA"
    }
}

Describe 'Get-PowerBatteryState' {
    It 'returns a state that agrees with the capabilities on battery presence' {
        $b = Get-PowerBatteryState
        $b | Should -BeOfType ([PsPowerCfg.PowerBatteryState])
        $b.BatteryPresent | Should -Be (Get-PowerCapability).SystemBatteriesPresent
        if (-not $b.BatteryPresent) { $b.Percent | Should -BeNullOrEmpty }
    }
}

Describe 'Get-PowerDevice' {
    BeforeDiscovery {
        $queries = @(
            @{ Query = 'WakeFromS1Supported'; Flag = 'wake_from_S1_supported' }
            @{ Query = 'WakeFromS2Supported'; Flag = 'wake_from_S2_supported' }
            @{ Query = 'WakeFromS3Supported'; Flag = 'wake_from_S3_supported' }
            @{ Query = 'WakeFromAny'; Flag = 'wake_from_any' }
            @{ Query = 'S1Supported'; Flag = 'S1_supported' }
            @{ Query = 'S2Supported'; Flag = 'S2_supported' }
            @{ Query = 'S3Supported'; Flag = 'S3_supported' }
            @{ Query = 'S4Supported'; Flag = 'S4_supported' }
            @{ Query = 'WakeProgrammable'; Flag = 'wake_programmable' }
            @{ Query = 'WakeArmed'; Flag = 'wake_armed' }
            @{ Query = 'AllDevices'; Flag = 'all_devices' }
        )
    }
    It 'matches powercfg /devicequery <Flag>' -ForEach $queries {
        $cli = @(powercfg.exe /devicequery $Flag |
                ForEach-Object -Process { $_.Trim() } |
                Where-Object -FilterScript { $_ -and $_ -ne 'NONE' })
        if ($LASTEXITCODE -ne 0) { Set-ItResult -Skipped -Because "powercfg failed: $cli"; return }
        # powercfg pads some names with trailing spaces; the API returns
        # them the same way, so trim both sides before comparing.
        $ours = @(Get-PowerDevice -Query $Query |
                ForEach-Object -Process { $_.Name.Trim() } |
                Where-Object -FilterScript { $_ })
        ($ours | Sort-Object) -join "`n" | Should -Be (($cli | Sort-Object) -join "`n")
    }
    It 'marks armed devices as programmable' {
        foreach ($d in Get-PowerDevice -Query WakeArmed) {
            $d.WakeArmed | Should -BeTrue
            $d.WakeProgrammable | Should -BeTrue -Because $d.Name
        }
    }
    It 'Enable-PowerDeviceWake throws ElevationRequired when not elevated' -Skip:$isAdmin {
        { Enable-PowerDeviceWake -Name 'x' } | Should -Throw -ErrorId 'ElevationRequired,Enable-PowerDeviceWake'
    }
    It 'Disable-PowerDeviceWake -WhatIf changes nothing' -Skip:(-not $isAdmin) {
        $armed = @(Get-PowerDevice -Query WakeArmed)
        if (-not $armed.Count) { Set-ItResult -Skipped -Because 'no wake-armed devices'; return }
        $armed[0] | Disable-PowerDeviceWake -WhatIf
        (Get-PowerDevice -Query WakeArmed | ForEach-Object -MemberName Name) | Should -Contain $armed[0].Name
    }
    It 'reports a missing device as PowerDeviceNotFound' -Skip:(-not $isAdmin) {
        $quiet = @{ ErrorVariable = 'err'; ErrorAction = 'SilentlyContinue' }
        Disable-PowerDeviceWake -Name 'PsPowerCFG no such device' -Confirm:$false @quiet
        $err.Count | Should -Be 1
        $err[0].FullyQualifiedErrorId | Should -BeLike 'PowerDeviceNotFound*'
    }
}

Describe 'Device wake changes' -Tag 'Mutating' -Skip:(-not ($runMutating -and $isAdmin)) {
    It 'disarms and re-arms a wake-armed device (verified with powercfg)' {
        $armed = @(Get-PowerDevice -Query WakeArmed)
        if (-not $armed.Count) { Set-ItResult -Skipped -Because 'no wake-armed devices'; return }
        $name = $armed[0].Name
        $armedNow = { @(powercfg.exe /devicequery wake_armed | ForEach-Object -Process { $_.Trim() }) }
        try {
            $d = Disable-PowerDeviceWake -Name $name -Confirm:$false -PassThru -ErrorAction Stop
            $d.WakeArmed | Should -BeFalse
            & $armedNow | Should -Not -Contain $name
        } finally {
            Enable-PowerDeviceWake -Name $name -Confirm:$false -ErrorAction SilentlyContinue
            if ((& $armedNow) -notcontains $name) {
                powercfg.exe /deviceenableawake $name | Out-Null
            }
        }
        & $armedNow | Should -Contain $name
    }
}

Describe 'Get-PowerLastWake' {
    It 'returns the newest Power-Troubleshooter wake event' {
        $ours = @(Get-PowerLastWake)
        $filter = @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Power-Troubleshooter'; Id = 1 }
        $theirs = @(Get-WinEvent -FilterHashtable $filter -MaxEvents 1 -ErrorAction SilentlyContinue)
        $ours.Count | Should -Be $theirs.Count
        if (-not $theirs.Count) { Set-ItResult -Skipped -Because 'no wake events in the System log'; return }
        $ours[0].PSObject.TypeNames | Should -Contain 'PsPowerCfg.PowerWakeEvent'
        $ours[0].TimeCreated | Should -Be $theirs[0].TimeCreated
        $ours[0].WakeTime | Should -Not -BeNullOrEmpty
        $ours[0].WakeTime | Should -BeGreaterOrEqual $ours[0].SleepTime
    }
    It 'returns -Count events newest first' {
        $events = @(Get-PowerLastWake -Count 3)
        $events.Count | Should -BeLessOrEqual 3
        for ($i = 1; $i -lt $events.Count; $i++) {
            $events[$i - 1].TimeCreated | Should -BeGreaterOrEqual $events[$i].TimeCreated
        }
    }
}

Describe 'Hibernate' {
    It 'Get-PowerHibernate agrees with the file system' {
        $h = Get-PowerHibernate
        $file = [IO.Path]::Combine($env:SystemDrive + '\', 'hiberfil.sys')
        $h.HiberFilePresent | Should -Be ([IO.File]::Exists($file))
        if ($h.HiberFilePresent) { $h.HiberFileSize | Should -BeGreaterThan 0 }
    }
    It 'Set-PowerHibernate throws ElevationRequired when not elevated' -Skip:$isAdmin {
        { Set-PowerHibernate -Disable } | Should -Throw -ErrorId 'ElevationRequired,Set-PowerHibernate'
    }
    It 'Set-PowerHibernate -WhatIf changes nothing' -Skip:(-not $isAdmin) {
        $before = Get-PowerHibernate
        if ($before.Enabled) { Set-PowerHibernate -Disable -WhatIf } else { Set-PowerHibernate -Enable -WhatIf }
        (Get-PowerHibernate).Enabled | Should -Be $before.Enabled
    }
}

Describe 'Power requests and wake timers' {
    Context 'not elevated' -Skip:$isAdmin {
        It '<Command> throws ElevationRequired' -ForEach @(
            @{ Command = 'Get-PowerRequest' }
            @{ Command = 'Get-PowerWakeTimer' }
        ) {
            { & $Command } | Should -Throw -ErrorId "ElevationRequired,$Command"
        }
    }

    Context 'elevated' -Skip:(-not $isAdmin) {
        BeforeAll {
            # Test-only helpers: hold a power request and a resumable timer
            # in this process so there is something known to find.
            Add-Type -Namespace PsPowerCfgTest -Name Native -MemberDefinition @'
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct REASON_CONTEXT { public uint Version; public uint Flags; public string SimpleReasonString; }
[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr PowerCreateRequest(ref REASON_CONTEXT c);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool PowerSetRequest(IntPtr h, int t);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool PowerClearRequest(IntPtr h, int t);
[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern IntPtr CreateWaitableTimerW(IntPtr a, bool manualReset, string name);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool SetWaitableTimer(IntPtr h, ref long due, int period, IntPtr r, IntPtr a, bool resume);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool CancelWaitableTimer(IntPtr h);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool CloseHandle(IntPtr h);
'@
            $script:exe = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
            $script:reason = 'PsPowerCFG test ' + [guid]::NewGuid().ToString('N').Substring(0, 8)
            $ctx = New-Object -TypeName PsPowerCfgTest.Native+REASON_CONTEXT
            $ctx.Version = 0; $ctx.Flags = 1; $ctx.SimpleReasonString = $script:reason
            $script:request = [PsPowerCfgTest.Native]::PowerCreateRequest([ref]$ctx)
            [void][PsPowerCfgTest.Native]::PowerSetRequest($script:request, 0)   # Display
            [void][PsPowerCfgTest.Native]::PowerSetRequest($script:request, 1)   # System

            $script:timer = [PsPowerCfgTest.Native]::CreateWaitableTimerW([IntPtr]::Zero, $true, $null)
            $due = -72000000000L   # 2 hours, relative
            $script:timerDue = [datetime]::Now.AddHours(2)
            $zero = [IntPtr]::Zero
            [void][PsPowerCfgTest.Native]::SetWaitableTimer($script:timer, [ref]$due, 0, $zero, $zero, $true)
        }
        AfterAll {
            foreach ($t in 0, 1) { [void][PsPowerCfgTest.Native]::PowerClearRequest($script:request, $t) }
            [void][PsPowerCfgTest.Native]::CloseHandle($script:request)
            [void][PsPowerCfgTest.Native]::CancelWaitableTimer($script:timer)
            [void][PsPowerCfgTest.Native]::CloseHandle($script:timer)
        }

        It 'Get-PowerRequest finds this process''s display and system requests with their reason' {
            $mine = @(Get-PowerRequest | Where-Object -FilterScript { $_.Reason -eq $script:reason })
            ($mine.Type | Sort-Object) -join ',' | Should -Be 'Display,System'
            foreach ($r in $mine) {
                $r.CallerType | Should -Be 'Process'
                $r.Path | Should -Be $script:exe
            }
        }
        It 'Get-PowerRequest -Type filters' {
            $isMine = { $_.Reason -eq $script:reason }
            @(Get-PowerRequest -Type System | Where-Object -FilterScript $isMine).Count | Should -Be 1
            @(Get-PowerRequest -Type AwayMode | Where-Object -FilterScript $isMine).Count | Should -Be 0
        }
        It 'Get-PowerWakeTimer finds this process''s timer' {
            $mine = @(Get-PowerWakeTimer | Where-Object -FilterScript { $_.Path -eq $script:exe })
            $unparsed = @(Get-PowerWakeTimer | Where-Object -FilterScript { -not $_.OwnerType })
            if (-not $mine.Count -and $unparsed.Count) {
                Set-ItResult -Skipped -Because 'powercfg output is not English'; return
            }
            $mine.Count | Should -BeGreaterOrEqual 1
            $mine[0].OwnerType | Should -Be 'Process'
            [math]::Abs(($mine[0].Expires - $script:timerDue).TotalMinutes) | Should -BeLessThan 3
        }
    }
}

Describe 'Request overrides' {
    BeforeAll {
        function script:Get-CliOverride {
            [CmdletBinding()]
            [OutputType([string])]
            param()

            $known = 'DISPLAY', 'SYSTEM', 'AWAYMODE', 'EXECUTION'
            $section = $null
            foreach ($line in powercfg.exe /requestsoverride) {
                if ($line -match '^\[(SERVICE|PROCESS|DRIVER)\]$') { $section = $Matches[1]; continue }
                if (-not $line.Trim() -or -not $section) { continue }
                $tokens = [Collections.Generic.List[string]]($line.Trim() -split ' ')
                $types = [Collections.Generic.List[string]]::new()
                while ($tokens.Count -gt 1 -and $known -contains $tokens[$tokens.Count - 1]) {
                    $types.Insert(0, $tokens[$tokens.Count - 1]); $tokens.RemoveAt($tokens.Count - 1)
                }
                '{0}|{1}|{2}' -f $section, ($tokens -join ' '), ($types -join ' ')
            }
        }
        function script:Get-OurOverride {
            [CmdletBinding()]
            [OutputType([string])]
            param()

            foreach ($o in Get-PowerRequestOverride) {
                $types = foreach ($request in $o.Request) { $request.ToUpperInvariant() }
                '{0}|{1}|{2}' -f $o.CallerType.ToUpperInvariant(), $o.Name, ($types -join ' ')
            }
        }
    }
    It 'Get-PowerRequestOverride matches powercfg /requestsoverride' {
        $expected = (@(Get-CliOverride) | Sort-Object) -join "`n"
        (@(Get-OurOverride) | Sort-Object) -join "`n" | Should -Be $expected
    }
    It 'Set-PowerRequestOverride throws ElevationRequired when not elevated' -Skip:$isAdmin {
        { Set-PowerRequestOverride -CallerType Process -Name x.exe -Request Display } |
            Should -Throw -ErrorId 'ElevationRequired,Set-PowerRequestOverride'
    }
    It 'Set-PowerRequestOverride -WhatIf writes nothing' -Skip:(-not $isAdmin) {
        Set-PowerRequestOverride -CallerType Process -Name 'PsPowerCFG-whatif.exe' -Request Display -WhatIf
        Get-PowerRequestOverride -Name 'PsPowerCFG-whatif.exe' | Should -BeNullOrEmpty
    }
}

Describe 'Request override changes' -Tag 'Mutating' -Skip:(-not ($runMutating -and $isAdmin)) {
    BeforeAll { $script:fake = 'PsPowerCFG-test.exe' }
    AfterAll {
        if (Get-PowerRequestOverride -CallerType Process -Name $script:fake) {
            powercfg.exe /requestsoverride process $script:fake | Out-Null
        }
    }
    It 'sets, replaces and removes an override on a fake process (verified with powercfg)' {
        $fake = @{ CallerType = 'Process'; Name = $script:fake }
        $o = Set-PowerRequestOverride @fake -Request Display, Execution -Confirm:$false -PassThru
        $o.Mask | Should -Be 9
        $line = "(?m)^$([regex]::Escape($script:fake)) DISPLAY EXECUTION\s*$"
        (powercfg.exe /requestsoverride | Out-String) | Should -Match $line

        (Set-PowerRequestOverride @fake -Request System -Confirm:$false -PassThru).Request | Should -Be 'System'

        Remove-PowerRequestOverride -CallerType Process -Name $script:fake -Confirm:$false
        Get-PowerRequestOverride -CallerType Process -Name $script:fake | Should -BeNullOrEmpty
        (powercfg.exe /requestsoverride | Out-String) | Should -Not -Match ([regex]::Escape($script:fake))
    }
    It 'Remove-PowerRequestOverride reports a missing override once' {
        $quiet = @{ ErrorVariable = 'err'; ErrorAction = 'SilentlyContinue' }
        Remove-PowerRequestOverride -CallerType Process -Name 'PsPowerCFG-none.exe' -Confirm:$false @quiet
        $err.Count | Should -Be 1
        $err[0].FullyQualifiedErrorId | Should -BeLike 'PowerRequestOverrideNotFound*'
    }
}

Describe 'Export-BatteryReport' {
    BeforeAll {
        $tmpName = 'PsPowerCFG-tests-' + [guid]::NewGuid().ToString('N')
        $script:bout = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath $tmpName
        [void][IO.Directory]::CreateDirectory($script:bout)
    }
    AfterAll {
        Remove-Item -LiteralPath $script:bout -Recurse -Force -ErrorAction SilentlyContinue
    }
    It 'writes XML and reformats it to HTML' {
        try {
            $path = Join-Path -Path $script:bout -ChildPath 'battery'
            $x = Export-BatteryReport -FormatXml -OutFile $path -ErrorAction Stop
        } catch {
            $noBattery = -not (Get-PowerCapability).SystemBatteriesPresent
            if ($_.FullyQualifiedErrorId -like 'PowerCfgFailed*' -and $noBattery) {
                Set-ItResult -Skipped -Because "no battery: $($_.Exception.Message)"; return
            }
            throw
        }
        $x.Extension | Should -Be '.xml'
        $h = Export-BatteryReport -ReformatXml -FilePath $x.FullName
        $h.Extension | Should -Be '.html'
        $h.Exists | Should -BeTrue
    }
}

Describe 'Report functions' {
    BeforeAll {
        $tmpName = 'PsPowerCFG-tests-' + [guid]::NewGuid().ToString('N')
        $script:out = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath $tmpName
        [void][IO.Directory]::CreateDirectory($script:out)
    }
    AfterAll {
        Remove-Item -LiteralPath $script:out -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'not elevated' -Skip:$isAdmin {
        It 'Export-SystemPowerReport throws ElevationRequired' {
            $path = Join-Path -Path $script:out -ChildPath 'x.html'
            { Export-SystemPowerReport -OutFile $path } |
                Should -Throw -ErrorId 'ElevationRequired,Export-SystemPowerReport'
        }
    }

    Context 'elevated' -Skip:(-not $isAdmin) {
        It 'Export-SystemPowerReport writes HTML and returns FileInfo' {
            $f = Export-SystemPowerReport -OutFile (Join-Path -Path $script:out -ChildPath 'spr') -Duration 1
            $f | Should -BeOfType [IO.FileInfo]
            $f.Extension | Should -Be '.html'
            $f.Exists | Should -BeTrue
        }

        It 'Export-SystemPowerReport XML round-trips through -ReformatXml' {
            $path = Join-Path -Path $script:out -ChildPath 'spr.xml'
            $x = Export-SystemPowerReport -FormatXml -OutFile $path -Duration 1
            $x.Extension | Should -Be '.xml'
            $h = Export-SystemPowerReport -ReformatXml -FilePath $x.FullName
            $h.FullName | Should -Be ([IO.Path]::ChangeExtension($x.FullName, '.html'))
            $h.Exists | Should -BeTrue
        }

        It 'Export-SystemSleepDiagnostics writes HTML, or fails loudly where Windows deprecated it' {
            try {
                $path = Join-Path -Path $script:out -ChildPath 'ssd.html'
                $f = Export-SystemSleepDiagnostics -OutFile $path -ErrorAction Stop
                $f.Exists | Should -BeTrue
            } catch {
                $_.FullyQualifiedErrorId | Should -BeLike 'ReportNotCreated*'
                $_.Exception.Message | Should -BeLike '*powercfg said:*'
                $because = "powercfg /systemsleepdiagnostics is deprecated on this build: $($_.Exception.Message)"
                Set-ItResult -Skipped -Because $because
            }
        }

        It 'Export-SrumDb writes CSV by default' {
            $f = Export-SrumDb -OutFile (Join-Path -Path $script:out -ChildPath 'srum')
            $f.Extension | Should -Be '.csv'
            $f.Exists | Should -BeTrue
        }

        It 'Export-EnergyReport writes HTML' {
            $f = Export-EnergyReport -OutFile (Join-Path -Path $script:out -ChildPath 'energy') -Duration 5
            $f.Extension | Should -Be '.html'
            $f.Exists | Should -BeTrue
        }

        It 'Export-PowerProvisioningXml writes XML with the given name' {
            $path = Join-Path -Path $script:out -ChildPath 'pxml'
            $f = Export-PowerProvisioningXml -OutFile $path -Name 'PsPowerCFG.Test' -Version '1.2'
            $f.Extension | Should -Be '.xml'
            $x = [xml][IO.File]::ReadAllText($f.FullName)
            $x.OuterXml | Should -Match 'PsPowerCFG\.Test'
        }

        It 'resolves relative paths against $PWD, not the process directory' {
            Push-Location -Path $script:out
            try {
                $f = Export-SystemPowerReport -OutFile 'rel.html' -Duration 1
                $f.DirectoryName | Should -Be $script:out.TrimEnd('\')
            } finally { Pop-Location }
        }
    }
}
