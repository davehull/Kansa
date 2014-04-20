<#
Get-SvcTrigStack.ps1
Requires logparser.exe in path
Pulls stack rank of Service Triggers from acquired Service Trigger data
ToDo: 
Add check for logparser.exe in path
Add check for *svctrigs.tsv in current path
#>

$lpquery = @"
SELECT
    COUNT(Condition, Value) as ct, 
    ServiceName, 
    Action, 
    Condition, 
    Value 
FROM
    *svctrigs.tsv 
GROUP BY
    ServiceName, 
    Action, 
    Condition, 
    Value 
ORDER BY
    ct ASC
"@

& logparser -i:tsv -fixedsep:on -dtlines:0 -rtp:50 $lpquery