<#
.SYNOPSIS
Get-ShedTasks.ps1 returns information about all Windows Scheduled Tasks.
#>
$tasks = schtasks /query /FO CSV /v | Select-String -n "`"TaskName`",`""
$tasks = $tasks | foreach {$_ -replace '"',''} |ConvertFrom-String -Delimiter "," -PropertyNames "HostName","TaskName","Next Run Time","Status","Logon Mode","Last Run Time","Last Result","Author","Task To Run","Start In","Comment","Scheduled Task State","Idle Time","Power Management","Run As User","Delete Task If Not Rescheduled","Stop Task If Runs X Hours and X Mins","Schedule","Schedule Type","Start Time","Start Date","End Date","Days","Months","Repeat: Every","Repeat: Until: Time","Repeat: Until: Duration","Repeat: Stop If Still Running"
$tasks
