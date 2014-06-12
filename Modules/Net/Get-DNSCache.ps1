# OUTPUT tsv
<#
.SYNOPSIS
Get-DNSCache.ps1 acquires DNS cache entries from the target host.
#>

<<<<<<< HEAD
if (Get-Command Get-DnsClientCache -ErrorAction SilentlyContinue) {
=======
if (Get-Command Get-DnsClientCache) {
>>>>>>> parent of a9aecff... Update Get-DNSCache.ps1
    Get-DnsClientCache
} else {
    & ipconfig /displaydns | Select-String 'Record Name' | ForEach-Object { $_.ToString().Split(' ')[-1] } | `
      Select-Object -Unique | sort | % {
        $o = "" | Select-Object FQDN
        $o.FQDN = $_
        $o
    }
}
