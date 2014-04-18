<#
Get-ASEPImagePathLaunchStringStack.ps1
Requires logparser.exe in path
Pulls frequency of autoruns based on [Image Path] and [Launch String] tuple
ToDo: 
Add check for logparser.exe in path
Add check for *svctrigs.tsv in current path
#>

& logparser -i:csv -dtlines:0 -rtp:50 "select Count([Image Path], [Launch String]) as ct, [Image Path], [Launch String] from *autorunsc.txt where Publisher not like '(Verified)%' group by [Image Path], [Launch String] order by ct asc"