<#
.SYNOPSIS
    Get-SysmonNetwork.ps1 extracts all Sysmon Network Events [Evt 3] from the Sysymon Operational Event log for a specified timeframe
.DESCRIPTION
    Query the event log and pull back all Sysmon Process Creation events. Configured for Sysmon 5.02
    Event 3
    Query and filter
.PARAMETER
    Switch to pull back Network events back a desired number of minutes
    [int32]$BackMins=180. Defaults to 180 minutes = 3 hours
    Some time guides: 180 = 3 hours, 360 = 6hours, 720 = 12 hours, 1440 = 1 day, 2880 = 2 days, 4320 = 3 days, 10080 = 7 days
    Keep in mind depending on sysmon configuration, the longer the timeframe the more work to pull events.
.EXAMPLE
    .\Get-SysmonNetwork.ps1 -BackMins 180
    .\Get-SysmonNetwork.ps1 180
    .\Get-SysmonNetwork.ps1

    HostName            : Win10.ACME.local
    Version             : 5
    EventType           : Network connection detected
    EventID             : 3
    DateUTC             : 2017-01-18T02:16:53
    ProcessGuid         : b7480112-13e6-587c-0000-00109a016400
    ProcessId           : 4572
    Image               : C:\Program Files (x86)\Google\Chrome\Application\chrome.exe
    User                : ACME\USER1
    Protocol            : tcp
    Initiated           : True
    SourceIsIpv6        : False
    SourceIp            : 10.1.1.21
    SourceHostname      : Win10.ACME.local
    SourcePort          : 55047
    SourcePortName      : 
    DestinationIsIpv6   : False
    DestinationIp       : 216.58.220.131
    DestinationHostname : syd09s01-in-f131.1e100.net
    DestinationPort     : 443
    DestinationPortName : https

.LINK
.NOTES
Configured for Sysmon 5.02
Sysmon configuration plays a large part in the amount of events.
For offline parsing of event logs modify script to remove "-LogName" and add "-Path <PATH_to_Logs>". 
e.g RawEvents = Get-WinEvent -Path c:\case\sysmon.evtx | Where-Object {$_.TimeCreated -ge $BackTime} | Where-Object { $_.Id -eq 3}
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [int32]$BackMins=180
)
$BackTime=(Get-Date) - (New-TimeSpan -Minutes $BackMins)
$RawEvents = Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" | Where-Object {$_.TimeCreated -ge $BackTime} | Where-Object { $_.Id -eq 3}
$RawEvents | ForEach-Object {  
    $PropertyBag = @{
        HostName = $_.MachineName
        Version=$_.Version
        EventType = $_.Message.Split(":")[0]
        EventID = $_.Id
        DateUTC = Get-Date ($_.Properties[0].Value) -format s
        ProcessGuid = $_.Properties[1].Value
        ProcessId = $_.Properties[2].Value
        Image = $_.Properties[3].Value
        User = $_.Properties[4].Value
        Protocol = $_.Properties[5].Value
        Initiated = $_.Properties[6].Value
        SourceIsIpv6 = $_.Properties[7].Value
        SourceIp = $_.Properties[8].Value
        SourceHostname = $_.Properties[9].Value
        SourcePort = $_.Properties[10].Value
        SourcePortName = $_.Properties[11].Value
        DestinationIsIpv6 = $_.Properties[12].Value
        DestinationIp = $_.Properties[13].Value
        DestinationHostname = $_.Properties[14].Value
        DestinationPort = $_.Properties[15].Value
        DestinationPortName = $_.Properties[16].Value
    }
    $Output = New-Object -TypeName PSCustomObject -Property $PropertyBag
    # When modifying PropertyBag remember to change Seldect-Object for ordering below
    $Output | Select-Object HostName, Version, EventType, EventID, DateUTC, ProcessGuid, ProcessId, Image, User, Protocol, Initiated, SourceIsIpv6, SourceIp, SourceHostname, SourcePort, SourcePortName, DestinationIsIpv6, DestinationIp, DestinationHostname, DestinationPort, DestinationPortName
}

        
