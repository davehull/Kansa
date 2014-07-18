<#
.SYNOPSIS
Get-Tasklistv.ps1 acquires tasklist /v (verbose output includes process owner) and formats as csv
.NOTES
Kansa.ps1 output directive follows
OUTPUT tsv
#>
& $env:windir\system32\tasklist.exe /v /fo csv | Select-Object -Skip 1 | % {
    $o = "" | Select-Object ImageName,PID,SessionName,SessionNum,MemUsage,Status,UserName,CPUTime,WindowTitle
    $row = $_ -replace '(,)(?=(?:[^"]|"[^"]*")*$)', "`t" -replace "`""
    $o.ImageName, 
    $o.PID,
    $o.SessionName,
    $o.SessionNum,
    $o.MemUsage,
    $o.Status,
    $o.UserName,
    $o.CPUTime,
    $o.WindowTitle = ( $row -split "`t" )
    $o
}