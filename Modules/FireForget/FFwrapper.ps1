# This module is used to wrap individual Fire&Forget Kansa modules with
# all the basic/common functions necessary to send results back to ELK
# and collect metrics along with safety mechanisms to control execution
# in a large enterprise environment. It also includes functions like
# a recursive file search algorithm that doesn't trip over symlinks or
# junctions, and a function to get metadata about a target file.
# Special comment tags are used to tell the kansa framework how to 
# splice the code from the wrapper around the target module at launch.

# DO NOT REMOVE THE FOLLOWING LINE
#<InsertModuleNameHERE>

$scriptblock_str = @'
# Array used to collect individual result hashtables and store them until they are shipped
$RESULTS_FINAL = New-Object -TypeName System.Collections.ArrayList

# Global variable for tracking total number of records produced/sent
$global:RESULTS_COUNT = 0

# Sends a single record to ELK.  Not intended to be called directly by module code
function Send-ElkAlert{
    param(
        [object]$writer,
        [string]$alertContent = ""
    )
    if(($writer -eq $null) -or ($alertContent -eq $null)) { return;}
    $SLmessage = $alertContent.Replace("`r`n", '')
    $writer.WriteLine($SLmessage)
}

# Helper function for modules. Any results that should be collected and sent to ELK should be added
# using this function.  A stub function that simulates this capability is included in the FFdevTemplate
function Add-Result{
    param([object]$hashtbl)
    if(!$hashtbl.ContainsKey("Hostname")){$hashtbl.add("Hostname",$global:hostname)}
    if(!$hashtbl.ContainsKey("KansaModule")){$hashtbl.add("KansaModule",$global:moduleName)}
    if(!$hashtbl.ContainsKey("HuntID")){$hashtbl.add("HuntID",$HuntID)}
    $result = New-Object -TypeName psobject
    $hashtbl.getenumerator() | % {$result | Add-member -membertype NoteProperty -Name $_.Name -Value $_.Value}
    [void]$RESULTS_FINAL.add($result)
    if($global:RESULTS_FINAL.count -gt 500){
        Send-Results
    }
}

# Helper function used mostly for metrics to collect info on the most recently LoggedOn user by comparing
# LastModified timestamps of NTuser.dat files
function Get-LLOuser{
    $o = "" | Select UserID,Name,Title,Dept,Div,Cmpny,Desc,Home,Email,PasswdExp,LogonDate,LogonDateNT
    $uDir = gci "$($env:SystemDrive)\Users"
    $dats = @()
    foreach ($uProf in $uDir) { $dats += gci -Fo $uProf.FullName -Fi "NTUSER.dat" }
    $User = ($dats | Sort {[DateTime]$_.LastWriteTime} | Select -L 1 | Select Directory | Split-Path -Leaf) -replace '}',''
    $NTUserDate = ($dats | Sort {[DateTime]$_.LastWriteTime} | Select -L 1 | Select LastWriteTime).LastWriteTime.tostring()
    $UserDate = (gi ($dats | Sort {[DateTime]$_.LastWriteTime} | Select -L 1 | Select Directory).Directory | select LastWriteTime).LastWriteTime.ToString()
    $oUser = new-object System.Security.Principal.NTAccount("$domain", "$User")
    $strSID = $oUser.Translate([System.Security.Principal.SecurityIdentifier])
    $strFltr = "(objectSID=$($strSID.Value))"
    $objDomain = New-Object System.DirectoryServices.DirectoryEntry
    #$objDomain.RefreshCache()
    #start-sleep 10
    $objSearcher = New-Object System.DirectoryServices.DirectorySearcher
    $objSearcher.SearchRoot = $objDomain
    $objSearcher.PageSize = 500
    $objSearcher.Filter = $strFltr
    #$objSearcher.CacheResults = $True
    #$objSearcher.SearchScope = "Subtree"
    $o.UserID = $User
    $o.LogonDate = $UserDate
    $o.LogonDateNT = $NTUserDate
    try{
        $colResults = $objSearcher.FindAll()
        if($colResults -and $colResults[0] -ne $null){            
            $o.Name = $($colResults[0].properties.name)
            $o.Dept = [System.Text.Encoding]::ASCII.GetString($($colResults[0].properties.department))
            $o.Title = $($colResults[0].properties.title)
            $o.Div = [System.Text.Encoding]::ASCII.GetString($($colResults[0].properties.division))
            $o.Desc = [System.Text.Encoding]::ASCII.GetString($($colResults[0].properties.admindescription))
            $o.Email = $($colResults[0].properties.mail)
            $o.Cmpny = [System.Text.Encoding]::ASCII.GetString($($colResults[0].properties.company))
            $o.Home = [System.Text.Encoding]::ASCII.GetString($($colResults[0].properties.homedirectory))
            $o.PasswdExp = $($colResults[0].properties.whenchanged)
        }
    }
    catch{ 
        #$_ | Out-File C:\temp\kansa_errors.txt -Append 
    }
    $o
}

