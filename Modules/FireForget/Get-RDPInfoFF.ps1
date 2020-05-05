# With RDP being a common porotocl/service leveraged for initial access or lateral movement many attackers seek to
# change the RDP configuration on endpoints to maintain access.  This module will enumerate many o fthe common RDP
# settings in the registry as well as any saved RDP profiles to see if defaults have been changed to downgrade
# connection security (such as disabling NLA for remote connections, or allowing inbound requests/users). The
# module also checks to ensure that the terminal services service is running on the designated port and has not
# been moved to another port that is more likely to be allowed through a firewall or avoid network scrutiny.

if(!(Get-Variable -Name DirWalk -ErrorAction SilentlyContinue)){$DirWalk = $true}
if(!(Get-Variable -Name FileStartPath -ErrorAction SilentlyContinue)){$FileStartPath = "$env:SystemDrive\"}
if(!(Get-Variable -Name FileExtensions -ErrorAction SilentlyContinue)){$FileExtensions = "*.rdp"}

$p = Get-ItemProperty "REGISTRY::HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" | select PortNumber
$d = Get-ItemProperty "REGISTRY::HKLM\System\CurrentControlSet\Control\Terminal Server" | select fDenyTSConnections
$u = Get-ItemProperty "REGISTRY::HKLM\System\CurrentControlSet\Control\Terminal Server" | select TSUserEnabled
$a = Get-ItemProperty "REGISTRY::HKLM\System\CurrentControlSet\Control\Terminal Server" | select AllowTSConnections
$rdpProcess = Get-WmiObject -Query "Select * from win32_process" | select ProcessName,Path,CommandLine,ProcessId,ParentProcessId | where CommandLine -Match "TermService"
$s = netstat -ano | Select-String -Pattern "\s$($rdpProcess.ProcessId)$" | select -First 1
$s2 = $s | ?{ $_ -match ":"}
$s3 = $s2.tostring().trim() -split "\s+" | select -Skip 1 -First 1
$listeningPort = $s3 -split ":" | select -Last 1

$regPort = 3389
$deny = 1
$userEnabled = 0
$allow = 0
if($p.PortNumber){
    $regPort = $p.PortNumber
}
if($d.fDenyTSConnections){
    $deny = $d.fDenyTSConnections
}
if($u.TSUserEnabled){
    $userEnabled = $u.TSUserEnabled
}
if($a.AllowTSConnections){
    $allow = $a.AllowTSConnections
}

$result = @{}
$result.Add("RegistryRDPPort",$regPort)
$result.Add("RegistryRDPDenyConnections",$deny)
$result.Add("RegistryRDPTSUserEnabled",$userEnabled)
$result.Add("RegistryRDPAllowTSConnections",$allow)
$result.Add("ListeningPortRDPService",$listeningPort -as [int32])
Add-Result -hashtbl $result 

if($DirWalk){
    $files = enhancedGCI -startPath $FileStartPath -extensions $FileExtensions
    $files | %{
        $test = gc $_ | Select-String -Pattern "enablecredsspsupport:i:0"
        if($test){
            $result = @{}
            $result = Get-FileDetails -hashtbl $result -filepath $_ -computeHash -algorithm @("MD5", "SHA256") -getContent
            $foundNLAbypass = $true
            $result.Add("FoundNLABypass",$foundNLAbypass)
            Add-Result -hashtbl $result
        }
    }
}
