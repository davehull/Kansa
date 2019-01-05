<#
.SYNOPSIS
Get-Process.ps1 returns data about Process.
.NOTES
The next line is needed by Kansa.ps1 to determine how to handle output
from this script.
OUTPUT TSV

Contributed by Jesse Moore
#>
<#net localgroup administrators | select-object -skip 6 | where {
    $_ -and $_ -notmatch "The command completed successfully"
} |  ForEach-Object {
    $o = "" | Select-Object Account
    $o.Account = $_
    $o 
} 
#>
#Get Processes
(Get-WMIObject Win32_Process -ComputerName $env:COMPUTERNAME | ForEach-Object { $_.ProcessName } | Sort-Object | Get-Unique) | ? {
    $_
} | % {
    $o ="" | select-object ProcessName
    $o.ProcessName = $_
    $o
}