# Helper function to enumerate installed software packages by registry and WMI repos
# Still under development
function Get-InstalledSW{
    param([string]$regex=".")
    $sw = @{}
    $software = @()
    $software += gci "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" | foreach { gp $_.PSPath } | ? { $_ -match $regex } | Select-Object -Property DisplayName,DisplayVersion
    $software += gci "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | foreach { gp $_.PSPath } | ? { $_ -match $regex } | Select-Object -Property DisplayName,DisplayVersion
    
    if($software){
        $sw.add("UninstallString",$uninstall)
        $WMIsoftware = Get-WmiObject -Class Win32_Product | where Name -match $regex 
        $i = 0
        foreach($app in $WMIsoftware){
            if($result2.ContainsKey("Application$i-Name")){$i++}
            $props = $app | Select Name,Version,Description,HelpLink,InstallDate,InstallSource,Vendor
            $props.psobject.properties | %{$sw.add("Application$i-$($_.Name)", "$($_.Value)")}
        }
    }
    return $sw
}

# Helper function designed to standardize the collection of common file metadata
function Get-FileDetails{
    param(
        [Parameter(Mandatory=$false,Position=0)]
            [hashtable]$hashtbl,
        [Parameter(Mandatory=$False,Position=1)]
            [string]$filepath = "",
        [Parameter(Mandatory=$False,Position=2)]
            [switch]$computeHash,
        [Parameter(Mandatory=$False,Position=3)]
            [ValidateSet("MD5","SHA1","SHA256")]
            [string[]]$algorithm="MD5",
        [Parameter(Mandatory=$False,Position=4)]
            [int]$maxHashSize=-1,
        [Parameter(Mandatory=$False,Position=5)]
            [switch]$getContent,
        [Parameter(Mandatory=$False,Position=6)]
            [int]$getMagicBytes=0,
        [Parameter(Mandatory=$False,Position=7)]
            [string]$prefix = ""
    )
    if($hashtbl -eq $null){
        $hashtbl = @{}
        $hashtbl.add("KansaModule",$global:moduleName)
        $hashtbl.add("Hostname",$global:hostname)
    }
    if(Test-Path -PathType Leaf -LiteralPath $filepath){
        $file = gi -Force -LiteralPath $filepath -ErrorAction SilentlyContinue
        $file.psobject.Properties | Where Name -NotMatch "(VersionInfo|^PS)" | select Name,Value | %{ 
            if($($_.Value) -and (($_.Value.GetType()) -match "long|bool") ){
                $hashtbl.add("$($prefix)File$($_.Name)",$_.Value)
            }else{
                $hashtbl.add("$($prefix)File$($_.Name)","$($_.Value)")
            }
            if(($_.Name -notmatch "Time|Length|Mode") -and ($_.Value) -and ($_.Value -notmatch "true|false")){$hashtbl.add("$($prefix)File$($_.Name)Lower","$($_.Value)".ToLower())}
        }
        $versioninfo = $file.VersionInfo.ToString().replace(': ','=').replace('\','\\') | ConvertFrom-StringData
        foreach ($element in $versioninfo.GetEnumerator()) { 
            if($element.Value){
                $hashtbl.add("$($prefix)FileVersion-$($element.name)",$element.value)
                if($element.Value -notmatch "true|false"){$hashtbl.add("$($prefix)FileVersion-$($element.name)Lower",$element.value.ToLower())}
            }
        }
        if ($computeHash -and (($maxHashSize -le 0) -or ($file.length -lt $maxHashSize))){
            $algorithm | %{ 
                $theHash = Get-FileHash -Path $file.FullName -Algorithm $_
                $hashtbl.add("$($prefix)FileHash$_",$theHash.Hash)
                $hashtbl.add("$($prefix)FileHash$($_)Lower",$theHash.Hash.ToLower())
            }
        }
        if ($file.Name -match '\.lnk$'){
            $wshell = New-Object -ComObject WScript.Shell
            $shrtct = $wshell.CreateShortcut($file.FullName)
            $rawTgt = gc $file.FullName | foreach-object { $_ -replace '[^\x20-\x7E]+', '*'} | Select-String '[^\*]*([A-Z]:\\|\\\\)[^\*]*' -AllMatches | foreach {$_.Matches.Value}
            $hashtbl.add("$($prefix)ShortcutTargetPath","$($shrtct.TargetPath)".ToLower())
            $hashtbl.add("$($prefix)ShortcutTargetPathRaw","$rawTgt".ToLower())
            $hashtbl.add("$($prefix)ShortcutArgs","$shrtct.Arguments")
            $hashtbl.add("$($prefix)ShortcutArgsLower","$($shrtct.Arguments)".ToLower())
            $hashtbl.add("$($prefix)ShortcutWorkingDir","$($shrtct.WorkingDirectory)".ToLower())
            if ($shrtct.TargetPath -match '.exe$'){
                $tgtHash = Get-FileHash -Path $shrtct.TargetPath -Algorithm MD5
                $hashtbl.add("$($prefix)ShortcutTargetHash",$tgtHash.Hash)
                $hashtbl.add("$($prefix)ShortcutTargetHashLower",$tgtHash.Hash.ToLower())
            }
            if ($shrtct.WindowStyle -ge 1 -and $shrtct.WindowStyle -le 7) {
                #$styles = @('Default','Default','Default','Maximized','Default','Default','Default','Minimized')
                $hashtbl.add("$($prefix)ShortcutWindowStyle",$styles[$shrtct.WindowStyle])
            }
        }
        if($getContent -and ($file.Name -match "\.(bat|js|vbs|py|wsf|sct|inf|ini|txt|url|website|cmd|pyw|ws|ps1|psm1|log|SettingContent-ms|appref-ms|rdp)$") ) {
            $content = gc -raw -LiteralPath $file.FullName #-Encoding Unicode #add this to clean unicode files
            if($content.Length -lt 10000){
                $hashtbl.add("$($prefix)FileContent", $content)
            }else{
                $hashtbl.add("$($prefix)FileContent", "Content greater than 10K")
                $hashtbl.add("$($prefix)FileContentTrunc10K", $content.Substring(0,9999))
            }
            $content = $null
            [System.GC]::Collect()
        }
        if(($getMagicBytes -gt 0) -and ($file.Length -gt $getMagicBytes)){
            $magicBytes = Get-MagicBytes -Path $filepath -ByteLimit $getMagicBytes
            $hashtbl.add("$($prefix)FileMagicBytesHex", $magicBytes.Hex)
            $hashtbl.add("$($prefix)FileMagicBytesHexLower", "$($magicBytes.Hex)".ToLower())
            $hashtbl.add("$($prefix)FileMagicBytesASCII", $magicBytes.ASCII)
        }
        $file = $null
    } else{
        $hashtbl.add("$($prefix)FileError", "File does not exist")
        $hashtbl.add("$($prefix)FileErrorPath", $filepath)
        $hashtbl.add("$($prefix)FileErrorPathLower", $filepath.ToLower())
    }
    return $hashtbl
}

# Helper function to retrieve the first n bytes of a file to assist in filetype determinations
# by default it will get the first 2 bytes of the target file starting at offset 0
function Get-MagicBytes{
    Param(
        [Parameter(Position=0,Mandatory=$true, ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$True)]
            [string[]]$Path,
        [parameter()]
            [int]$ByteLimit = 2,
        [parameter()]
            [int]$ByteOffset = 0
    )
    if((test-path $Path -PathType Leaf) -and ((gi -force $Path).Length -ge ($ByteOffset + $ByteLimit)) ){
        $Item = Get-Item -Force $Path
        $filestream = New-Object IO.FileStream($Item, [IO.FileMode]::Open, [IO.FileAccess]::Read)
        [void]$filestream.Seek($ByteOffset, [IO.SeekOrigin]::Begin)
        $bytebuffer = New-Object "Byte[]" ($filestream.Length - ($filestream.Length - $ByteLimit))
        [void]$filestream.Read($bytebuffer, 0, $bytebuffer.Length)
        $hexstringBuilder = New-Object Text.StringBuilder
        $stringBuilder = New-Object Text.StringBuilder
        For ($i=0;$i -lt $ByteLimit;$i++) {
            [void]$hexstringBuilder.Append(("{0:X}" -f $bytebuffer[$i]).PadLeft(2, "0"))
            If ([char]::IsLetterOrDigit($bytebuffer[$i]) -and ([int]$bytebuffer[$i] -lt 127)) {
                [void]$stringBuilder.Append([char]$bytebuffer[$i])
            } Else {
                [void]$stringBuilder.Append(".")
            }
        }
        $Hex = $hexstringBuilder.ToString()
        $ASCII = $stringBuilder.ToString()
        $item = $null
        $filestream.Close()
        $filestream = $null
        return [pscustomobject] @{
            Hex = $hexstringBuilder.ToString()
            ASCII = $stringBuilder.ToString()
        }
    } else{
        return [pscustomobject] @{
            Hex = "Unable to locate file or read specified offset + length"
            ASCII = "Unable to locate file or read specified offset + length"
        }
    }
}

# Simple function to hash large strings for easy filtering in Kibana
function Get-StringHash([String]$stringData, [ValidateSet("MD5","SHA1","SHA256")][String]$Algorithm="SHA256"){
    $strBuilder = New-Object System.Text.StringBuilder
    [System.Security.Cryptography.HashAlgorithm]::Create($Algorithm).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringData)) | %{
        [Void]$strBuilder.Append($_.toString("x2"))
    }
    return $strBuilder.ToString()
}

