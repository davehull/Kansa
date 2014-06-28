# DATADIR ProcsWMI
<#
Get-ProcsWMICLIStack.ps1

Returns frequency of "CommandLine," which is
ExecutablePath and command line arguments and hash
of file on disk

Requires:
Process data matching *ProcWMI.tsv in pwd
logparser.exe in path
#>

if (Get-Command logparser.exe) {
    $lpquery = @"
    SELECT
        COUNT(CommandLine) as Cnt,
        CommandLine,
        Hash
    FROM
        *ProcsWMI.tsv
    GROUP BY
        CommandLine,
        Hash
    ORDER BY
        Cnt ASC
"@

    & logparser -i:tsv -dtlines:0 -fixedsep:on -rtp:-1 "$lpquery"

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}