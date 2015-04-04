<#
.SYNOPSIS
Get-SvcAll.ps1 returns information about all Windows services.
.NOTES
The following line is required by Kansa.ps1, which uses it to determine
how to handle the output from this script.
OUTPUT tsv
#>
Get-WmiObject win32_service | Select-Object Name, DisplayName, PathName, StartName, StartMode, State, TotalSessions, Description 