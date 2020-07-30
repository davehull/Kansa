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
      @{Name="User";Expression={($|Invoke-CimMethod -MethodName GetOwner).User};},
      @{Name="Domain";Expression={($|Invoke-CimMethod -MethodName GetOwner).Domain};}|
         %{$ProcessObject[[int]$.Handle]=$}

Get-CimInstance -Namespace root/StandardCimv2 -ClassName MSFT_NetTCPConnection|
   Select-Object CreationTime,LocalAddress,LocalPort,OwningProcess,RemoteAddress,RemotePort,PSComputerName,
      @{Name="Protocol";Expression={"TCP"};}|
         %{$NetworkObject[[int]$.OwningProcess]=$}

Get-CimInstance -Namespace root/StandardCimv2 -ClassName MSFT_NetUDPEndpoint|
   Select-Object CreationTime,LocalAddress,LocalPort,OwningProcess,RemoteAddress,RemotePort,PSComputerName,
      @{Name="Protocol";Expression={"UDP"};}|
         %{$NetworkObject[[int]$.OwningProcess]=$}

$NetworkObject.keys|%{
   $NetworkObject[$]|
      Select-Object CreationTime,Protocol,LocalAddress,LocalPort,OwningProcess,RemoteAddress,RemotePort,PSComputerName,
         @{Name="ProcessName";Expression={$ProcessObject[[int]$.OwningProcess].ProcessName}},
         @{Name="Path";Expression={$ProcessObject[[int]$.OwningProcess].Path}},
         @{Name="CommandLine";Expression={$ProcessObject[[int]$.OwningProcess].CommandLine}},
         @{Name="ExecutablePath";Expression={$ProcessObject[[int]$.OwningProcess].ExecutablePath}},
         @{Name="Handle";Expression={$ProcessObject[[int]$.OwningProcess].Handle}},
         @{Name="ProcessId";Expression={$ProcessObject[[int]$.OwningProcess].ProcessId}},
         @{Name="ParentProcessID";Expression={$ProcessObject[[int]$.OwningProcess].ParentProcessID}},
         @{Name="ThreadCount";Expression={$ProcessObject[[int]$.OwningProcess].ThreadCount}},
         @{Name="Domain";Expression={$ProcessObject[[int]$.OwningProcess].Domain}},
         @{Name="User";Expression={$ProcessObject[[int]$_.OwningProcess].User}}
   }
}
    
