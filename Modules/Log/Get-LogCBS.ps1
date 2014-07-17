<#
.SYNOPSIS
Get-LogCBS.ps1 returns the contents of the CBS log.

.NOTES
Next line required by Kansa.ps1 for handling this scripts output.
OUTPUT TSV
#>

Get-Content $env:windir\logs\CBS\cbs.log | % { 
    $_ -replace "\s\s+", "`t" 
} | % {
    $r = [regex]','
    $r.replace($_, "`t", 1)
} | % {
    $o = "" | Select-Object Timestamp, MessageType, LogSource, Message
    $o.Timestamp, $o.MessageType, $o.LogSource, $o.Message = ($_ -split "`t").Trim()
    $o
}