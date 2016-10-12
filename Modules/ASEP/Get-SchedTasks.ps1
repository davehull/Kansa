<#
.SYNOPSIS
Get-ShedTasks.ps1 returns information about all Windows Scheduled Tasks.
.NOTES
The following line is required by Kansa.ps1, which uses it to determine
Output will be a PS Object.
- schtasks.exe output is not good.  It needs to be parsed to remove redundant headers.
#>
# Run schtasks and remove redundant headers
$tasks = schtasks /query /FO CSV /v | Select-String -n "`"TaskName`",`""
# Remove duplicate quotes and convert output to an object
$tasks = $tasks | foreach {$_ -replace '"',''} | ConvertFrom-String -Delimiter "," -PropertyNames "HostName","TaskName","Next Run Time","Status","Logon Mode","Last Run Time","Last Result","Author","Task To Run","Start In","Comment","Scheduled Task State","Idle Time","Power Management","Run As User","Delete Task If Not Rescheduled","Stop Task If Runs X Hours and X Mins","Schedule","Schedule Type","Start Time","Start Date","End Date","Days","Months","Repeat: Every","Repeat: Until: Time","Repeat: Until: Duration","Repeat: Stop If Still Running"
$tasks
