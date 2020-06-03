# This module can be used to update the winlogbeat config and troubleshoot some common casues for service failures. It will
# even attempt to reinstall the service if it is not installed (due to failed initial install or malicious action). It can
# compare the current config and download an updated one if necessary, and swap configs / bounce the service to get the new
# configs to take effect.  An attacker may alter the configuration or stop the service to avoid detection.  This module may
# identify systems where tampering has occurred and optionally revert changes back to baseline standards

if(!(Get-Variable -Name necroSvr -ErrorAction SilentlyContinue)){$necroSvr = @("127.0.0.1")}
if(!(Get-Variable -Name necroPort -ErrorAction SilentlyContinue)){$necroPort = @(80)}
if(!(Get-Variable -Name huntFolder -ErrorAction SilentlyContinue)){$huntFolder = "$env:SystemDrive\Temp\"}
if(!(Get-Variable -Name newConfigMD5 -ErrorAction SilentlyContinue)){$newConfigMD5 = "4EC4D85F91B209C22A3F5D2DA4B20E60"}
if(!(Get-Variable -Name checkOnly -ErrorAction SilentlyContinue)){$checkOnly = $true}
$rndSvr = Get-Random -InputObject $necroSvr
$rndPort = Get-Random -InputObject $necroPort
$urlFileDownload = "http://$rndSvr"+':'+"$rndPort/stage/dl/winlogbeat.yml"
    
$result = @{}
    
$wlbpath = ""
$status = ""
$fail = $false
$svcRunning = $false

# Check to ensure hunt/staging folder exists to handle download of new config.  If not, then create it
if(!(test-path -LiteralPath "$huntFolder") -and !$checkOnly){
    New-Item -ItemType directory -Path "$huntFolder"
    if(!(test-path -LiteralPath "$huntFolder")){
        $status += "Error: Failed to created Hunt util folder`n"
        $fail = $true
    }else{
        $status += "Success: Created Hunt util folder`n"
    }
}else{
    $status += "Success: Hunt util folder already exists`n"
}

# Check default winlogbeat installation folders to verify the service is installed.  Set the wlbpath variable for future ops
if(test-path -PathType Container -literalpath "$env:SystemDrive\Program Files (x86)\winlogbeat"){
    $wlbpath = "$env:SystemDrive\Program Files (x86)\winlogbeat\"
    $status += "Success: Winlogbeat installation at $wlbpath`n"
}elseif(test-path -PathType Container -literalpath "$env:SystemDrive\Program Files\winlogbeat"){
    $wlbpath = "$env:SystemDrive\Program Files\winlogbeat\"
    $status += "Success: Winlogbeat installation at $wlbpath`n"
}else {
    $status += "Error: Unable to locate winlogbeat installation folder`n"
    $fail = $true
}
$result.add("WinlogbeatsPath",$wlbpath)

# Check the hash of the existing wlb config to see if it needs to be updated
$oldWLBconfigMD5 = ""
if(!$fail -and (test-path -PathType Leaf -literalpath $($wlbpath + "winlogbeat.yml"))){
    $content = gc -raw $($wlbpath + "winlogbeat.yml")
    $oldWLBconfigMD5 = (Get-FileHash $($wlbpath + 'winlogbeat.yml') -Algorithm MD5).hash
    $result.add("OldWLBconfig",$content)
    $result.add("OldWLBconfigMD5",$oldWLBconfigMD5)
}elseif(!$fail){
    $status += "Error: No existing config file present`n"
}

# If the existing config hash value is the same as the new config hash, no update needed. Set $fail flag to short-circuit the rest of the script
if($oldWLBconfigMD5 -eq $newConfigMD5){
    $status += "INFO: Existing config file already updated. Update not attempted`n"
    $fail = $true
}

#check to make sure there is enough free diskspace to install the new config and run the service.  If not, try clearing temp internet cache for all users
$driveSpace = Get-WmiObject -Class Win32_logicaldisk -Filter "DriveType = '3'" | where DeviceID -match "$env:SystemDrive" | Select-Object -ExpandProperty FreeSpace
if($drivespace -lt 20000000){
    $status += "WARNING: C Drive appears to be full. Will try clearing temp inet cache`n"
    $theUsers = ls "C:\Users"        
    foreach($u in $theUsers) {
        $winver = [environment]::OSVersion.Version | Select-Object -ExpandProperty Major
        if($winver -ge 10){ls -force "$($u.FullName)\AppData\Local\Microsoft\Windows\INetCache\IE" | %{ remove-item -ErrorAction SilentlyContinue -recurse $_}
        }else{ls -force "$($u.FullName)\AppData\Local\Microsoft\Windows\Temporary Internet Files\Content.IE5\" | %{ remove-item -ErrorAction SilentlyContinue -recurse $_}}
    }
}

# Check for presence of a config file in the staging folder. If present - check hash value to see if it is correct version
if((test-path -literalpath "$huntFolder\winlogbeat.yml") -and !$checkOnly){
    if(((Get-FileHash "$huntFolder\winlogbeat.yml" -Algorithm MD5).hash -ne $newConfigMD5)){
        $status += "WARNING: Removed existing config from hunt folder - did not match new MD5`n"
        Remove-Item "$huntFolder\winlogbeat.yml"
    }else{
        $status += "WARNING: New config already downloaded in hunt folder`n"
    }
}

# Try 3 times to download the new config file from staging REST API server
$i = 0
while(!(test-path -literalpath "$huntFolder\winlogbeat.yml") -and !$fail -and !$checkOnly){
    if($i -ge 3){
        $fail = $true
        $status += "Error: Download new config file failed`n"
        break
    }        
    Invoke-WebRequest $($urlFileDownload) -OutFile $("$huntFolder\winlogbeat.yml")
    start-sleep -seconds $($i + 1)
    $i++
}

# Check for successful download
if((test-path -literalpath "$huntFolder\winlogbeat.yml") -and !$checkOnly){
    $status += "Success: Downloaded new config file`n"
    if( ((Get-FileHash "$huntFolder\winlogbeat.yml" -Algorithm MD5).hash -ne $newConfigMD5) ){
        $status += "Error: New config file hash mismatch`n"
        $fail = $true
    }else{
        $status += "Success: New config file hashes match`n"
        #$fail = $false
    }        
}

# If winlogbeat service is not currently installed & running, try to install and start it with existing config
if(!((get-wmiobject win32_service -filter "name='winlogbeat'").state -eq "Running") -and !$checkOnly){
    $status += "WARNING: Winlogbeat service is not currently running. Will attempt to install and start`n"
    if( (sc.exe query winlogbeat | Select-String -pattern "specified service").Line -match "does not exist" ){
        & $($wlbpath+"\install-service-winlogbeat.ps1")
        start-sleep -seconds 2
    }
    (get-wmiobject win32_service -filter "name='winlogbeat'").startService()
    start-sleep -seconds 2
}

# Check the service configuration options to ensure that the service is not disabled by an attacker or mischievous user
if((sc.exe qc winlogbeat 1024 | Select-String -Pattern "START_TYPE").Line -notmatch "AUTO_START"){
    $status += "WARNING: Winlogbeat service not set to autostart. Attempting to update`n"
    sc.exe config winlogbeat start= auto
    start-sleep -seconds 2
    (get-wmiobject win32_service -filter "name='winlogbeat'").startService()
    start-sleep -seconds 2
}

# In order to install the new wlb config we need to try and stop the service
$i = 0
while ( ((get-wmiobject win32_service -filter "name='winlogbeat'").state -eq "Running") -and !$fail -and !$checkOnly) {
    if($i -ge 3){
        $status += "Error: Failed to stop winlogbeat service`n"
        $fail = $true
        Break
    }
    (get-wmiobject win32_service -filter "name='winlogbeat'").stopService()
    Start-Sleep -Seconds 5
    $i++
}

# Swap the configs and backup the old one
if(!$fail -and !$checkOnly){
    $status += "Success: winlogbeat service is stopped`n"
    if(test-path -literalpath $($wlbpath + 'winlogbeat-2019-03-19.BAK.yml')) { remove-item -literalpath $($wlbpath +'winlogbeat-2019-03-19.BAK.yml') }
    Rename-Item -LiteralPath $($wlbpath + 'winlogbeat.yml') -NewName "winlogbeat-BAK.yml"
    Move-Item -LiteralPath "$huntFolder\winlogbeat.yml" -Destination $($wlbpath + 'winlogbeat.yml')
    if( ((Get-FileHash $($wlbpath + 'winlogbeat.yml') -Algorithm MD5).hash -ne $newConfigMD5)){
        $status += "Error: Failed to copy config file`n"
        $fail = $true
    }else{
        $status += "Success: Copied new config file to destination and verified hash`n"
    }
}

# Check for the presence of a cached config file in the programdata directory to indicate the service may not have properly stopped
# try to rename the file to avoid conflicting config versions
if((test-path -pathtype leaf -literalpath "$env:SystemDrive\ProgramData\winlogbeat\.winlogbeat.yml") -and !$fail){
    if((Get-FileHash "$env:SystemDrive\ProgramData\winlogbeat\.winlogbeat.yml" -Algorithm MD5).Hash -eq $result.oldWLBconfigMD5){
        $status += "Warning: YAML file in $env:SystemDrive\ProgramData\winlogbeat\ does not match specified config`n"
    }
    if(!$checkOnly){
        ren "$env:SystemDrive\ProgramData\winlogbeat\.winlogbeat.yml" "$env:SystemDrive\ProgramData\winlogbeat\.winlogbeat.yml.bak"        
        $status += "Warning: Renamed YAML file in $env:SystemDrive\ProgramData\winlogbeat\ to avoid service error`n"
    }
}

# Try to restart the winlogbeat service
$i = 0
while (((get-wmiobject win32_service -filter "name='winlogbeat'").state -ne "Running") ){
    if($i -ge 3){
        $status += "Error: Failed to start winlogbeat service`n"
        $fail = $true
        Break
    }
    (get-wmiobject win32_service -filter "name='winlogbeat'").startService()
    Start-Sleep -Seconds 5
    $i++        
}
if ((get-wmiobject win32_service -filter "name='winlogbeat'").state -eq "Running"){
    $status += "Success: winlogbeat service is running`n"
    $svcRunning = $true
}

# Gather final results and send to ELK for reporting/summary
if(!$fail){
    $content = gc -raw $($wlbpath + 'winlogbeat.yml')
    $newWLBconfigMD5 = (Get-FileHash $($wlbpath + 'winlogbeat.yml') -Algorithm MD5).hash
    $result.add("NewWLBconfig",$content)
    $result.add("NewWLBconfigMD5",$newWLBconfigMD5)
}
$result.add("Error",$fail)
$result.add("CheckOnly",$checkOnly)
$result.add("StatusMessage",$status)
$result.add("WinlogbeatServiceRunning",$svcRunning)

Add-Result -hashtbl $result
