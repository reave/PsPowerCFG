function Get-PowerLastWake {
    <#
    .SYNOPSIS
        Reports what woke the system from sleep. Counterpart of powercfg /lastwake.
    .DESCRIPTION
        Reads the "system has returned from a low power state" events (ID 1 from
        Microsoft-Windows-Power-Troubleshooter) in the System log, newest first,
        through wevtapi. Each event records the sleep and wake times and the wake
        source.

        powercfg /lastwake reads a kernel wake-history information class that has
        no public documentation, so this uses the event log instead. Two
        differences follow: wakes the log has rolled over are gone, and a boot
        with no sleep since shows the last wake before that boot, where powercfg
        shows an empty history.
    .EXAMPLE
        Get-PowerLastWake

        Shows the most recent wake: when the system slept, when it woke, and the wake source.
    .EXAMPLE
        Get-PowerLastWake -Count 10 | Format-Table -Property WakeTime, WakeSourceText

        Lists the last ten wakes as a table of wake time and source.
    .OUTPUTS
        PsPowerCfg.PowerWakeEvent
    #>
    [CmdletBinding()]
    [OutputType('PsPowerCfg.PowerWakeEvent')]
    param(
        # How many wake events to return, newest first. Default 1.
        [ValidateRange(1, 10000)]
        [int]$Count = 1
    )

    $xpath = "*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]"
    $r = [PsPowerCfg.Safe]::QueryEventLog('System', $xpath, $Count)
    if ($r.Failed) {
        $record = New-NativeErrorRecord -Result $r -ErrorId 'GetPowerLastWakeFailed' -TargetObject 'System'
        $PSCmdlet.WriteError($record)
        return
    }

    $invariant = [System.Globalization.CultureInfo]::InvariantCulture
    $roundtrip = [System.Globalization.DateTimeStyles]::RoundtripKind
    foreach ($xmlText in $r.Value) {
        # XPath rather than dot-notation: under strict mode a missing element
        # would throw.
        $doc = [xml]$xmlText
        $ns = [System.Xml.XmlNamespaceManager]::new($doc.NameTable)
        $ns.AddNamespace('e', 'http://schemas.microsoft.com/win/2004/08/events/event')
        $data = [ordered]@{}
        foreach ($node in $doc.SelectNodes('/e:Event/e:EventData/e:Data', $ns)) {
            $key = $node.GetAttribute('Name')
            if ($key) { $data[$key] = $node.InnerText }
        }
        $created = $doc.SelectSingleNode('/e:Event/e:System/e:TimeCreated', $ns)
        $times = @{}
        foreach ($key in 'TimeCreated', 'SleepTime', 'WakeTime') {
            $text = $data[$key]
            if ($key -eq 'TimeCreated') {
                $text = if ($created) { $created.GetAttribute('SystemTime') } else { $null }
            }
            $dt = [datetime]::MinValue
            $times[$key] = $null
            if ($text -and [datetime]::TryParse($text, $invariant, $roundtrip, [ref]$dt)) {
                $times[$key] = $dt.ToLocalTime()
            }
        }
        $sourceType = 0
        $hasSourceType = [int]::TryParse([string]$data['WakeSourceType'], [ref]$sourceType)
        [pscustomobject]@{
            PSTypeName     = 'PsPowerCfg.PowerWakeEvent'
            TimeCreated    = $times['TimeCreated']
            SleepTime      = $times['SleepTime']
            WakeTime       = $times['WakeTime']
            WakeSourceType = if ($hasSourceType) { $sourceType } else { $null }
            WakeSourceText = $data['WakeSourceText']
            Data           = $data
        }
    }
}