# The native powershell Get-ChildItems cmdlet has a nasty habit of getting stuck in an
# infinite recursive loop due to poor handling of filesystem symlinks/junctions. This
# helper function can be used to recursively search the whole filesystem for a file or
# folder using regular expressions and extension wildcards while safely handling
# symlinks/junctions. $extensions should be in the form @("*.exe","*.dll"). If the
# $extensions is omitted or blank ("") then it will default to "*.*". If one of the
# $extensions is invalid it will be omitted. If all $extensions are invalid the 
# function will return zero results.If searching for a folder instead of files use the
# -folder switch. Returns array of strings as matches.
function enhancedGCI{
    Param([String]$startPath,[String]$regex,[String[]]$extensions,[switch]$folder)
    if(!$startPath){
        $files = @()
        foreach($drive in $(gdr -PSProvider 'FileSystem' | select Name).Name){
            $files += enhancedGCI -startPath "$drive`:\" -extensions $extensions -regex $regex
        }
        return $files
    }
    if ($startPath -like '*\AppData\Local\Box*'){
        Return
    }
    if($extensions -eq ""){
        $extensions = "*.*"    
    }elseif($extensions -notmatch "\*\.([a-z0-9]|\-|_|\*)*"){
        $extensions = $extensions -match "\*\.([a-z0-9]|\-|_|\*)*"
        if(!$extensions){Return}
    }
    try{
       if($folder){
            $firstPass = [IO.Directory]::EnumerateDirectories($startPath)
            if($regex){
                $firstPass | where-object {$_ -Match $regex}
            }else{
                $firstPass
            } 
            
            $firstPass | % {
                if ([IO.File]::GetAttributes($_) -NotLike '*ReparsePoint*'){
                    enhancedGCI -startPath $_ -regex $regex -folder
                }
            }
        }else{
            foreach ($extension in $extensions){
                $firstPass = [IO.Directory]::EnumerateFiles($startPath, $extension)
                if($regex){
                    $firstPass | where-object {$_ -Match $regex}
                }else{
                    $firstPass
                } 
            }
            [IO.Directory]::EnumerateDirectories($startPath) | % { 
                if ([IO.File]::GetAttributes($_) -NotLike '*ReparsePoint*'){
                    enhancedGCI -startPath $_ -regex $regex -extensions $extensions
                }
            }
        }
    } catch {
    }
}

