<#
Get-SvcTrigStack.ps1
Requires logparser.exe in path
Pulls stack rank of Service Triggers from acquired Service Trigger data
ToDo: 
Add check for logparser.exe in path
Add check for *svctrigs.tsv in current path
#>

& logparser -i:tsv -fixedsep:on -dtlines:0 -rtp:50 "select Count(Condition, Value) as ct, ServiceName, Action, Condition, Value from *svctrigs.tsv group by ServiceName, Action, Condition, Value order by ct asc"