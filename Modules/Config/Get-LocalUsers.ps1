<#
.SYNOPSIS
Get-LocalUsers.ps1 returns the following details of each local user acccount:
    - Disabled (bool), 
    - Name, 
    - Full Name, 
    - Caption, 
    - Domain
    - SID.  

by the dude with the moe, 18 Nov 2022. 
.NOTES
Next line is required by Kansa.ps1. It instructs Kansa how to handle
the output from this script.
OUTPUT tsv
#>
Get-WmiObject win32_UserAccount | Select-Object -Property Disabled, Name, FullName, Caption, Domain, SID