# Helper function to download a file from a server supporing a REST API
function Get-File{
    param( [string]$server="",[int]$port=80,[string[]]$filename="",[string]$targetPath="C:\utils\Hunt",[switch]$overwrite )
    $urlFileDownload = "http://$server"+':'+"$port/stage/dl/"
    if(!(Test-Path -PathType Container $targetPath)){ New-Item -ItemType directory -Path $targetPath | Out-Null }
    $filename | % { If(Test-Path -PathType Leaf "$targetPath\$_"){Remove-Item -Force "$targetPath\$_"} }
    foreach ($f in $filename){
        if($overwrite -and (Test-Path "$targetPath\$f")){Remove-Item -Force "$targetPath\$f"}
        if(!(Test-Path "$targetPath\$f")){
            Invoke-WebRequest $($urlFileDownload+$f) -OutFile $("$targetPath\$f")
        }    
    }
}

# Helper function to upload a file to a server supporing a REST API
function Send-File{
    Param([String]$localFilePath,[String]$remoteFilename,[String]$url)
    $fieldName = 'file'
    if(!('System.Net.Http.HttpClient' -as [Type])){
       Add-Type -AssemblyName 'System.Net.Http'
    }
    Try{
       $client = New-Object System.Net.Http.HttpClient
       $content = New-Object System.Net.Http.MultipartFormDataContent
       $fileStream = [System.IO.File]::OpenRead($localFilePath)
       $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
       $content.Add($fileContent, $fieldName, $remoteFilename)

       $result = $client.PostAsync($url, $content).Result
       $result.EnsureSuccessStatusCode()
       if ($result -match "200"){ return 200 }
    }
    Catch {       
    }
    Finally {
       if ($client -ne $null) { $client.Dispose() }
       if ($content -ne $null) { $content.Dispose() }
       if ($fileStream -ne $null) { $fileStream.Dispose() }
       if ($fileContent -ne $null) { $fileContent.Dispose() }
    }
}

