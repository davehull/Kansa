# OUTPUT xml
<#
Get-RunningServices.ps1
Acquires details about running and auto-start services
#>

Get-WmiObject win32_service | ? { $_.State -match "Running" -or $_.StartMode -match "Auto" }