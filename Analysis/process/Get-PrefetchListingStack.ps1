<#
.SYNOPSIS
Get-PrefetchListingStack.ps1
Requires logparser.exe in path
Pulls stack rank of prefetch files based
on collected Get-PrefetchListing data.

This script exepcts files matching the pattern 
*PrefetchListing.tsv to be in the current working
directory
.NOTES
DATADIR PrefetchListing
#>

if (Get-Command logparser.exe) {

    $lpquery = @"
    SELECT
        COUNT(FullName) as CT,
        FullName
    FROM
        *PrefetchListing.tsv
    GROUP BY
        FullName
    ORDER BY
        ct
"@

    & logparser -stats:off -i:csv -fixedsep:on -dtlines:0 -rtp:-1 $lpquery

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}
