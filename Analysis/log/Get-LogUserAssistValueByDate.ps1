# DATADIR LogUserAssist
<#
Get-LogUserAssistValueByDate.ps1
Requires logparser.exe in path
Returns UserAssist data sorted by KeyLastWritetime ascending

This script expects files matching the *LogUserAssist.tsv pattern to be in the
current working directory.
#>


if (Get-Command logparser.exe) {
    $lpquery = @"
    SELECT
        User,
        Subkey,
        KeyLastWriteTime,
        Value,
        Count,
        PSComputerName
    FROM
        *LogUserAssist.tsv
    ORDER BY
        KeyLastWriteTime ASC
"@

    & logparser -i:tsv -dtlines:0 -fixedsep:on -rtp:-1 "$lpquery"

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}