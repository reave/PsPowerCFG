#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
# Run under both editions:
#   powershell.exe -NoProfile -Command "Invoke-Pester .\Tests -Output Detailed"
#   pwsh.exe       -NoProfile -Command "Invoke-Pester .\Tests -Output Detailed"

BeforeDiscovery {
    # -Skip is evaluated during discovery, before any BeforeAll runs, so the
    # elevation check has to happen here.
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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
            'Export-SystemPowerReport', 'Export-SystemSleepDiagnostics', 'Export-SRUMDB')
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

Describe 'Scheme management' -Tag 'Mutating' {
    BeforeAll {
        $script:originalActive = [PsPowerCfg.PowerApi]::GetActiveScheme()
        $script:created = [System.Collections.Generic.List[guid]]::new()
        $script:tmp = Join-Path ([IO.Path]::GetTempPath()) ('PsPowerCFG-scheme-' + [guid]::NewGuid().ToString('N'))
        [void][IO.Directory]::CreateDirectory($script:tmp)
        $script:source = Get-ActivePowerScheme
    }
    AfterAll {
        [PsPowerCfg.PowerApi]::SetActiveScheme($script:originalActive)
        foreach ($g in $script:created) {
            try { [PsPowerCfg.PowerApi]::DeleteScheme($g) } catch { Write-Warning "cleanup: $($_.Exception.Message)" }
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
        $copy = Copy-PowerScheme -Guid $script:source.Guid -DestinationGuid $dest
        $script:created.Add($copy.Guid)
        $copy.Guid | Should -Be $dest
        $copy.Name | Should -Be $script:source.Name
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

    It 'Export-PowerScheme writes a .pow file' {
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
        $victim | Remove-PowerScheme -Confirm:$false
        (Get-PowerScheme).Guid | Should -Not -Contain $victim.Guid
    }

    It 'Restore-DefaultPowerScheme -WhatIf changes nothing' {
        $before = @((Get-PowerScheme).Guid | Sort-Object)
        Restore-DefaultPowerScheme -WhatIf
        @((Get-PowerScheme).Guid | Sort-Object) | Should -Be $before
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
