<#
.SYNOPSIS
    Get-RdpConnectionLogs.ps1 queries the RemoteConnectionManager operational
    log to get details about remote connections.

.DESCRIPTION
    The RemoteConnectionManager operational log contains details about the
    state of the services controlling RDP access to a host. Most of the events
    are, as the name implies, operational and not immediately relevant to IR.
    Event 1149 however, records the user, domain, and source IP address of 
    connections to the host.

    Query and filter thanks to a tweet by Nick Landers (@monoxgas).

.PARAMETER AllEvents
    Switch to pull all events from the log, not just 1149. This disables all
    additional processing of the Message property.

.EXAMPLE
    .\Get-RdpConnectionLogs.ps1

    Message     : Remote Desktop Services: User authentication succeeded:
    ProcessId   : 3352
    Id          : 1149
    MachineNae  : KANSA-TEST
    TimeCreated : 4/15/2016 06:30:11
    Version     : 0
    LogName     : Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational
    SourceIp    : 10.0.0.46
    UserName    : KANSA\tester
    UserId      : S-1-5-20
    ThreadId    : 8472

.EXAMPLE
    .\Get-RdpConnectionLogs.ps1 -AllEvents

.LINK
https://twitter.com/monoxgas/status/733808746896363520
https://twitter.com/monoxgas/status/733808977327226880

.NOTES
OUTPUT tsv
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [switch]$AllEvents
)

if ($AllEvents) # Effectively a dump of the log, lots of uneccessary data here.
{
    Write-Warning "Running this script in 'AllEvents' mode is not recommended as it returns a significant amount of unnecessary data."
    Start-Sleep -Seconds 1
    
    Get-WinEvent -LogName "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational" | `
        Select-Object -Property TimeCreated, LogName, Id, Version, ProcessId, ThreadId, MachineName, UserId, Message
}
else # Targetted on authentication events.
{
    $RawEvents = Get-WinEvent -LogName "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational" | `
        Where-Object { $_.Id -eq 1149 }

    $RawEvents | ForEach-Object `
    {  
        if ($_.Properties.Count -lt 3)
        {
            Write-Warning "Event record missing expected fields. Skipping extended processing."
            $_ | Select-Object -Property TimeCreated, LogName, Id, Version, ProcessId, ThreadId, MachineName, UserId
            continue
        }

        $User = $_.Properties[0].Value
        $Domain = $_.Properties[1].Value
        $SourceIp = $_.Properties[2].Value

        $NormalizedUser = ("{1}\{0}" -f $User, $Domain)

        $Message = $_.Message.Split("`n")[0]

        $PropertyBag = @{
            TimeCreated = $_.TimeCreated;
            LogName = $_.LogName;
            Id = $_.Id;
            Version = $_.Version;
            ProcessId = $_.ProcessId;
            ThreadId = $_.ThreadId;
            MachineNae = $_.MachineName;
            UserId = $_.UserId;
            UserName = $NormalizedUser;
            SourceIp = $SourceIp;
            Message = $Message
        }

        $o = New-Object -TypeName PSCustomObject -Property $PropertyBag
        $o
    }
}