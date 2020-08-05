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
$NetworkObject=@{}
$ProcessObject=@{}

Get-CimInstance -Namespace root/cimv2 -ClassName win32_process|
   Select-Object ProcessName,Path,CommandLine,ExecutablePath,Handle,ProcessId,ParentProcessID,ThreadCount,
      @{Name="User";Expression={($_|Invoke-CimMethod -MethodName GetOwner).User};},
      @{Name="Domain";Expression={($_|Invoke-CimMethod -MethodName GetOwner).Domain};}|
         %{$ProcessObject[[int]$_.Handle]=$_}

Get-CimInstance -Namespace root/StandardCimv2 -ClassName MSFT_NetTCPConnection|
   Select-Object CreationTime,LocalAddress,LocalPort,OwningProcess,RemoteAddress,RemotePort,PSComputerName,
      @{Name="Protocol";Expression={"TCP"};}|
         %{$NetworkObject[[int]$_.OwningProcess]=$_}

Get-CimInstance -Namespace root/StandardCimv2 -ClassName MSFT_NetUDPEndpoint|
   Select-Object CreationTime,LocalAddress,LocalPort,OwningProcess,RemoteAddress,RemotePort,PSComputerName,
      @{Name="Protocol";Expression={"UDP"};}|
         %{$NetworkObject[[int]$_.OwningProcess]=$_}

$NetworkObject.keys|%{
   $NetworkObject[$_]|
      Select-Object CreationTime,Protocol,LocalAddress,LocalPort,OwningProcess,RemoteAddress,RemotePort,PSComputerName,
         @{Name="ProcessName";Expression={$ProcessObject[[int]$_.OwningProcess].ProcessName}},
         @{Name="Path";Expression={$ProcessObject[[int]$_.OwningProcess].Path}},
         @{Name="CommandLine";Expression={$ProcessObject[[int]$_.OwningProcess].CommandLine}},
         @{Name="ExecutablePath";Expression={$ProcessObject[[int]$_.OwningProcess].ExecutablePath}},
         @{Name="Handle";Expression={$ProcessObject[[int]$_.OwningProcess].Handle}},
         @{Name="ProcessId";Expression={$ProcessObject[[int]$_.OwningProcess].ProcessId}},
         @{Name="ParentProcessID";Expression={$ProcessObject[[int]$_.OwningProcess].ParentProcessID}},
         @{Name="ThreadCount";Expression={$ProcessObject[[int]$_.OwningProcess].ThreadCount}},
         @{Name="Domain";Expression={$ProcessObject[[int]$_.OwningProcess].Domain}},
         @{Name="User";Expression={$ProcessObject[[int]$_.OwningProcess].User}},
         @{Name="Timestamp";Expression={Get-Date -Format "o"}}
   }
}
    
