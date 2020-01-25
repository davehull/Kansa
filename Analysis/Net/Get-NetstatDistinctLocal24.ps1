<#
Get-NetstatDistinctLocal24.ps1
Requires logparser.exe in path
Pulls distinct /24 local network addresses. Useful for building the 
filter for local addresses in other analysis scripts, so you can see
what hosts are communicating to hosts outside your environment.

This script exepcts files matching the pattern 
*netstat.csv to be in the current working
directory
.NOTES
DATADIR Netstat
#>

if (Get-Command logparser.exe) {

    $lpquery = @"
    SELECT
        Distinct substr(ForeignAddress, 0, last_index_of(ForeignAddress, '.')) as Local/24
    FROM
        *netstat.csv
    ORDER BY
        Local/24
"@

    & logparser -stats:off -i:csv -dtlines:0 -rtp:-1 $lpquery

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}
