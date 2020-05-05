# Looking at network connections can be interesting to identify lateral movement, c@, exfil, beaconing, etc...
# Even with all the netflow from routers and firewall logs, without sysmon event_id:3 logs it is difficult to 
# gain visibility into intra-vlan/switched traffic.  This module performs a snapshot in time taking the 
# netstat output and enriching it with local DNS cache and process info.  Sending it back to ELK allows for
# large scale analytics to identify outliers. Analysts/Hunters can pivot on many facets including 
# low-frequency of occurrence / stacking of binaries/hashes making network connections, unique comamndlines
# internal-internal or external traffic, unusual ports, strange paths, etc... Obviously sysmon event_id:3
# data will be more realtime

function get-netstat-cmdline-dns{
    $props = [ordered]@{
    RecordName = ""
    RecordType = ""
    Section    = ""
    TimeToLive = 0
    DataLength = 0
    Data       = ""
    }
    $dnsRecords = @()

    $cache = ipconfig /displaydns
    for($i=0; $i -le ($cache.Count -1); $i++) {
        if ($cache[$i] -like '*Record Name*'){
            $rec = New-Object -TypeName psobject -Property $props
            $rec.RecordName = ($cache[$i] -split ': ')[1].Trim()
            $rec.Section = ($cache[$i+4] -split ': ')[1].Trim()
            $rec.TimeToLive = ($cache[$i+2] -split ': ')[1].Trim()
            $rec.DataLength = ($cache[$i+3] -split ': ')[1].Trim()
            $irec = ($cache[$i+5] -split ': ')
            $rec.RecordType = ($irec[0].TrimStart() -split ' ')[0]
            $rec.Data = $irec[1]

            $dnsRecords += $rec
        } else {
            continue
        }
    }
    #$dnsRecords | Format-Table –AutoSize

    $data = netstat -ano
    $data = $data[4..$data.count]
    $psnetstat = New-Object -TypeName System.Collections.ArrayList
    $WMIProcess = Get-WmiObject -query 'Select * from win32_process' | Select Name,ProcessId,ParentProcessId,CommandLine,CreationDate,Description,Path
    $procs = Get-Process -IncludeUserName
    $FilehashesMD5 = @{}
    $FilehashesSHA256 = @{}
    foreach ($line in $data){
        # Remove the whitespace at the beginning on the line
        $line = $line -replace '^\s+', ''
            # Split on whitespaces characteres
        $line = $line -split '\s+'
            # Define Properties
        if($line[1] -match '::'){
            $localIP,$localPort = $line[1] -replace '::','*' -split ':' -replace "\*",'::'
            $foreignIP,$foreignPort = $line[2] -replace '::','*' -split ':' -replace "\*",'::'
        } else {
            $localIP,$localPort = $line[1] -split ':'
            $foreignIP,$foreignPort = $line[2] -split ':'
        }
        $protocol = $line[0]
        If($protocol -eq "TCP"){
            $state = $line[3]
            $mypid = $line[4]
        } else {
            $state = "STATELESS"
            $mypid = $line[3]
        }
        $process = ($WMIProcess | where ProcessId -EQ $mypid | Select Name).Name
        $processPath = ($WMIProcess | where ProcessId -EQ $mypid | Select Path).Path
        $processFileHashMD5 = ""
        $processFileHashSHA256 = ""
        if($processPath -and $FilehashesMD5.ContainsKey($processPath)){
            $processFileHashMD5 = $FilehashesMD5.$processPath
            $processFileHashSHA256 = $FilehashesSHA256.$processPath
        }elseif($processPath){
            $processFileHashMD5 = (Get-FileHash -Algorithm MD5 -Path $processPath).Hash
            $processFileHashSHA256 = (Get-FileHash -Algorithm SHA256 -Path $processPath).Hash
            $FilehashesMD5.Add($processPath, $processFileHashMD5)
            $FilehashesSHA256.Add($processPath, $processFileHashSHA256)
        }
        $parentPid = ($WMIProcess | where ProcessId -EQ $mypid | Select ParentProcessId).ParentProcessId
        $parentProcess = ($WMIProcess | where ProcessId -EQ $parentPid | Select Name).Name
        $parentProcessPath = ($WMIProcess | where ProcessId -EQ $parentPid | Select Path).Path
        $parentProcessFileHashMD5 = ""
        $parentProcessFileHashSHA256 = ""
        if($parentProcessPath -and $FilehashesMD5.ContainsKey($parentProcessPath)){
            $parentProcessFileHashMD5 = $FilehashesMD5.$processPath
            $parentProcessFileHashSHA256 = $FilehashesSHA256.$processPath
        }elseif($parentProcessPath){
            $parentProcessFileHashMD5 = (Get-FileHash -Algorithm MD5 -Path $parentProcessPath).Hash
            $parentProcessFileHashSHA256 = (Get-FileHash -Algorithm SHA256 -Path $parentProcessPath).Hash
            $FilehashesMD5.Add($parentProcessPath, $parentProcessFileHashMD5)
            $FilehashesSHA256.Add($parentProcessPath, $parentProcessFileHashSHA256)
        }
        $cmdline = ($WMIProcess | where ProcessId -EQ $mypid | Select CommandLine).CommandLine
        $forAddr = ($dnsRecords | where Data -EQ $foreignIP | Select RecordName).RecordName
        $user = ($procs | where Id -EQ $mypid | select UserName).UserName
        $properties = @{
            Protocol = $protocol
            LocalAddress = $localIP
            LocalPort = $localPort
            RemoteAddress = $foreignIP
            RemotePort = $foreignPort
            RemoteHostname = $forAddr
            State = $state
            Pid = $mypid
            ParentPid = $parentPid
            Process = $process
            ProcessPath = $processPath
            ProcessFileHashMD5 = $processFileHashMD5
            ProcessFileHashSHA256 = $processFileHashSHA256
            ParentProcess = $parentProcess
            ParentProcessPath = $parentProcessPath
            ParentProcessFileHashMD5 = $parentProcessFileHashMD5
            ParentProcessFileHashSHA256 = $parentProcessFileHashSHA256
            CmdLine = $cmdline
            User = $user
        }    
        # Output object
        [void]$psnetstat.add((New-Object -TypeName PSObject -Property $properties))
    }
    return $psnetstat
}

$psnetstat = get-netstat-cmdline-dns

foreach($row in $psnetstat){
    $result = @{}
    $row.psobject.properties | %{$result.Add($_.name,$_.value)}
    Add-Result -hashtbl $result
}
