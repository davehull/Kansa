<#
.SYNOPSIS
Get-WMIFiltConBind.ps1 returns information about the WMI Event Filter
to Consumer binding, a necessary component for triggering WMI Event
Consumers, which have been used by malware as a persistence mechanism
.NOTES
The following line is an OUPUT directive used by kansa.ps1 to determine
how this scripts output should be handled.
OUTPUT TSV
#>
Get-WmiObject -Namespace root\subscription -Query "select * from __FilterToConsumerBinding"