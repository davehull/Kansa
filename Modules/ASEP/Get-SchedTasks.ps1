<#
.SYNOPSIS
Get-ShedTasks.ps1 returns information about all Windows Scheduled Tasks.
.NOTES
schtasks.exe output is not that good.  It needs to be parsed to remove redundant headers.
#>
# Run schtasks and convert csv to object
schtasks /query /FO CSV /v | ConvertFrom-Csv
