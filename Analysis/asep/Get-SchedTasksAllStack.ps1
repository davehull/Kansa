<#
.SYNOPSIS
Get-SchedTasksAllStack.ps1
Requires logparser.exe in path
Pulls stack rank of all Service Failures from acquired Service Failure data

This script expects files matching the pattern *SvcFail.tsv to be in 
the current working directory.
.NOTES
DATADIR SchedTasksAll
#>

if (Get-Command logparser.exe) {

    $lpquery = @"
    SELECT
        COUNT(*) as Quantity, 
        Author,
        [Task To Run],
        BinaryPath,
        dllPath, 
        BinaryHash, 
        dllHash
    FROM
        *SchedTasksAll.csv
    GROUP BY
        Author,
        [Task To Run],
        BinaryPath,
        dllPath, 
        BinaryHash, 
        dllHash
    ORDER BY
        Quantity ASC
"@

    & logparser -stats:off -i:csv -o:csv $lpquery

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}
