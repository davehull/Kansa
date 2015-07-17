<#
.SYNOPSIS
Get-Products.ps1 returns data about products that were installed via 
the installer.
.NOTES
The next line is needed by Kansa.ps1 to determine how the output from
this script should be handled.
OUTPUT csv
#>
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |  Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, InstallSource