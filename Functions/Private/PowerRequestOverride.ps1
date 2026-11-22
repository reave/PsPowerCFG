# Registry layout powercfg /requestsoverride uses (verified on Windows 11
# 26100): one subkey per caller type, one DWORD per caller name.
$script:PowerRequestOverrideKey = 'SYSTEM\CurrentControlSet\Control\Power\PowerRequestOverride'
$script:PowerRequestTypeBits = [ordered]@{ Display = 1; System = 2; AwayMode = 4; Execution = 8 }
