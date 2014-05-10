<#
Get-PrefetchListingStack.ps1
Requires logparser.exe in path
Pulls stack rank of prefetch files based
on collected Get-PrefetchListing data.

This script exepcts files matching the pattern 
*PrefetchListing.tsv to be in the current working
directory
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

    & logparser -i:tsv -fixedsep:on -dtlines:0 -rtp:50 $lpquery

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}