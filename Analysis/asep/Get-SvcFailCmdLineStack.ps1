<#
.SYNOPSIS
Get-SvcFailCmdLineStack.ps1
Requires logparser.exe in path
Pulls stack rank of Service Failure CmdLines from acquired Service Failure data
where CmdLine is not 'customScript.cmd' nor NULL

This script expects files matching the pattern *SvcFail.tsv to be in 
the current working directory.
.NOTES
DATADIR SvcFail
#>

if (Get-Command logparser.exe) {

    $lpquery = @"
    SELECT
        COUNT(To_Lowercase(CmdLine)) as ct, 
        To_Lowercase(CmdLine) as CmdLineLC
    FROM
        *SvcFail.csv
    GROUP BY
        CmdLineLC
    ORDER BY
        ct ASC
"@

    & logparser -stats:off -i:csv -dtlines:0 -rtp:-1 $lpquery

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}