# Helper function to open or close an availability ticket using a REST API
function Notify-Helpdesk{
    Param (
        [string]$RESTendpoint="127.0.0.1",
        [string]$source="Kansa-Powershell-launcher",
        [string]$node=$env:COMPUTERNAME,
        [string]$type=$global:moduleName,
        [string]$resource="Windows workstation or server",
        [string]$description='Automated alert indicating the start of a Kansa Hunt Operation. For questions please contact Hunt team or Security Ops Ctr',
        [ValidateRange(0,5)][int]$severity=0,
        [string]$additional_info
    )

    $EventManagerUsername = ''
    $EventManagerPassword = ''
    $username = $env:UserName
    $changeAction = 'start'
    If($severity -eq 0){
        $changeAction = 'end'
        $description = $description -replace 'start', 'end'
    }
    [System.Collections.Hashtable]$additional_info_HT = $Null
    if($additional_info -eq '') {
        [System.Collections.Hashtable]$additional_info_HT = @{changeAction=$changeAction;username=$username}
    } else {
        [System.Collections.Hashtable]$additional_info_HT = @{changeAction=$changeAction;username=$username;info=$additional_info}
    }

    # Create the Event object
    $Event = @{
        source=$source;
        node=$node;
        type=$type;
        description=$description;
        severity=$severity.toString();
    }

    # Add optional parameters to the event object, if set by the user
    If ($resource) { $Event.Add('resource', $resource) }
    $Event.Add('additional_info', [System.Collections.Hashtable]$additional_info_HT)

    # Json format the Event
    $EventJson = $($Event | ConvertTo-Json)

    # Ignore invalid SSL cert errors
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

    # Submit the Event
    $response = Invoke-RestMethod -Uri $RESTendpoint -Headers @{Authorization = ('Basic {0}' -f ([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(('{0}:{1}' -f $EventManagerUsername,$EventManagerPassword)))))} -Method 'POST' -ContentType 'application/json' -Body $EventJson -ErrorAction Stop

    return $response
}

# Helper function to send any queued results stored in the $RESULTS_FINAL array to ELK and zeroize that cache
function Send-Results{
    $destIP = Get-Random -InputObject $ElkServers
    [int]$port=Get-Random -InputObject $ElkPorts
    $socket = new-object System.Net.Sockets.TcpClient($destIP, $port)
    $stream = $socket.GetStream()
    $enc = [System.Text.Encoding]::ASCII
    $writer = new-object System.IO.StreamWriter($stream,$enc)
    $writer.AutoFlush = $true
    foreach ($obj in $RESULTS_FINAL){
        $parsedObj = $obj | ConvertTo-Json -Compress
        Send-ElkAlert -writer $writer -alertContent $parsedObj
    }
    $writer.Dispose()
    $stream.Dispose()
    $socket.Dispose()
    Set-Variable -name RESULTS_COUNT -value $($Global:RESULTS_COUNT+$RESULTS_FINAL.Count) -Scope Global #computationally more efficient to increment this counter only when the results are flushed instead of in the add-result function every time something is added
    $RESULTS_FINAL.Clear()
    [System.GC]::Collect()
}

# Wrapper variables used for safety and metrics. Setting to default values, but may be overwritten by module parameters passed in later
$startTime = Get-Date
$global:moduleName = "FFwrapper.ps1"
$delayedStart = $true
$maxDelay = 28800 #8hrs, spread execution across endpoints out over the space of Xsec
$killSwitch = $true
$killDelay = 900 #15min, allow sufficient time for execution, upload and TCP reporting to ELK
$VDIcheck = $false
$CPUpriority = "Idle" #valid values are: "Idle" "BelowNormal" "Normal" "AboveNormal" "High" "RealTime"...recommend never anything higher than "Normal"
$tzdiff = ((Get-WmiObject -class Win32_OperatingSystem).CurrentTimeZone / 60)
$ElkServers = @()
$ElkPorts = @()
$ModuleAccount = $env:USERNAME
$HuntID = $startTime.ToString("yyyyMMddHHmmss")
$SafeWord = "safeword" #placeholder
$SafeUser = $ModuleAccount #placeholder
$domain = "local" #placeholder
$VDIname = '^VDIhost' #placeholder
$VDIip = '127.0.0.1' #placeholder
$HelpdeskAlert = @{RESTendpoint = '127.0.0.1'; description = 'Automated alert indicating the start of a Kansa Hunt Operation. For questions please contact Hunt team or Security Ops Ctr'; severity = 0}
$Notify = $false

