<#
.SYNOPSIS
Get-ShedTasks.ps1 returns operational information about all Windows Scheduled Tasks.
.NOTES
The following line is required by Kansa.ps1, which uses it to determine
how to handle the output from this script.
OUTPUT tsv
#>
if (Get-Command Get-ScheduledTask -errorAction SilentlyContinue) {
    Get-ScheduledTask | Get-ScheduledTaskInfo
} 
