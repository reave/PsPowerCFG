$Private = (Get-ChildItem -Path (Join-Path $PSScriptRoot 'Functions\Private') -Filter *.ps1)
$Public = (Get-ChildItem -Path (Join-Path $PSScriptRoot 'Functions\Public') -Filter *.ps1)


foreach ($function in $Public) {
    . $function.FullName
    Export-ModuleMember $function.BaseName
}

foreach ($function in $Private) {
    . $function.FullName
}