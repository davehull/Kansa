<#
.SYNOPSIS
Get-WMIEvtFilter.ps1 returns information about WMI Event Filters, which
are used to monitor for certain Windows Events. When the filter matches
an event, if there is a Filter to Consumer binding in place and a WMI
Event Consumer, the code in the consumer will be called. Malware
authors have used WMI Event Consumers and their associated components
for maintaining persistence.
.NOTES
The following line is used by Kansa.ps1 to determine how to treat the
output from this script.
OUTPUT TSV
#>
ForEach ($NameSpace in "root\subscription","root\default") { Get-WmiObject -Namespace $NameSpace -Query "select * from __EventFilter" }
