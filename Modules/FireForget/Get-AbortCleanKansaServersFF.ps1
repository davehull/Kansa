# This module is used to abort the deployment of a Kansa module from distributed-kansa servers
# It can also be used in the event that a kansa server stalls its deployment due to too many connection
# errors or timeouts.  The parameters can be configured to clean up result folders and error logs
# and optionally send any uncollected results/errors to ELK for the previous n kansa jobs.
# The default settings are set for safe operation and will only send results/errors from the last 1 job

if(!(Get-Variable -Name KillRunningKansaJob -ErrorAction SilentlyContinue)){$KillRunningKansaJob = $False}
if(!(Get-Variable -Name CleanupServer -ErrorAction SilentlyContinue)){$CleanupServer = $False}
if(!(Get-Variable -Name SendPartialResultsToElk -ErrorAction SilentlyContinue)){$SendPartialResultsToElk = $True}
if(!(Get-Variable -Name DeletePartialResults -ErrorAction SilentlyContinue)){$DeletePartialResults = $False}
if(!(Get-Variable -Name NumRecentJobs -ErrorAction SilentlyContinue)){$NumRecentJobs=1}
if(!(Get-Variable -Name KansaRemotePath -ErrorAction SilentlyContinue)){$KansaRemotePath="F:\Kansa"}
if(!(Get-Variable -Name KansaJobPath -ErrorAction SilentlyContinue)){$KansaJobPath = ""}

$thisProcess = Get-WmiObject -query 'Select * from win32_process' | where ProcessId -eq $Pid | Select Name,ProcessId,ParentProcessId

$allPaths = @()
if($KansaJobPath -eq ""){
    $KansaJobPath = $KansaRemotePath
    if ($NumRecentJobs -eq 0) {
        $allPaths = gci -Path $KansaJobPath -Directory -Recurse | where Name -Match "Output_" | Sort-Object -Descending
    } 
    else {
        $allPaths = gci -Path $KansaJobPath -Directory -Recurse | where Name -Match "Output_" | Sort-Object -Descending | Select -First $NumRecentJobs
    }
}
else {
    $allPaths = $KansaJobPath
}

if ($KillRunningKansaJob) {
    $thePIDSkilled = New-Object -TypeName System.Collections.ArrayList
    gps | where ProcessName -eq "powershell" | ForEach-object {
        #$_.Id        
        if (!$($_.Id -eq $thisProcess.ProcessId)) {
            kill -Force $_.Id
            $thePIDSkilled.add([String]$_.Id + '(powershell) ')
        }
    }

    gps | where ProcessName -eq "wsmprovhost" | ForEach-object {
        kill -Force $_.Id
        $thePIDSkilled.add([String]$_.Id + '(wsmprovhost) ')
    }
    
    gps | where ProcessName -eq "WmiPrvSE" | ForEach-object {
        kill -Force $_.Id
        $thePIDSkilled.add([String]$_.Id + '(WmiPrvSE) ')
    }

    $result = @{}
    $result.add("ModuleStatus","Processes Killed")
    $result.add("Details", "Count:$($thePIDSkilled.count), ProcessIDs:$($thePIDSkilled -join ',')")
    Add-Result -hashtbl $result
}

