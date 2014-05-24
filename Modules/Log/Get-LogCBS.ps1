# OUTPUT TSV
# Returns the contents of the CBS log.

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