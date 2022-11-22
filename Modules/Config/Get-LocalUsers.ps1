<#
.SYNOPSIS
Get-LocalUsers.ps1 returns a list of local user account on the host.   

by the dude with the moe, 18 Nov 2022. 
.DESCRIPTION
Get-LocalUsers.ps1 returns Disabled (bool), Name, Full-Name, Caption, Domain and SID for each local user account on the host.
#>
Get-WmiObject win32_UserAccount | Select-Object -Property Disabled, Name, FullName, Caption, Domain, SID