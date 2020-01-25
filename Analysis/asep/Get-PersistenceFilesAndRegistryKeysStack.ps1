<#
.SYNOPSIS
Get-PersistenceFilesAndRegistryKeysStack.ps1
Requires logparser.exe in path
Pulls stack rank of all Service Failures from acquired Service Failure data

This script expects files matching the pattern *SvcFail.tsv to be in 
the current working directory.
.NOTES
DATADIR PersistanceFilesAndRegistryKeys
#>

if (Get-Command logparser.exe) {
	
	$lpquery = @"
    SELECT
        COUNT(Type) as Quantity, 
        Type, Set, Path, Value
    FROM
        *PersistenceFilesAndRegistryKeys.csv
    GROUP BY
       Type, Set, Path, Value
    ORDER BY
        Quantity ASC
"@
	
	& logparser -stats:off -i:csv -o:csv $lpquery
	
}
else {
	$ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
	"${ScriptName} requires logparser.exe in the path."
}
