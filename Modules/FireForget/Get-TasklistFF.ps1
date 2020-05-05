# Simple module to grab the contents of the tasklist command, parse them, and send them into ELK
# This module is the less resource-intensive version of the get-RunningProcessesAndModules kansa
# module and collects much less data so it may be better for simple analytics to ID outliers or
# as a first pass to inspect a system that is exhibiting unusual behaviors

& $env:windir\system32\tasklist.exe /v /fo csv | Select-Object -Skip 1 | % {
    $o = "" | Select-Object HostName,ImageName,PID,SessionName,SessionNum,MemUsage,Status,UserName,CPUTime,WindowTitle,timeStamp
    $row = $_ -replace '(,)(?=(?:[^"]|"[^"]*")*$)', "`t" -replace "`""
    $o.HostName = $env:COMPUTERNAME
    $o.ImageName, 
    $o.PID,
    $o.SessionName,
    $o.SessionNum,
    $o.MemUsage,
    $o.Status,
    $o.UserName,
    $o.CPUTime,
    $o.WindowTitle = ( $row -split "`t" )
    
    $result = @{}
    $result.add("ImageName",$o.ImageName)
    $result.add("PID",$o.PID)
    $result.add("SessionName",$o.SessionName)
    $result.add("SessionNum",$o.SessionNum)
    $result.add("MemUsage",$o.MemUsage)
    $result.add("Status",$o.Status)
    $result.add("Username",$o.UserName)
    $result.add("CPUTime",$o.CPUTime)
    $result.add("WindowTitle",$o.WindowTitle)
    Add-Result -hashtbl $result
}
