# This module is intended to inventory all of the endpoint security tools expected to be present on a workstation/server
# and determine their status. Attackers may attempt to hide by disabling security tools, so the absence of a security
# tool may serve as an indicator or suspicious activity. At a minimum it indicates a security blindspot or control 
# failure, and may indicate a larger IT problem with package management. Hashtables of process names, key file locations,
# product installation names, and service names should be passed in as arguments.  The key values must all be unique
# since each host will submit a single record with the status of ALL agents. Winlogbeat is used as a default example
# below.

if(!(Get-Variable -Name processNames -ErrorAction SilentlyContinue)){$processNames = @{Winlogbeat = "winlogbeat.exe";}}
if(!(Get-Variable -Name fileSystemLocation -ErrorAction SilentlyContinue)){$fileSystemLocation = @{WinlogbeatFile = "$env:SystemDrive\Program Files\winlogbeat\winlogbeat.exe";}}
if(!(Get-Variable -Name installedPrograms -ErrorAction SilentlyContinue)){$installedPrograms = @{WinlogbeatInstalledSW = "winlogbeat"}}
if(!(Get-Variable -Name services -ErrorAction SilentlyContinue)){$services = @{WinlogbeatSvc = "winlogbeat";}}
    
$result = @{}
$procs = Get-WmiObject -Query "Select * from win32_process" | select ProcessName,Path,CommandLine,ProcessId,ParentProcessId
$procs | % { $_.processname = $_.processname.tolower() }
if ($procs -eq $null) {
    $result.add("Error","Process List was Null")
} else{
    $processNames.Keys | %{
        if($procs.ProcessName.IndexOf($processNames.$_) -gt 0){
            $result.Add($_,"Running")
            $result.Add("$_ Path",$procs[$procs.ProcessName.IndexOf($processNames.$_)].Path)
            $result.Add("$_ CommandLine",$procs[$procs.ProcessName.IndexOf($processNames.$_)].CommandLine)
            $result.Add("$_ PID",$procs[$procs.ProcessName.IndexOf($processNames.$_)].ProcessId)
            $PPID = $procs[$procs.ProcessName.IndexOf($processNames.$_)].ParentProcessId
            $result.Add("$_ PPID",$PPID)
            if($PPID -gt 0){ $result.Add("$_ ParentProcessName", ($procs | where ProcessId -EQ $PPID).ProcessName )}
        }else{
            $result.Add($_,"Not Running")
        }
    }

    $fileSystemLocation.Keys | %{
        if(Test-Path -PathType Leaf -Path $($fileSystemLocation.$_)){
            $result.add($_, "Exists")
            $result.add("$_ Location", $($fileSystemLocation.$_))
            $file = gi -Path $($fileSystemLocation.$_)
            $result.Add("$_ Size",$file.Length)
            $result.Add("$_ MD5", $(Get-FileHash -Algorithm MD5 $file).Hash)
            $result.Add("$_ SHA256", $(Get-FileHash -Algorithm SHA256 $file).Hash)
            $result.Add("$_ Created","$($file.CreationTime)")
        }elseif(Test-Path -PathType Leaf -Path $($fileSystemLocation.$_ -replace "\\Program Files\\","\Program Files (x86)\")){
            $result.add($_, "Exists")
            $result.add("$_ Location", $($fileSystemLocation.$_ -replace "\\Program Files\\","\Program Files (x86)\"))
            $file = gi -Path $($fileSystemLocation.$_ -replace "\\Program Files\\","\Program Files (x86)\")
            $result.Add("$_ Size",$file.Length)
            $result.Add("$_ MD5", $(Get-FileHash -Algorithm MD5 $file).Hash)
            $result.Add("$_ SHA256", $(Get-FileHash -Algorithm SHA256 $file).Hash)
            $result.Add("$_ Created","$($file.CreationTime)")
        }else{
            $result.add($_, "Not Present")
        }
    }

    $prgrms = Get-WmiObject -Class Win32_Product | Select-Object Name, Version | Sort-Object Name
    $installedPrograms.keys | %{
        $i = $prgrms | Where Name -Match $($installedPrograms.$_) | select -First 1
        $result.Add($_, $i.Version)
    }

    $services.Keys | %{
        $svcQuery = "name='" + $services.$_ + "'"
        $tmp = (get-wmiobject win32_service -filter "$svcQuery")
        if($tmp){
            $result.Add($_, "Installed")
            $result.Add("$_ State", $tmp.State)
            $result.Add("$_ StartMode", $tmp.StartMode)
            $result.Add("$_ ExitCode", $tmp.ExitCode)
        }else{
            $result.Add($_, "Not Installed")
        }
    }
}
#$result.GetEnumerator() | sort -Property Name
Add-Result -hashtbl $result
