<#
.SYNOPSIS
Get-NetstatStackForeignIpProcess.ps1
Requires logparser.exe in path

Pulls stack rank of connections from netstat data based on 
ForeignAddress and Process. 

Assumes local network space is using 10/8 CIDR and looks for
foreign addresses outside that range. See query for additional
filtered IP ranges and processes.

You may want to customize this a bit for
your environment. If you're running web 
servers, for example, stacking them may be
meaningless if they are meant to accept 
connections from any host in the world, or
maybe you just remove the web server process
from the query...

!! YOU WILL LIKELY WANT TO ADJUST THIS QUERY !!

This script exepcts files matching the pattern 
*netstat.tsv to be in the current working
directory
.NOTES
DATADIR Netstat
#>

if (Get-Command logparser.exe) {

    $lpquery = @"
    SELECT
        COUNT(ForeignAddress,
        Process) as ct,
        ForeignAddress,
        Process
    FROM
        *netstat.tsv
    WHERE
        ConPid not in ('0'; '4') and
        ForeignAddress not like '10.%' and
        ForeignAddress not like '169.254%' and
        ForeignAddress not in ('*'; '0.0.0.0'; 
            '127.0.0.1'; '[::]'; '[::1]')
    GROUP BY
        ForeignAddress,
        Process
    ORDER BY
        Process,
        ct desc
"@

    & logparser -stats:off -i:csv -fixedsep:on -dtlines:0 -rtp:-1 $lpquery

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}
