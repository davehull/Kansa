# OUTPUT TSV
Get-WmiObject -Namespace root\subscription -Query "select * from __EventFilter"