# Future development
#retryReport
#saveReport
#persistence
#VDIabort
#VDImultiplier
#variable to specify how many records must accumulate prior to sending/flushing queue
#fullMetrics #check CPU/mem/diskIO/network-utilization more frequently, store max value
#better garbage collection
#throttling/limits on RAM/network/diskIO usage
#suppressionTerm #keyword to whitelist module from EDR
#useUDP
#startAlert
#finishAlert

# DO NOT REMOVE THE FOLLOWING LINE. The kansa launcher uses this tag to pass module-specific commandline runtime parameters/variables through to the wrapper
#<InsertFireForgetArgumentsHERE>

# Setting up variables used for metrics
$global:hostname = ($env:COMPUTERNAME).ToLower()
$host.ui.RawUI.WindowTitle = $HuntID
$OS = Get-WmiObject -class Win32_OperatingSystem
$OSversion = [environment]::OSVersion.Version.ToString()
$OSfriendly = $OS.Caption
$OSsvcPack = $OS.CSDVersion
if($OSsvcPack){$OSsvcPack = $OSsvcPack.Trim()}
$OSbitness = $OS.OSArchitecture
$OSinstallTime = [datetime]::parseexact(($OS.InstallDate -split '-')[0],'yyyyMMddHHmmss.ffffff',$null)
$OScurrentTime = [datetime]::parseexact(($OS.LocalDateTime -split '-')[0],'yyyyMMddHHmmss.ffffff',$null)
$OSlastBootTime = [datetime]::parseexact(($OS.LastBootUpTime -split '-')[0],'yyyyMMddHHmmss.ffffff',$null)
$HostPhysMemory = (get-ciminstance -class "cim_physicalmemory" | Select Capacity| Measure-Object -Property Capacity -sum).sum
$HostCPU = get-ciminstance -class "cim_processor"
$procBitness = [System.IntPtr]::Size * 8
#if($startTime.IsDaylightSavingTime()) { $tzdiff += -1 }
$rnd = 0
if($delayedStart) {$rnd = Get-Random -Minimum 1 -Maximum $maxDelay}
$abort = $false

# Send an initial record indicating module successfully delivered to target with basic safety settings included
$result = @{}
$result.add("ModuleStatus","Started")
$result.add("ModulePID",$PID)
$result.add("ModuleStart","$startTime")
$result.add("ModuleAccount",$ModuleAccount)
$result.add("KillSwitchEnabled",$killSwitch)
$result.add("KillSwitchTimeout",$killDelay)
$result.add("RandomDelayedStart",$delayedStart)
$result.add("DelaySeconds",$rnd)
$result.add("VDIcheck",$VDIcheck)
Add-Result -hashtbl $result
Send-Results

# SAFETY-1: VDI-check & abort
if ($VDIcheck){
    if ($hostname -match $VDIname) { 
        $abort = $true
        $result = @{}
        $result.add("ModuleStatus","Aborted")
        $result.add("AbortReason","Hostname matched VDI convention")
        Add-Result -hashtbl $result
    } else {
        $ipaddrs = get-WmiObject Win32_NetworkAdapterConfiguration | where {$_.Ipaddress.length -gt 0 -and $_.DNSDomain}
        foreach ($addr in $ipaddrs) {
            if ($addr.IPAddress -match $VDIip) { 
                $abort = $true
                $result = @{}
                $result.add("ModuleStatus","Aborted")
                $result.add("AbortReason","IP Address matched VDI convention")
                $result.add("IPAddress",$addr.IPAddress)
                Add-Result -hashtbl $result
            }
        }
    }
}

# SAFETY-2: Randomized delayed start
if ($delayedStart -and !$abort) { Start-Sleep -s $rnd }

if($Notify){
    $HelpdeskAlert.severity = 5
    Notify-Helpdesk -RESTendpoint $($HelpdeskAlert.RESTendpoint) -description $($HelpdeskAlert.RESTendpoint) -severity $($HelpdeskAlert.severity) -additional_info "HuntID $HuntID"
}

