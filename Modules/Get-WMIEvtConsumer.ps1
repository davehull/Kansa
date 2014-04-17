# OUTPUT xml
$ComputerName = $env:COMPUTERNAME
get-wmiobject -namespace root\subscription -computername $ComputerName -query "select * from __EventConsumer"