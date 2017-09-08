<#
.SYNOPSIS
    Get-SysmonProcess.ps1 extracts all Sysmon Process Create Events [Evt 1] from the Sysymon Operational Event log for a specified timeframe
.DESCRIPTION
    Query the event log and pull back all Sysmon Process Creation events. Configured for Sysmon 5.02
    Event 1
    Query and filter
.PARAMETER
    Switch to pull back Process Creation back a desired number of minutes
    [int32]$BackMins=180. Defaults to 180 minutes = 3 hours
    Some time guides: 180 = 3 hours, 360 = 6hours, 720 = 12 hours, 1440 = 1 day, 2880 = 2 days, 4320 = 3 days, 10080 = 7 days
    Keep in mind depending on sysmon configuration, the longer the timeframe the more work to pull events.
.EXAMPLE
    .\Get-SysmonProcess.ps1 -BackMins 720
    .\Get-SysmonProcess.ps1 720
    .\Get-SysmonProcess.ps1

    DateUTC           : 2017-01-16T01:09:25
    HostName          : Win10.ACME.local
    Version           : 5
    EventID           : 1
    EventType         : Process Create
    ProcessGuid       : b7480112-1d45-587c-0000-0010c1d96b00
    ProcessId         : 5196
    Image             : C:\Windows\System32\PING.EXE
    CommandLine       : ping  8.8.8.8 -n 1
    MD5               : 7B647B55695ACE1E99158F79AB3AF51A
    SHA1              : 57CC695F7FFA71A5970DDAB9A8656DDEC78E795A
    SHA256            : ED7FA5B3CCBDD31A9E83F7C59F78AB5E2C83C7FEEDCC5F8B95948D11EBD7FF34
    CurrentDirectory  : C:\Users\Administrator\Desktop\
    User              : ACME\USER1
    LogonGuid         : b7480112-13c7-587c-0000-0020bef05f00
    LogonId           : 6287550
    TerminalSessionId : 2
    IntegrityLevel    : High
    ParentProcessGuid : b7480112-1d20-587c-0000-00105ea06b00
    ParentProcessId   : 1064
    ParentImage       : C:\Windows\System32\cmd.exe
    ParentCommandLine : "C:\Windows\system32\cmd.exe" 

.LINK
.NOTES
Configured for Sysmon 5.02
Sysmon configuration plays a large part in the amount of events.
I have configured the module to report back for a Sysmon hash configuration of: MD5,SHA1,SHA256. For any other configurations you will need to reconfigure the Propertybag array to report relevant algorythms.
For simplicity I have also included a hashes field commented out. If included, it will show all calculated hashes in one line.
When modifying $PropertyBag, remember to change the final Select-Object to ensure correct feilds are selected in order.
For offline parsing of event logs modify script to remove "-LogName" and add "-Path <PATH_to_Logs>". 
e.g RawEvents = Get-WinEvent -Path c:\case\sysmon.evtx | Where-Object {$_.TimeCreated -ge $BackTime} | Where-Object { $_.Id -eq 1}
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [int32]$BackMins=180
)
$BackTime=(Get-Date) - (New-TimeSpan -Minutes $BackMins)
$RawEvents = Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" | Where-Object {$_.TimeCreated -ge $BackTime} | Where-Object { $_.Id -eq 1}
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
        CommandLine = $_.Properties[4].Value
        CurrentDirectory = $_.Properties[5].Value
        User = $_.Properties[6].Value
        LogonGuid = $_.Properties[7].Value
        LogonId = $_.Properties[8].Value
        TerminalSessionId = $_.Properties[9].Value
        IntegrityLevel = $_.Properties[10].Value
        #Hashes = ($_.Properties[11].Value.Split(",")) # shows hash feild with all configured hash types one field
        MD5 = ($_.Properties[11].Value.Split(",")[1].split("=")[1]) # requires logging of MD5, SHA1, SHA256
        SHA1 = ($_.Properties[11].Value.Split(",")[0].split("=")[1]) # required logging of MD5, SHA1, SHA256
        SHA256 = ($_.Properties[11].Value.Split(",")[2].split("=")[1]) # required logging of MD5, SHA1, SHA256
        ParentProcessGuid = $_.Properties[12].Value
        ParentProcessId = $_.Properties[13].Value
        ParentImage = $_.Properties[14].Value
        ParentCommandLine = $_.Properties[15].Value
    }
    $Output = New-Object -TypeName PSCustomObject -Property $PropertyBag
    # When modifying PropertyBag remember to change Seldect-Object for ordering below
    $Output | Select-Object DateUTC, HostName, Version, EventID, EventType, ProcessGuid, ProcessId, Image, CommandLine, MD5,SHA1, SHA256, CurrentDirectory, User, LogonGuid, LogonId, TerminalSessionId, IntegrityLevel, ParentProcessGuid, ParentProcessId, ParentImage, ParentCommandLine
} 
