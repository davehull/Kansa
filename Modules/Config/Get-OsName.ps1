<#net localgroup administrators | select-object -skip 6 | where {
    $_ -and $_ -notmatch "The command completed successfully"
} |  ForEach-Object {
    $o = "" | Select-Object Account
    $o.Account = $_
    $o 
} 
#>
#OUTPUT TSV
(Get-WmiObject -class Win32_OperatingSystem).Caption | ? {
    $_
} | % {
    $o ="" | select-object Caption
    $o.Caption=$_
    $o
}
