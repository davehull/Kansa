<#
.SYNOPSIS
Get-ProxSystemStartTime.ps1

Pulls the StartTime for the System process for each host,
sort the data for all hosts.

Process data matching *Prox.xml in pwd
.NOTES
DATADIR Prox
#>

$(foreach($file in (ls *Prox.xml)) {
    $data = Import-Clixml $file
    $data | Where-Object { $_.ProcessName -eq "System" } |
        Select-Object PSComputerName, ProcessName, StartTime
}) | Sort-Object StartTime