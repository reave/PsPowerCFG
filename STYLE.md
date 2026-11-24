# Code and documentation style

This module follows two guides:

- Code: the [PowerShell Practice and Style guide][ppas] (PoshCode). Where a page says `TODO` and
  links to a GitHub discussion, the consensus of that discussion is the rule.
- Documentation: the [PowerShell-Docs style guide][docs-style], its [editor's checklist][checklist],
  and [Markdown best practices][markdown]. These apply to `README.md`, this file, and
  comment-based help.

Where either guide conflicts with the project goals (Windows PowerShell 5.1 and PowerShell 7,
speed, P/Invoke and .NET over cmdlets, no behavior regressions), the goals win. Those cases are
listed under [Deviations](#deviations).

`PSScriptAnalyzerSettings.psd1` enforces the mechanical rules. `Tests/Invoke-StyleCheck.ps1` runs
the analyzer with those settings and works around intermittent analyzer crashes. The `Code style`
Pester test runs it when **PSScriptAnalyzer** is installed:

```powershell
pwsh.exe -NoProfile -File .\Tests\Invoke-StyleCheck.ps1
```

## Rules from finalized guide pages

| Rule | Source |
|---|---|
| One True Brace Style: `} else {`, `} catch {` | [Code layout][layout] |
| Four-space indentation, no tabs | [Code layout][layout] |
| Lines no longer than 115 characters | [Code layout][layout] |
| No `;` as a line terminator | [Code layout][layout] |
| `[CmdletBinding()]` on every function, blocks in `param`, `begin`, `process`, `end` order | [Function structure][function] |
| `[OutputType()]` on every function, `DefaultParameterSetName` when there are parameter sets | [Function structure][function] |
| No `return $value`: emit the value, then `return` | [Function structure][function] |
| Comment-based help inside the function, keywords in ALL CAPS | [Documentation][doc-comments] |
| Each parameter documented by a comment above its declaration, not `.PARAMETER` | [Documentation][doc-comments] |
| Every `.EXAMPLE` has an explanation | [Documentation][doc-comments], [editor's checklist][checklist] |
| Full command and parameter names, no aliases | [Naming conventions][naming] |
| PascalCase public names; two-letter acronyms uppercase (`PS`), longer ones Pascal (`Srum`, `Xml`, `Csv`) | [Code layout][layout] (Capitalization) |
| Native code wrapped in functions, with the reason documented (PURE-03, PURE-04) | [Building reusable tools][tools] |

The [Best Practices TODO][bp-todo] page is a draft, not a finalized page. Two of its rules are
adopted: no positional arguments in shared code, and `SupportsShouldProcess` on functions that
change state.

## Rules from TODO discussions

| Rule | Discussion | Consensus |
|---|---|---|
| Backtick line continuation only as a last resort. Prefer one line, then natural continuation after a pipe, comma, or operator, then splatting. | [#15][i15] ([Readability][readability] TODO) | Agreed in the thread; the Readability page is marked for rewrite on this basis. |
| Lowercase language keywords, PascalCase public names and parameters, camelCase locals, ALL CAPS help keywords | [#36][i36] | Agreed. Acronyms weren't settled, so the finalized .NET rule above applies. |
| A short noun prefix written into command names (`PowerScheme`, `PowerSetting`), not `DefaultCommandPrefix` | [#23][i23] | Leaning, no formal decision. |

## Documentation rules

From the PowerShell-Docs [editor's checklist][checklist] and [Markdown best practices][markdown]:

- Backticks for command names, variables, file paths, and literal values
- Bold for parameter, property, type, class, and module names; bold is semantic, not emphasis
- Lines wrapped at 100 characters, except tables and code
- ATX headings in sentence case, one H1, no skipped levels
- Fenced code blocks tagged `powershell` or `Output`
- Hyphens for bullets, `1.` for every numbered item
- Examples use full command and parameter names, splatting instead of backtick continuation

## Deviations

- **P/Invoke instead of cmdlets.** PURE-01 in [Building reusable tools][tools] prefers native
  PowerShell over .NET. The project goal is speed and language-independent output, so
  `powrprof.dll` is called directly. The reason is documented and every call is wrapped in a
  function, which satisfies PURE-03 and PURE-04.
- **Add-Type instead of a shipped binary.** The [Best Practices TODO][bp-todo] draft says to prefer
  **RequiredAssemblies** over `Add-Type`, and also to use `Add-Type` for small P/Invoke code.
  There's no code-signing certificate for a shipped DLL, so the module compiles with `Add-Type`
  and caches the DLL per user.
- **No DefaultParameterSetName on `Restore-DefaultPowerScheme`.** With neither **Guid** nor **All**,
  the call must fail to bind. A default set would prompt for **Guid** or fall through to the full
  reset.
- **Plural noun in `Export-SystemSleepDiagnostics`.** Kept for compatibility, because renaming
  breaks callers.
- **Commands without the `Power` noun prefix** (`Export-SystemPowerReport`, `Export-EnergyReport`,
  `Export-BatteryReport`, `Export-SrumDb`). Kept for compatibility.
- **Module and type names.** The .NET acronym rule would give `PSPowerCfg`. The module stays
  `PsPowerCFG` and the types stay `PsPowerCfg.*`, because renaming breaks imports and type
  references.
- **Long manifest `Description`.** Manifests allow only constant values, so the string can't be
  split. The style test excludes that one line.
- **`Write-Host` in tests.** It prints timing lines that `Write-Information` would hide in Pester
  output.
- **`Where-Object` and `ForEach-Object` in small module code paths.** PERF-03 in [Performance][perf]
  ranks language features above the pipeline. Hot paths use `foreach`. Short filters over a few
  items keep the cmdlets, with named parameters.
- **PSUseConsistentWhitespace CheckOperator off.** It flags the aligned hashtables the guide uses.

### Where the two guides differ

- **Example layout.** PlatyPS puts the explanation before the code. Comment-based help has no place
  for text before the code, so the explanation follows it, as the PoshCode guide shows.
- **Line length.** PoshCode allows 115 characters in code; PowerShell-Docs wants 100 in Markdown.
  Code uses 115 and Markdown uses 100.
- **Help sections.** PowerShell-Docs expects PlatyPS sections such as **INPUTS** and **OUTPUTS**
  even when the value is None. Comment-based help here lists only what applies, and `[OutputType()]`
  fills **OUTPUTS** in `Get-Help`.

[ppas]: https://poshcode.gitbook.io/powershell-practice-and-style
[docs-style]: https://learn.microsoft.com/powershell/scripting/community/contributing/powershell-style-guide
[checklist]: https://learn.microsoft.com/powershell/scripting/community/contributing/editorial-checklist
[markdown]: https://learn.microsoft.com/powershell/scripting/community/contributing/general-markdown
[layout]: https://github.com/PoshCode/PowerShellPracticeAndStyle/blob/master/Style-Guide/Code-Layout-and-Formatting.md
[function]: https://github.com/PoshCode/PowerShellPracticeAndStyle/blob/master/Style-Guide/Function-Structure.md
[doc-comments]: https://github.com/PoshCode/PowerShellPracticeAndStyle/blob/master/Style-Guide/Documentation-and-Comments.md
[readability]: https://github.com/PoshCode/PowerShellPracticeAndStyle/blob/master/Style-Guide/Readability.md
[perf]: https://github.com/PoshCode/PowerShellPracticeAndStyle/blob/master/Best-Practices/Performance.md
[bp-todo]: https://github.com/PoshCode/PowerShellPracticeAndStyle/blob/master/Best-Practices/TODO.md
[naming]: https://github.com/PoshCode/PowerShellPracticeAndStyle/blob/master/Style-Guide/Naming-Conventions.md
[tools]: https://github.com/PoshCode/PowerShellPracticeAndStyle/blob/master/Best-Practices/Building-Reusable-Tools.md
[i15]: https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/15
[i23]: https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/23
[i36]: https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/36
