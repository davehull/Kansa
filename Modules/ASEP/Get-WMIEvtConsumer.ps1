# OUTPUT TSV
get-wmiobject -namespace root\subscription -query "select * from __EventConsumer"