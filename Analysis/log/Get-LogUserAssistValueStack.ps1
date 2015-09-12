<#
.SYNOPSIS
Get-LogUserAssistValueStack.ps1
Requires logparser.exe in path
Pulls frequency of UserAssist subkey values (i.e. an executable run by a user)

This script expects files matching the *LogUserAssist.tsv pattern to be in the
current working directory.

.NOTES
DATADIR LogUserAssist
#>


if (Get-Command logparser.exe) {
    $lpquery = @"
    SELECT
        COUNT(Value) as ct,
        Value
    FROM
        *LogUserAssist.tsv
    GROUP BY
        Value
    ORDER BY
        ct ASC
"@

    & logparser -stats:off -i:csv -dtlines:0 -fixedsep:on -rtp:-1 "$lpquery"

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}
