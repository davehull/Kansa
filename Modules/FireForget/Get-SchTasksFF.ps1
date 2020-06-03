# This module will enumerate all scheduled tasks on a system using two different methods:
# 1. Running the schtasks command and parsing the csv output
# 2. Parsing all of the XML .job files in the Windows\System32\Tasks\ subfolder
# the module cleans up the data and if it is able to parse/recognize a target script/binary it will collect
# metadata about the target to allow for higher-fidelity dispositioning since the task fields/names are 
# arbitrary & can be controlled by the attacker. The data is all sent to ELK for aggregation and analytics.

# Simple function to parse XML task job files and show value assignments by flattening/concatenating out hierarchies
function parseXML{
    param(
        [Object]$myXML,
        [string]$prefix
    )
    If($myXML.hasChildNodes){            
        $prefix += $myXML.Name
        $myXML.ChildNodes | %{ parseXML -myXML $_ -prefix $prefix}
    }else{
        "$prefix=$($myXML.Value)"
    }
}

# Collect the two datasets
$path = "$($env:SystemRoot)\System32\Tasks"
$xmltsks = gci -recurse -force -file -path $path
$schtsks = schtasks /v /fo csv /query | ConvertFrom-Csv

# Iterate through the scheduled task data collected from schtasks.exe and parse/enrich records
foreach($tsk in $schtsks){
    $result = @{}
    $header = $true #assume this row is a header row
    $tsk.psobject.properties | %{ if($_.Name -ne $_.Value){$header = $false} } #if the name and value do not match for this row of the csv then this is NOT a header row
    if($header){continue} #if this is a header row, skip to the next row of the csv
    $tsk.psobject.properties | %{ $result.add("schtask $($_.Name)",$_.Value) } #add all of the name/value pairs to our result object/hashtable for shipping
    $xmltsk = $xmltsks | where FullName -eq "$path$($tsk.TaskName)" #find the corresponding task info from the xml job files
    if($xmltsk){
        $result = Get-FileDetails -hashtbl $result -filepath $xmltsk.FullName -computeHash -algorithm @("MD5","SHA256") -prefix "XML" #add the XML enrichments to the result object using the "XML" prefix to denote where the data was obtained
        $xmltskContent = gc -raw $xmltsk.FullName #attach the full raw job xml task file for troubleshooting any parsing errors
        parseXML -myXML ([xml]($xmltskContent)).ChildNodes[1] | %{
            $r = $_.split("=")
            $i = 0
            while($result.ContainsKey("XML$($r[0])$i")){$i++}
            $result.add("XML$($r[0])$i",$r[1])
        }
        $result.Add("XMLFileContent",$xmltskContent)
    }
    #attempt to identify working folders and target scripts/executables
    $start = $tsk | ? "Start In" -notmatch "(Start In|N/A|Multiple Actions)" | Select "Start In"
    if($start){$start= $start.'Start In'}else{$start = ""}
    $tgt = $tsk | ? "Task To Run" -notmatch "(Task To Run|COM handler|Multiple Actions)" | Select "Task To Run"
    if($tgt){$tgt = $tgt.'Task To Run'}else{$tgt = ""}
    $cmd = ""
    if(($tgt.Length -ge $start.Length) -and ($tgt.Substring(0,$start.Length).ToLower() -eq $start.ToLower())){ 
        $cmd = $tgt 
    }else{
        $cmd = $start + "\" + $tgt
    }
    $result.add("tgtUnparsed",$cmd)
    if($cmd -eq ""){Add-Result -hashtbl $result;continue} #if unable to parse a cmdline add the record for shipping and move on to the next row
    $subs = @{"%windir%"="$env:windir";"%SystemRoot%"=$env:SystemRoot;"%userprofile%"=$env:UserProfile;"%ProgramFiles%"=$env:ProgramFiles;"%ProgramFiles(x86)%"=${env:ProgramFiles(x86)};"%programdata%"=$env:ProgramData;"%systemdrive%"=$env:SystemDrive}
    $subs.GetEnumerator() | % { $cmd = $cmd -replace $($_.Name),$($_.Value) } #iterate through the list of environment variable substitutions and switch variables to actual values
    $cmd = $cmd -replace '"','' #strip out quotes
    $suffix = $null
    if($cmd -match '^[A-Z]:\\'){
        $paths = $cmd
    }else{
        $paths = $env:Path -split ';' | %{ $_ + '\'} #if the literal path to the target is not specified, it must be located in one of the system paths. create variants to test all system paths for this target executable/suffix
        $suffix = "$cmd"
    }
    $present = $false
    $arguments = ""
    #iterate through all possible paths to find the target file/executable
    foreach($p in $paths){
        $f = $p+$suffix
        $i = 0
        #since the target path may contain spaces for arguments after the executable, look for the first space and test to see if that is a valid file
        #incrementally look for each space in the string to identify the point where the command is sparated from the arguments
        while($i -ge 0){
            $nextspace = $f.indexof(" ",$i+1) #when we exceed the length of the string this will return a negative number triggering the end of the loop
            #once we are able to resolve a file stop iterating, collect the file info and trigger the breakpoint in the loop
            if(($nextspace -ge 0) -and (test-path -pathtype leaf -ErrorAction SilentlyContinue -literalpath $f.substring(0,$nextspace)) ){
                $cmd = $f.substring(0,$nextspace)
                $arguments = $f.substring($nextspace,$f.length - $nextspace)
                $present = $true
                $i = -1
                $result = Get-FileDetails -hashtbl $result -filepath $cmd -computeHash -algorithm @("MD5","SHA256") -prefix "tgt"
                $result.add("tgtArguments",$arguments)
                $result.add("tgtCommand",$cmd)
            }else{
                $i = $nextspace
            }
        }
        if($present){break}
    }
    #Below are some samples of command fields that were used to build the algorithm above and test various inputs/use-cases for proper parsing
    #$cmd = "%ProgramFiles%\Windows Defender\MpCmdRun.exe -IdleTask -TaskName WdCacheMaintenance"
    #$cmd = "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NonInteractive -File ""F:\SCOM 2016\Gateway\Tools\UpdateOMCert.ps1"""
    #$cmd = "%SystemRoot%\System 32\Windows Power Shell\v1.0\powershell.exe -NonInteractive -File ""F:\SCOM 2016\Gateway\Tools\UpdateOMCert.ps1"""
    #$cmd = "PowerShell.exe -WindowStyle hidden -ExecutionPolicy Bypass -Command ""& %ProgramData%\Microsoft\AppV\Setup\OfficeIntegrator.ps1"""
    #below are some of the environment variables that needed substitutions
    #%CommonProgramFiles%
    #username tmp temp  public   ALLUSERSPROFILE
     
    $result.add("tgtFound",$present)
    Add-Result -hashtbl $result
}

#Old XML-only task parsing logic.  Saving code as a reference only
#foreach ($xtsk in $xmltsks){
#    $result = Get-FileDetails -filepath $xtsk.FullName -computeHash -algorithm @("MD5","SHA256")
#    $xTskContent = gc $xtsk.FullName
#    $result.add("FileContent",$xTskContent)
#    parseXML -myXML ([xml]($xTskContent)).ChildNodes[1] | %{$r = $_.split("="); $result.add("XML$($r[0])",$r[1])}
#    $thisTask = $schtsks | where TaskName -match $result.FileBaseName | select -First 1
#    $thisTask.psobject.properties | %{ $result.add("schtsk$($_.Name)",$_.Value)}
#    $t = $result.XMLTaskActionsExecCommand
#    $lastslash = $t.LastIndexOf("\")
#    if($lastslash -eq -1) {$lastslash = 0}
#    $lastspace = $t.indexof(" ",$lastslash)
#    if($lastspace -eq -1) {$lastspace = $t.length}
#    $tgt = $t.Substring(0,  $lastspace)
#    $result.add("tgt",$tgt)
#    #$schtasks | where Hostname -notmatch "HostName" | where "Task To Run" -notmatch "COM handler" | select "Task To Run" | %{$t = $_."Task To Run"; $lastslash=$t.LastIndexOf("\");if($lastslash -eq -1) {$lastslash = 0};$lastspace = $t.indexof(" ",$lastslash);if($lastspace -eq -1) {$lastspace = $t.length};$t.Substring(0,  $lastspace) }
#    #$result.GetEnumerator() | sort -Property name
#}
