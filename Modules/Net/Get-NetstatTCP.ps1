Function Get-NetStat {
<#
   .SYNOPSIS 
       Get a "better" Netstat.
   .DESCRIPTION 
       Get ProcessId,ProcessName,ParentProcessID,Path,CommandLine,ThreadCount,UserName,LocalPort,RemoteAddress,RemotePort,State,
       Hostname, and Timestamp
   .EXAMPLE 
       PS C:\> Get-NetStat | Out-GridView
   .EXAMPLE 
       PS C:\> Get-NetStat
#>
    $a=@{};Get-WmiObject win32_process | select -Property ProcessId,ProcessName,ParentProcessID,Path,CommandLine,ThreadCount|%{
            $a[$_.ProcessId]=$_};$b=@{};Get-Process -IncludeUserName | select -Property ID,UserName|%{$b[[int]$_.Id]=$_};
            $NetStat=Get-NetTCPConnection|select -Property LocalAddress,LocalPort,RemoteAddress,RemotePort,State,
                @{Name="PID";Expression={$_.OwningProcess}},
                @{Name="ProcessName";Expression={$a[$_.OwningProcess].ProcessName}},
                @{Name="ThreadCount";Expression={$a[$_.OwningProcess].ThreadCount}},
                @{Name="Path";Expression={$a[$_.OwningProcess].Path}},
                @{Name="ParentPID";Expression={$a[$_.OwningProcess].ParentProcessID}},
                @{Name="CommandLine";Expression={$a[$_.OwningProcess].CommandLine}},
                @{Name="UserName";Expression={$b[[int]$_.OwningProcess].UserName}},
                @{Name="host";Expression={$env:COMPUTERNAME}},
                @{Name="ts";Expression={Get-Date -Format "o"}}|? -Property LocalAddress -NE '127.0.0.1'|? -Property LocalAddress -NE '::';
    $NetStat}
    
