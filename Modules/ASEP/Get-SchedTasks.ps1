<#
.SYNOPSIS
Get-ShedTasks.ps1 returns information about all Windows Scheduled Tasks.
.NOTES
The following line is required by Kansa.ps1, which uses it to determine
how to handle the output from this script.
OUTPUT tsv
#>
if (Get-Command Get-ScheduledTask -errorAction SilentlyContinue) {
    Get-ScheduledTask
} else {
    schtasks /query /FO CSV | Select-String -n "`"TaskName`",`""
}
