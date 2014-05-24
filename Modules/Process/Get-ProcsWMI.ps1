# OUTPUT tsv
<#
Get-ProcsWMI.ps1
Acquires command line arguments for running processes
#>

Get-WmiObject -Query "Select * from win32_process"