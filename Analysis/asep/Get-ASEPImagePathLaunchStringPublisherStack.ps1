# DATADIR Autorunsc
<#
Get-ASEPImagePathLaunchStringStack.ps1
Requires logparser.exe in path
Pulls frequency of autoruns based on ImagePath, LaunchString and Publisher tuple
where ImagePath is not 'File not found'

This script expects files matching the pattern *autorunsc.txt to be in the
current working directory.
#>

if (Get-Command logparser.exe) {

    $lpquery = @"
    SELECT
        COUNT(ImagePath, LaunchString, Publisher) as ct,
        ImagePath,
        LaunchString,
        Publisher
    FROM
        *autorunsc.tsv
    WHERE
        (ImagePath not like 'File not found%')
    GROUP BY
        ImagePath,
        LaunchString,
        Publisher
    ORDER BY
        ct ASC
"@

    & logparser -q:on -i:tsv -dtlines:0 -fixedsep:on -rtp:-1 "$lpquery"

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}
