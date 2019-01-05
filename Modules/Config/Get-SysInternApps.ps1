<#
.SYNOPSIS
Get-SysInternApps.ps1 returns data about if SysInternals are installed via Registry.
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
#Get Sysinternals Apps from Registry
reg query HKCU\SOFTWARE\Sysinternals 2> null | ? {
    $_
} | % {
    $o ="" | select-object SysinternApps
    $o.SysInternApps = $_
    $o
}
