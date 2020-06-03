# This module collects the ARP table routing table, interface configs, and route-forwarding information
# from a target.  It can be used to identify potential arp-spoofing/poisoning in an environment by
# comparing hop counts and cached arp info for IP addresses.

#parse the windows ARP table into a PS object
Function Get-Arp{
    $output = arp -a 
    $output = $output[3..($output.length-2)]  # get rid of first three lines
    $output | foreach {
        $parts = $_ -split "\s+", 6
        New-Object -Type PSObject -Property @{
            InternetAddress = $parts[1]
            PhysicalAddress = $parts[2]
            Type = $parts[3]
        }
    }
}

$key = Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters
$o = "" | Select-Object IProutingRegKey,IP,Gateway,Mask,IProutingSvcState,IProutingSvcStart
if ($key.IPEnableRouter -eq 1) { 
    $o.IProutingRegKey = "Enabled"
} else {
    $o.IProutingRegKey = "Disabled"
}

$ipconfig = ipconfig

$o.IP = @($ipconfig | where-object {$_ -match "IPv4 Address"} | foreach-object{$_.Split(":")[-1].Trim()})
$o.Gateway = @($ipconfig | where-object {$_ -match "Default Gateway"} | foreach-object{$_.Split(":")[-1].Trim()})
$o.Mask = @($ipconfig | where-object {$_ -match "Subnet Mask"} | foreach-object{$_.Split(":")[-1].Trim()})
$o.IProutingSvcState = @(c:\windows\system32\sc.exe query RemoteAccess | Where-Object {$_ -Match "STATE"} | foreach-object{$_.Split(":")[-1].Trim()})
$o.IProutingSvcStart = @(c:\windows\system32\sc.exe qc RemoteAccess | Where-Object {$_ -Match "START_TYPE"} | foreach-object{$_.Split(":")[-1].Trim()})

for ($i=0; $i -lt $o.IP.Count; $i++){
    $pingGW = ""
    $GWTTL = ""

    $result = @{}
        
    $result.add("IProutingRegKey", "$($o.IProutingRegKey)")
    $result.add("IProutingSvcState", $o.IProutingSvcState[0])
    $result.add("IProutingSvcStart", $o.IProutingSvcStart[0])
    $result.add("IP","$($o.IP[$i])")
    $result.add("SubnetMask", "$($o.Mask[$i])")
    $result.add("Gateway", "$($o.Gateway[$i])")
    if ($o.Gateway -ne $null){ 
        $pingGW = ping -n 1 -4 $o.Gateway[$i] | Where-Object {$_ -match "Reply"}
        $GWTTL = $pingGW.Split("TTL=")[-1].Trim()
        $traceGW = tracert -d -h 4 -4 $o.Gateway[$i] | Where-Object {$_ -match "ms"} | select -Last 1
    }
    if (test-path REGISTRY::HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\PortProxy\v4tov4\tcp) {
        $portproxies = (Get-ItemProperty REGISTRY::HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\PortProxy\v4tov4\tcp).psobject.Properties | where Name -NotMatch "PS(Provider|ChildName|ParentPath|Path)"
        $i = 0
        $portproxies | % {
            if($result.containsKey(("PortProxySrc" + $i))){
                $i += 1
            }
            $result.add(("PortProxySrc" + $i), $_.Name)
            $result.add(("PortProxyDst" + $i), $_.Value)
        }
    }
    $a = (Get-Date).AddDays(-10)
    $rdpSrcs = Get-EventLog -LogName Security -after $a | Where-Object {($_.EventID -eq '4624') -and  ($_.EntryType -eq 'SuccessAudit') -and ($_.Message | Select-String "Logon Type:\t\t\t10")} | select Message | select-string -Pattern "Source Network Address:.*\r\n" -AllMatches | %{$_.Matches} | % {($_.Value).Trim() -replace "Source Network Address:\t",""}
    if($rdpSrcs){$result.add("RDPsources", $rdpSrcs)}
    $result.add("GatewayPing", "$pingGW")
    $result.add("GatewayTTL", $GWTTL)
    $result.add("traceGW", $traceGW.Trim())
    $mygwMAC = get-arp | where InternetAddress -EQ $o.Gateway[$i] | select PhysicalAddress,Type
    $result.add("GatewayHW", "$($mygwMAC.PhysicalAddress)")
    $result.add("GatewayHWtype", $mygwMAC.Type)
    $result.add("InterfaceCount", $o.IP.Count)
    Add-Result -hashtbl $result
}
