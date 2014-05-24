# OUTPUT tsv
<#
.SYNOPSIS
Get-SvcAll.ps1
Returns Service's Name, DisplayName, PathName, StartName, StartMode, State, TotalSessions, Description
#>

Get-WmiObject win32_service | % {
    $o = "" | Select-Object Name, DisplayName, PathName, StartName, StartMode, State, TotalSessions, Description
    $o.Name          = $_.Name
    $o.DisplayName   = $_.DisplayName
    $o.PathName      = $_.PathName
    $o.StartName     = $_.StartName
    $o.StartMode     = $_.StartMode 
    $o.State         = $_.State
    $o.TotalSessions = $_.TotalSessions
    $o.Description   = $_.Description
    $o
}