if ($SendPartialResultsToElk) {
        
    $allJSONPaths = $allPaths | % { Get-ChildItem -Path $_.FullName -Filter '*.json' -Recurse }

    if ($allJSONPaths.Count -gt 0){
        $JSONPathStr = @()
        foreach ($f in $allJSONPaths){
            $fullJSONPath = $f.Directory.ToString() + "\" + $f.ToString()
            # Only add to list of files to be parsed and sent if the file has content
            $testJSONPath = Get-Item $fullJSONPath
            if ($testJSONPath.Length -gt 0){
                $JSONPathStr += $fullJSONPath
            }
        }
            
        $recordsSent = 0

        foreach ($j in $JSONPathStr){
            $tgtModuleName = $j.Split("\")[-2]
            $tgtModuleName = "Kansa-$tgtModuleName"
            [string]$alertContent = Get-Content $j

            $alertContentJSON = gc -Path $j -Raw | ConvertFrom-Json
            foreach ($a in $alertContentJSON){
                $result = @{}
                $a.psobject.properties | % { $result.Add($_.Name,$_.Value) }
                $result.Add("sourceScript","kansa.ps1")
                $result.Add("sourceModule","$tgtModuleName")
                $result.Add("KansaModule", $($tgtModuleName -replace "^Kansa-",""))
                $result.Add('KansaServer', $hostname)
                Add-Result -hashtbl $result
                $recordsSent += 1
            }
        }

        $result = @{}
        $result.add("ModuleStatus","Partial Results queued to send to ELK")
        $result.add("Details", "RecordsSent:$($JSONPathStr.count)")
        Add-Result -hashtbl $result
    }

    $errorFiles = $allPaths | % { Get-ChildItem -Path $_.FullName -File -Filter 'Error.log' }
    if ($errorFiles){
        foreach($file in $errorFiles){
            $errorFile = Get-Item -Path $($file.Directory.ToString() + "\" + $file.ToString())

            if ($errorFile.Length -gt 0){                    
                $tgtModuleName = "kansa.ps1"
                $ErrorLogHost = $hostname

                $errors = Get-Content $errorFile -Delimiter '['
                $res = @{}
                for ($i = 1; $i -lt $errors.count; $i++) { 
                    $err=$errors[$i].replace("[","")
                    $res.add(($err.Substring(0,$err.IndexOf("]"))).ToUpper(), ($err.Substring($err.IndexOf(":")+2,$err.Length - $err.IndexOf(":") - 3)).Trim())
                }
                    
                $res.getenumerator() | % {
                    $result = @{}
                    $result.Add('Hostname', $_.Name)
                    $result.Add('KansaModule', $tgtModuleName)
                    $result.Add('ModuleStatus', 'Error')
                    $result.Add('Error', $_.Value)
                    $result.Add('ErrorLogFile', $errorFile.Fullname)
                    $result.Add('KansaServer', $ErrorLogHost)
                    Add-Result -hashtbl $result
                }

                $result = @{}
                $result.add("ModuleStatus","Partial Errors queued to send to ELK")
                $result.add("Details", "RecordsSent:$($res.count)")
                Add-Result -hashtbl $result
            }
        }                
    }
    Send-Results
}

if ($DeletePartialResults) {
    foreach ($path in $allPaths) {
        Remove-Item -Recurse -Force -Path $path.FullName
    }
    $result = @{}
    $result.add("ModuleStatus","Removed Output Folders")
    $result.add("Details",$($allPaths -join ' | '))
    Add-Result -hashtbl $result
}

if ($CleanupServer) {
    $i = 0
    while ( ((Get-Service winrm | select status) -Match "Running" ) -and $i -lt 3) {
        #net stop winrm /yes
        (get-wmiobject win32_service -filter "name='winrm'").stopService()
        $i++
        Start-Sleep -Seconds $i
    }
    $i = 0
    while ( ((Get-Service winmgmt | select status) -match "Running") -and $i -lt 3)  {
        #net stop winmgmt /yes
        (get-wmiobject win32_service -filter "name='winmgmt'").stopService()
        $i++
        Start-Sleep -Seconds $i
    }

    $result = @{}
    $result.add("ModuleStatus","Stopped Services")
    $result.add("Details","winrm, winmgmt")
    Add-Result -hashtbl $result

    $files = gci -Path $KansaRemotePath | where Name -match "(temptargets.*\.txt|currentRunlog\.txt|IN_USE_BY.*)"
    $files | %{ remove-item $_.Fullname -Force}

    $result = @{}
    $result.add("ModuleStatus","Deleted Temporary Files")
    $result.add("Details",$(($files | select FullName).FullName -join ','))
    Add-Result -hashtbl $result

    (get-wmiobject win32_service -filter "name='winrm'").startService()
    Start-Sleep -Seconds 2
    (get-wmiobject win32_service -filter "name='winmgmt'").startService()
    Start-Sleep -Seconds 2
    net start winrm
        
    $result = @{}
    $result.add("ModuleStatus","Services restarted")
    $result.add("Details","winrm, winmgmt")
    Add-Result -hashtbl $result
}
