<#
Get-ASEPImagePathLaunchStringStack.ps1
Requires logparser.exe in path
Pulls frequency of autoruns based on [Image Path] and [Launch String] tuple

This script expects files matching the *autorunsc.txt pattern to be in the
current working directory.
#>


if (Get-Command logparser.exe) {
    $lpquery = @"
    SELECT
        COUNT([Image Path], [Launch String], MD5) as ct,
        [Image Path],
        [Launch String],
        MD5
    FROM
        *autorunsc.txt
    WHERE
        Publisher not like '(Verified)%' and
        ([Image Path] not like 'File not found%')
    GROUP BY
        [Image Path],
        [Launch String],
        MD5
    ORDER BY
        ct ASC
"@

    & logparser -i:tsv -dtlines:0 -rtp:50 "$lpquery"

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}
