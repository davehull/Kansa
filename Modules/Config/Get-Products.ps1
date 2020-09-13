<#
.SYNOPSIS
Get-Products.ps1 returns data about products that were installed via 
the installer.
.NOTES
The next line is needed by Kansa.ps1 to determine how the output from
this script should be handled.
OUTPUT csv
#>
$64bit = gwmi win32_operatingsystem | select -ExpandProperty osarchitecture
if ($64bit -eq "64-bit") {
    Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |? {$_.DisplayName -ne $null}| Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, InstallSource
    Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |? {$_.DisplayName -ne $null}|  Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, InstallSource
}
else {
    Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |? {$_.DisplayName -ne $null}| Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, InstallSource
}