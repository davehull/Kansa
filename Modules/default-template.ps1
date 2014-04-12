$Ext = ".txt"
<#
.SYNOPSIS
Default module template
Put the file extension for your output inside the quotes on the first line
Output from the module should be written using Write-Output or just sent
to the pipeline, the calling script will handle writing the output to a
file.

Because modules are only intended to be used to collect data, they should
be named according to the verb-noun convention, in this case "Get-Data.ps1"
where "Data" is the element your script is written to collect.
#>