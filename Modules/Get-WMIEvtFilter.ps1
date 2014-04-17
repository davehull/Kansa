# OUTPUT xml
$ComputerName = $env:COMPUTERNAME
Get-WmiObject -Namespace root\subscription -computername $ComputerName -Query "select * from __EventFilter"