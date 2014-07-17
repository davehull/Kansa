<#
.SYNOPSIS
Get-Products.ps1 returns data about products that were installed via 
the Windows installer.
.NOTES
The next line is needed by Kansa.ps1 to determine how the output from
this script should be handled.
OUTPUT tsv
#>
Get-WmiObject Win32_Product