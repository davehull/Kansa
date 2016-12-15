<#
.SYNOPSIS
Get-WMIEventConsumer.ps1 returns data for WMI Event Consumers, which
when accompanied by a WMI Event Filter and a WMI Event Filter to
Consumer Binding, will fire when the filter matches a given Windows
event. This has been used by malware authors for maintaining 
persistence.
.NOTES
The following line is used by Kansa.ps1 to determine how ouptut from
this script should be handled.
OUTPUT TSV
#>
ForEach ($NameSpace in "root\subscription","root\default") { get-wmiobject -namespace $NameSpace -query "select * from __EventConsumer" }
