# OUTPUT tsv
<#
.SYNOPSIS
Get-Products.ps1
Returns objects for products installed via Windows Installer, not likely 
to be malware for sure, but may give an indication of vulnerable product versions.
#>
Get-WmiObject Win32_Product