<#
.SYNOPSIS
Get-NetstatListenerStack.ps1
Requires logparser.exe in path

Pulls stack rank of Netstat listeners aggregating 
on Protocol, Component and Process

!! YOU WILL LIKELY WANT TO ADJUST THIS QUERY !!

This script exepcts files matching the pattern 
*netstat.csv to be in the current working
directory
.NOTES
DATADIR Netstat
#>

if (Get-Command logparser.exe) {

    $lpquery = @"
    SELECT
        COUNT(Protocol,
        State,
        Component,
        Process) as Cnt,
        Protocol,
        State,
        Component,
        Process
    FROM
        *netstat.csv
    WHERE
        ConPid not in ('0'; '4') and
        State = 'LISTENING'
    GROUP BY
        Protocol,
        State,
        Component,
        Process

    ORDER BY
        Cnt, Process desc
"@

    & logparser -stats:off -i:csv -dtlines:0 -rtp:-1 $lpquery

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}
