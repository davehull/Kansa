<#
.SYNOPSIS
Get-SvcFailStack.ps1
Requires logparser.exe in path
Pulls stack rank of Service Failures from acquired Service Failure data
where CmdLine is not 'customScript.cmd' nor NULL

This script expects files matching the pattern *SvcFail.tsv to be in 
the current working directory.
.NOTES
DATADIR SvcFail
#>

if (Get-Command logparser.exe) {

    $lpquery = @"
    SELECT
        COUNT(ServiceName, 
        CmdLine,
        FailAction1,
        FailAction2,
        FailAction3) as ct, 
        ServiceName, 
        CmdLine,
        FailAction1,
        FailAction2,
        FailAction3
    FROM
        *SvcFail.csv
    WHERE
        CmdLine <> 'customScript.cmd' AND
        CmdLine is not NULL
    GROUP BY
        ServiceName, 
        CmdLine,
        FailAction1,
        FailAction2,
        FailAction3
    ORDER BY
        ct ASC
"@

    & logparser -stats:off -i:csv -dtlines:0 -rtp:-1 $lpquery

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}
