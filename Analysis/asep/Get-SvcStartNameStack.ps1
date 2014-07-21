<#
.SYNOPSIS
Get-SvcStartNameStack.ps1
A basic stack for services aggregating on Caption and StartName.
StartName tells you what account the service runs under.

Out put is fairly ugly, it is sorted by Name, rather than count.
Sorting this way means that items with the same Caption, but 
different StartNames will be reported next to each other. Seeing
two services reporting to be the same service, but running under
different accounts would be worthy of closer investigation, confirm
the Pathnames are the same for both of them.

Get-Autorunsc.ps1 output provides much of this same information,
but it doesn't tell you the account a service will run under.
.NOTES
DATADIR SvcAll
#>

$data = $null

foreach ($file in (ls *svcall.xml)) {
    $data += Import-Clixml $file
}

$data | Select-Object Caption, StartName | Sort-Object Caption, StartName | Group-Object Caption, StartName | Sort-Object Name