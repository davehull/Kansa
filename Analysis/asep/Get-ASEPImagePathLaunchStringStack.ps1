<#
Get-ASEPImagePathLaunchStringStack.ps1
Requires logparser.exe in path
Pulls frequency of autoruns based on [Image Path] and [Launch String] tuple

This script expects files matching the pattern *autorunsc.txt to be in the
current working directory.
#>

if (Get-Command logparser.exe) {

    $lpquery = @"
    SELECT
        COUNT([Image Path], [Launch String]) as ct,
        [Image Path],
        [Launch String]
    FROM
        *autorunsc.txt
    WHERE
        Publisher not like '(Verified)%' and
        ([Image Path] not like 'File not found%')
    GROUP BY
        [Image Path],
        [Launch String]
    ORDER BY
        ct ASC
"@

    & logparser -i:csv -dtlines:0 -rtp:50 "$lpquery"

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}
