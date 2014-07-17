<#
.SYNOPSIS
Get-LocalAdmins.ps1 returns a list of local administrator accounts.
.NOTES
Next line is required by Kansa.ps1. It instructs Kansa how to handle
the output from this script.
OUTPUT tsv
#>

& net localgroup administrators | Select-Object -Skip 6 | ? {
    $_ -and $_ -notmatch "The command completed successfully" 
} | % {
    $o = "" | Select-Object Account
    $o.Account = $_
    $o
}