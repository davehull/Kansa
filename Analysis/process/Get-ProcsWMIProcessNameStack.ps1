<#
.SYNOPSIS
Get-ProcsWMIProcessNameStack.ps1

Pulls frequency of processes based on path ProcessName

Requires:
Process data matching *ProcWMI.tsv in pwd
logparser.exe in path
.NOTES
DATADIR ProcsWMI
#>

if (Get-Command logparser.exe) {
    $lpquery = @"
    SELECT
        COUNT(ProcessName) as ct,
        ProcessName
    FROM
        *ProcsWMI.tsv
    GROUP BY
        ProcessName
    ORDER BY
        ct ASC
"@

    & logparser -stats:off -i:csv -dtlines:0 -fixedsep:on -rtp:-1 "$lpquery"

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}
