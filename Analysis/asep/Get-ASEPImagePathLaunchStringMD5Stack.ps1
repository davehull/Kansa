<#
Get-ASEPImagePathLaunchStringStack.ps1
Requires logparser.exe in path
Pulls frequency of autoruns based on [Image Path] and [Launch String] tuple
ToDo: 
Add check for logparser.exe in path
Add check for *svctrigs.tsv in current path
#>

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

& logparser -i:csv -dtlines:0 -rtp:50 "$lpquery"