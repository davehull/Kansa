<#
.SYNOPSIS
Get-LocalAdminStack.ps1
Requires logparser.exe in path
Pulls frequency of local admin account entries

This script expects files matching the *LocalAdmins.tsv pattern to be in the
current working directory.
.NOTES
DATADIR LocalAdmins
#>


if (Get-Command logparser.exe) {
    $lpquery = @"
    SELECT
        COUNT(Account) as ct,
        Account
    FROM
        *LocalAdmins.csv
    GROUP BY
        Account
    ORDER BY
        ct ASC
"@

    & logparser -stats:off -i:csv -dtlines:0 -rtp:-1 "$lpquery"

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}
