# DATADIR Autorunsc
<#
Get-ASEPImagePathLaunchStringStack.ps1
Requires logparser.exe in path
Pulls frequency of autoruns based on ImagePath, LaunchString and MD5 tuple

This script expects files matching the *autorunsc.txt pattern to be in the
current working directory.
#>


if (Get-Command logparser.exe) {
    $lpquery = @"
    SELECT
        COUNT(ImagePath, LaunchString, MD5) as ct,
        ImagePath,
        LaunchString,
        MD5
    FROM
        *autorunsc.tsv
    WHERE
        (ImagePath not like 'File not found%')
    GROUP BY
        ImagePath,
        LaunchString,
        MD5
    ORDER BY
        ct ASC
"@

    & logparser -i:tsv -dtlines:0 -fixedsep:on -rtp:-1 "$lpquery"

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}