# SAFETY-3: Killswitch.  This safety measure will spawn a parallel orphaned
# process that will forcefully terminate this process after a predetermined 
# time has elapsed
if ($killSwitch  -and !$abort) {
    $cmdStr = "c:\windows\system32\cmd.exe /c `"TITLE $HuntID & ping -n $killDelay 127.0.0.1 1>nul 2>nul & taskkill /F /FI ^`"IMAGENAME eq powershell.exe^`" /FI ^`"PID eq $PID^`" /FI ^`"USERNAME eq $SafeUser^`"`""
    $killswx = ([wmiclass]"\\localhost\ROOT\CIMV2:win32_process").Create($cmdStr)
}

# SAFETY-4: CPU Priority - This will use the process priority level to restrict execution CPU resource utilization
(Get-Process -id $PID).PriorityClass = $CPUpriority

# Placing entire module in this IF statement ensures that metrics are still collected even if the module must abort for safety
If (!$abort){
##############MODULE CODE INSERTED HERE#################

# DO NOT REMOVE THE FOLLOWING COMMENT/TAG - it is used by kansa to dynamically splice module code into this wrapper at launch time
#<InsertFireForgetModuleContentsHERE>

##############END OF MODULE SPECIFIC CODE###############
}
$endTime = Get-Date
$totalDuration = $endTime - $startTime
$runTime = $endTime - $startTime.AddSeconds($rnd)
$sleepEvents = $null
if($runTime.TotalSeconds -gt $killDelay){$sleepEvents = Get-EventLog -LogName System -Source Microsoft-Windows-Power-Troubleshooter -Newest 10 | Sort TimeGenerated | Select Message -Last 1}
if($abort) { $runTime = $totalDuration }
$thisProc = get-process | where Id -eq $pid | Select PM,CPU,WS
$thisCounterPath = ((Get-Counter "\Process(powershell*)\ID Process").CounterSamples | ? {$_.RawValue -eq $pid}).Path
$pws = ((get-counter ($thisCounterPath -replace "\\id process$","\Working Set - Private")).CounterSamples | select CookedValue).CookedValue / 1MB
$uptime = ($OScurrentTime - $OSlastBootTime)
$LLOuser = Get-LLOuser

$result = @{}
$result.add("HostUptimeDays",$uptime.totaldays)
$result.add("HostLastLoggedOnUser",$LLOuser.Name)
$result.add("HostLastLoggedOnUserID",$LLOuser.UserID)
$result.add("HostLastLoggedOnUserDate",$LLOuser.LogonDate)
$result.add("HostLastLoggedOnUserDateNT",$LLOuser.LogonDateNT)
$result.add("HostLastLoggedOnTitle",$LLOuser.Title)
$result.add("HostLastLoggedOnDept",$LLOuser.Dept)
$result.add("HostLastLoggedOnDiv",$LLOuser.Div)
$result.add("HostLastLoggedOnDesc",$LLOuser.Desc)
$result.add("HostLastLoggedOnCmpny",$LLOuser.Cmpny)
$result.add("HostLastLoggedOnHome",$LLOuser.Home)
$result.add("HostLastLoggedOnEmail",$LLOuser.Email)
$result.add("HostLastLoggedOnPasswdExp",$LLOuser.PasswdExp)
$result.add("HostOSVersion",$OSversion) 
$result.add("HostOSName","$($OSfriendly.Trim()) $OSsvcPack") 
$result.add("HostOSBitness",$($OSbitness -split '-' | Select -First 1)) 
$result.add("HostOSInstalled",$OSinstallTime.ToString())
$result.add("HostOSStartTime",$OScurrentTime.ToString())
$result.add("HostOSLastBoot",$OSlastBootTime.ToString())
$result.add("HostPhysicalMemoryMB",($HostPhysMemory / 1MB))
$HostCPU | %{
    $result.add($_.DeviceID,$_.Name)
    $result.add("$($_.DeviceID) Cores",$_.NumberOfCores)
    $result.add("$($_.DeviceID) LogicalProcessors",$_.NumberOfLogicalProcessors)
    $result.add("$($_.DeviceID) AddressWidth",$_.AddressWidth)
}
$result.add("ModuleAccount",$ModuleAccount)
$result.add("ModuleStatus","Complete")
$result.add("ModulePID",$PID)
$result.add("ModuleProcessBitness", $procBitness)
$result.add("ModuleStart",$startTime.ToString())
$result.add("ModuleComplete",$endTime.ToString())
$result.add("ModuleWSMemMB",$($thisProc.WS / 1MB))
$result.add("ModulePWSMemMB",$pws)
$result.add("ModuleCPUseconds",$thisProc.CPU)
$result.add("DelaySeconds",$rnd)
$result.add("TotalDurationMinutes",$totalDuration.TotalMinutes)
#add BITNESS
if($sleepEvents){
    $result.add("Slept", $true)
    $sleepMsg = $sleepEvents.Message -replace "`r`n`r`n","`r`n" -split "`r`n"
    try{
        $sleepTime = ([datetime]::ParseExact($($sleepMsg[1].Substring( $($sleepMsg[1].IndexOf(': ') + 2), 19 )) -replace("T","_"),'yyyy-MM-dd_HH:mm:ss',$null)).AddHours($tzdiff)
        $wakeTime = ([datetime]::ParseExact($($sleepMsg[2].Substring( $($sleepMsg[2].IndexOf(': ') + 2), 19 )) -replace("T","_"),'yyyy-MM-dd_HH:mm:ss',$null)).AddHours($tzdiff)
        $sleptOnTheJob = $sleepTime -gt $startTime
        if($sleptOnTheJob) {$runTime = $endTime - $wakeTime}
        if($startTime.AddSeconds($rnd) -lt $sleeptime) {$runtime.AddSeconds($($sleepTime - $startTime.AddSeconds($rnd)).TotalSeconds)}
        $result.add("SleepTime",$sleepTime.ToString())
        $result.add("WakeTime",$wakeTime.ToString())        
        $result.add("SleptOnTheJob", $sleptOnTheJob)
    } catch {
        Continue
    }
} 
$result.add("MinutesRuntime",$runTime.TotalMinutes)
$result.add("ItemsAnalyzed",$($Global:RESULTS_Count + $RESULTS_FINAL.count))
Add-Result -hashtbl $result

Send-Results

if($Notify){
    Notify-Helpdesk -RESTendpoint $($HelpdeskAlert.RESTendpoint) -description $($HelpdeskAlert.RESTendpoint) -severity 0 -additional_info "HuntID $HuntID"
}

if ($killSwitch  -and !$abort) {
    $killswxpid = $killswx.ProcessId
    $pingpid = $WMIProcess | where ParentProcessId -EQ $killswxpid | select ProcessId
    $pp = $pingpid.ProcessId
    $res2 = taskkill /F /FI "USERNAME eq $ModuleAccount" /FI "PID eq $killswxpid"
    $res = taskkill /F /FI "USERNAME eq $ModuleAccount" /FI "PID eq $pp"
}
'@

# This function is necessary to compress the entire module plus wrapper into a string short enough to accommodate the 8192 char maximum command-line length limit for a new process-creation
# Some EDR products may flag this type of encoded powershell process creation as malicious. The $safeword allows one-time dynamic whitelisting/suppression of this hunt module combined with
# the user context of execution to safely ignore this shady-looking script.
function Compress-EncodeScript{
    param([string]$script = "")
    $m=New-Object System.IO.MemoryStream
    $s=New-Object System.IO.StreamWriter(New-Object System.IO.Compression.GZipStream($m,[System.IO.Compression.CompressionMode]::Compress))
    $s.Write($script -join "`n")
    $s.Close()
    $r=[System.Convert]::ToBase64String($m.ToArray())
    #prepend safeword to scriptblock command to bypass builtin IOCs for suspicious powershell
    $p = "`write-host $SafeWord;`$d=[System.Convert]::FromBase64String('$r');`$m=New-Object System.IO.MemoryStream;`$m.Write(`$d,0,`$d.Length);`$m.Seek(0,0);iex (New-Object System.IO.StreamReader(New-Object System.IO.Compression.GZipStream(`$m,[System.IO.Compression.CompressionMode]::Decompress))).ReadToEnd()"
    return $p
}

# Compress and encode scriptblock to pass to endpoint with self-decompression/decode script
$scriptblock_bytes = [System.Text.Encoding]::Unicode.GetBytes($scriptblock_str)
$scriptblock_CompEnc = Compress-EncodeScript -script $scriptblock_str
$myproc = ([wmiclass]"\\localhost\ROOT\CIMV2:win32_process").Create("powershell.exe -NoProfile -windowstyle hidden -Command $scriptblock_CompEnc")

# This section controls the output of the wrapper module. It relays back to Kansa the PID 
# of the process created on the target workstation. This makes cleanup of orphaned processes 
# possible in case a module misbehaves. And positive deconfliction in the event that Incident
# Response needs to distinguish between friendly forces and adversarial activity
$o = "" | Select-Object PID,Hostname,Message,KansaModule
$o.PID,$o.Hostname,$o.Message,$o.KansaModule = $myproc.ProcessID,($env:COMPUTERNAME).ToLower(),'FireForget Kansa module launched on endpoint',$global:moduleName

$o
