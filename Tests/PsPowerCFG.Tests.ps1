#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
# Run under both editions:
#   powershell.exe -NoProfile -Command "Invoke-Pester .\Tests -Output Detailed"
#   pwsh.exe       -NoProfile -Command "Invoke-Pester .\Tests -Output Detailed"

BeforeAll {
    $manifest = Join-Path $PSScriptRoot '..\PsPowerCFG.psd1'
    Import-Module $manifest -Force -ErrorAction Stop

    # Language-neutral ground truth: GUIDs from powercfg.exe output.
    $script:cliGuids = @(powercfg.exe /list | Select-String -Pattern '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' -AllMatches |
            ForEach-Object { [guid]$_.Matches[0].Value })
    $script:cliActive = [guid]((powercfg.exe /getactivescheme | Select-String -Pattern '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}').Matches[0].Value)
    $script:isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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
        $cmds | Should -Be (@('Export-SRUMDB', 'Export-SystemPowerReport', 'Export-SystemSleepDiagnostics', 'Get-ActivePowerScheme', 'Get-PowerScheme') | Sort-Object)
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

Describe 'Report functions' {
    BeforeAll {
        $script:out = Join-Path ([IO.Path]::GetTempPath()) ('PsPowerCFG-tests-' + [guid]::NewGuid().ToString('N'))
        [void][IO.Directory]::CreateDirectory($script:out)
    }
    AfterAll {
        Remove-Item -LiteralPath $script:out -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'not elevated' -Skip:($script:isAdmin) {
        It 'Export-SystemPowerReport throws ElevationRequired' {
            { Export-SystemPowerReport -OutFile (Join-Path $script:out 'x.html') } | Should -Throw -ErrorId 'ElevationRequired,Export-SystemPowerReport'
        }
    }

    Context 'elevated' -Skip:(-not $script:isAdmin) {
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

        It 'Export-SystemSleepDiagnostics writes HTML' {
            (Export-SystemSleepDiagnostics -OutFile (Join-Path $script:out 'ssd.html')).Exists | Should -BeTrue
        }

        It 'Export-SRUMDB writes CSV by default' {
            $f = Export-SRUMDB -OutFile (Join-Path $script:out 'srum')
            $f.Extension | Should -Be '.csv'
            $f.Exists | Should -BeTrue
        }

        It 'resolves relative paths against $PWD, not the process directory' {
            Push-Location $script:out
            try {
                (Export-SystemSleepDiagnostics -OutFile 'rel.html').DirectoryName | Should -Be $script:out.TrimEnd('\')
            }
            finally { Pop-Location }
        }
    }
}
