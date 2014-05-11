# OUTPUT tsv
<#
.SYNOPSIS
Get-SchedTaskActsTrigs.ps1
Returns Scheduled Tasknames, Actions, Triggers, TaskPath, Authors and Dates.
#>

<#
Get-ScheduledTask | % {
    $o = "" | Select-Object Taskname, Actions, Triggers, TaskPath, Author, Date
    $o.Taskname = $_.Taskname
    $o.Actions  = ($_).Actions
    $o.Triggers = $($_.Triggers)
    $o.TaskPath = $($_.TaskPath)
    $o.Author   = $($_.Author)
    $o.Date     = $($_.Date)
    $o
}
#>


<#
foreach($TaskName in ((Get-ScheduledTask).TaskName)) {
    #$o = "" | Select-Object Taskname, 
    (Get-ScheduledTask | ? { $_.TaskName -eq $TaskName }).Actions
    (Get-ScheduledTask | ? { $_.TaskName -eq $TaskName }).Triggers
}
#>

Get-ScheduledTask | % {
    $o = "" | Select-Object Taskname, TaskPath, Author, Date, AId, 
        Arguments, Execute, WorkingDirectory, Enabled, EndBoundary, 
        ExecutionTimeLimit, TId, Repetition, StartBoundary, RandomDelay
    $o.TaskName           = $_.TaskName
    $o.TaskPath           = $_.TaskPath
    $o.Author             = $_.Author
    $o.Date               = $_.Date
    $o.AId                = $_.Actions       | Foreach { $_.Id }
    $o.Arguments          = $_.Actions       | Foreach { $_.Arguments }
    $o.Execute            = $_.Actions       | Foreach { $_.Execute }
    $o.WorkingDirectory   = $_.Actions       | Foreach { $_.WorkingDirectory }
    $o.Enabled            = $_.Triggers      | Foreach { $_.Enabled }
    $o.EndBoundary        = $_.Triggers      | Foreach { $_.EndBoundary }
    $o.ExecutionTimeLimit = $_.Triggers      | Foreach { $_.ExecutionTimeLimit }
    $o.TId                = $_.TId           | Foreach { $_.Id }
    $o.Repetition         = $_.Repetition    | Foreach { $_.Repetition }
    $o.StartBoundary      = $_.StartBoundary | Foreach { $_.StartBoundary }
    $o.RandomDelay        = $_.RandomDelay   | Foreach { $_.RandomDelay }
    $o
<#
    $_.Actions
    $_.Triggers
#>
}