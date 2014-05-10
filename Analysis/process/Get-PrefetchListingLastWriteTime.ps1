<#
Get-PrefetchListingLastWriteTime.ps1
Requires logparser.exe in path
Pulls PrefetchListing data sorted by LastWriteTimeUtc Descending
on collected Get-PrefetchListing data.

This script exepcts files matching the pattern 
*PrefetchListing.tsv to be in the current working
directory
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

    & logparser -i:tsv -fixedsep:on -dtlines:0 -rtp:50 $lpquery

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}