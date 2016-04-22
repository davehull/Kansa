<#
.SYNOPSIS
Get-DNSCacheStack.ps1
Requires logparser.exe in path
Pulls frequency of DNSCache entries

This script expects files matching the *DNSCache.csv pattern to be in the
current working directory.
.NOTES
DATADIR DNSCache
#>


if (Get-Command logparser.exe) {
    $lpquery = @"
    SELECT
        COUNT(Entry) as ct,
        Entry
    FROM
        *DNSCache.csv
    GROUP BY
        Entry
    ORDER BY
        ct ASC
"@

    & logparser -stats:off -i:csv -dtlines:0 -rtp:-1 "$lpquery"

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}

