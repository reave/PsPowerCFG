# GUIDs of the schemes Windows ships. Used to tell built-in from custom
# schemes (Restore-DefaultPowerScheme backup, Remove-PowerScheme guard).
$script:BuiltInPowerSchemes = @(
    [guid]'381b4222-f694-41f0-9685-ff5bb260df2e'  # Balanced (SCHEME_BALANCED)
    [guid]'8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'  # High performance (SCHEME_MIN)
    [guid]'a1841308-3541-4fab-bc81-f71556f20b4a'  # Power saver (SCHEME_MAX)
    [guid]'e9a42b02-d5df-448d-aa00-03f14749eb61'  # Ultimate Performance
)
