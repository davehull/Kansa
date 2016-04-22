<#
.SYNOPSIS
Get-ARPStack.ps1
Requires logparser.exe in path
Pulls frequency of ARP based on IpAddr

This script expects files matching the *Arp.csv pattern to be in the
current working directory.
.NOTES
DATADIR Arp
#>


if (Get-Command logparser.exe) {
    $lpquery = @"
    SELECT
        COUNT(IpAddr, Mac, Type) as ct,
        IpAddr,
        Mac,
        Type
    FROM
        *arp.csv
    GROUP BY
        IpAddr,
        Mac,
        Type
    ORDER BY
        ct ASC
"@

    & logparser -stats:off -i:csv -dtlines:0 -rtp:-1 "$lpquery"

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}

