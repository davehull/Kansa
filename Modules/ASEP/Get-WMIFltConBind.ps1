<#
.SYNOPSIS
Get-WMIFiltConBind.ps1 returns information about the WMI Event Filter
to Consumer binding, a necessary component for triggering WMI Event
Consumers, which have been used by malware as a persistence mechanism
#>
ForEach ($NameSpace in "root\subscription","root\default") { Get-WmiObject -Namespace $NameSpace -Query "select * from __FilterToConsumerBinding" }
