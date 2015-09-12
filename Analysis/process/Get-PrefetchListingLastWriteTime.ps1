<#
.SYNOPSIS
Get-PrefetchListingLastWriteTime.ps1
Requires logparser.exe in path
Pulls PrefetchListing data sorted by LastWriteTimeUtc Descending
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
        FullName,
        LastWriteTimeUtc,
        PSComputerName
    FROM
        *PrefetchListing.tsv
    ORDER BY
        LastWriteTimeUtc Desc
"@

    & logparser -stats:off -i:csv -fixedsep:on -dtlines:0 -rtp:-1 $lpquery

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}
