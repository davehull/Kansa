<#
.SYNOPSIS
Get-SvcAllRunningAuto.ps1
Parses through the Get-SvcAll.ps1 data and returns
those items that are running or set to start automatically.
.NOTES
DATADIR SvcAll
#>

$data = $null

foreach ($file in (ls *svcall.xml)) {
    $data += Import-Clixml $file
}

$data | ? { $_.StartMode -eq "Auto" -or $_.State -eq "Running" }