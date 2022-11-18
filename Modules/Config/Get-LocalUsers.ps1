<#
.SYNOPSIS
Get-LocalUsers.ps1 returns a list of local user accounts detailing name, full name, caption, domain and SID.  

by the dude with the moe, 18 Nov 2022. 
.NOTES
Next line is required by Kansa.ps1. It instructs Kansa how to handle
the output from this script.
OUTPUT csv
#>
Get-WmiObject win32_UserAccount | Select-Object -Property Name, FullName, Caption, Domain, SID