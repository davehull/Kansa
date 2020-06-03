# If an organization is too risk averse to agree to install Sysmon enterprise-wide, there may be an opportunity for tactical
# installation using kansa. SOC analysts or threat hunters can target a set of systems that may be at increased risk or showing
# signs of suspicious/unusual behavior. Or if the IT organization needs help pushing out an install, kansa can do so quickly.
# This module can be used to install/update/uninstall sysmon based on the flags used at launch. The module also allows for
# obfuscating/hardening the install to make it less obvious to the casual attacker that they are being watched.

if(!(Get-Variable -Name necroSvr -ErrorAction SilentlyContinue)){$necroSvr = @("127.0.0.1")}
if(!(Get-Variable -Name necroPort -ErrorAction SilentlyContinue)){$necroPort = @(80)}
if(!(Get-Variable -Name stagingPath -ErrorAction SilentlyContinue)){$stagingPath = "$env:SystemDrive\Temp"}
if(!(Get-Variable -Name configName -ErrorAction SilentlyContinue)){$configName = "sysmonconfig.xml"}
if(!(Get-Variable -Name configMD5 -ErrorAction SilentlyContinue)){$configMD5 = "ABCDEF0123456789ABCDEF0123456789"}
if(!(Get-Variable -Name serviceName -ErrorAction SilentlyContinue)){$serviceName = "notsysmon"}
if(!(Get-Variable -Name serviceDescription -ErrorAction SilentlyContinue)){$serviceDescription = "Not Sysmon Driver"}
if(!(Get-Variable -Name driverName -ErrorAction SilentlyContinue)){$driverName = "notsysmo"}
if(!(Get-Variable -Name driverAltitude -ErrorAction SilentlyContinue)){$driverAltitude = 385202}
if(!(Get-Variable -Name preStagedFiles -ErrorAction SilentlyContinue)){$preStagedFiles = $false}
if(!(Get-Variable -Name stagedBinary -ErrorAction SilentlyContinue)){$stagedBinary = "sysmon.exe"}
if(!(Get-Variable -Name updateConfigOnly -ErrorAction SilentlyContinue)){$updateConfigOnly = $false}
if(!(Get-Variable -Name uninstall -ErrorAction SilentlyContinue)){$uninstall = $false}

if($uninstall){
    $updateConfigOnly = $false
}

#select a necromancer server/port combo to use for downloading binary and config
$rndSvr = Get-Random -InputObject $necroSvr
$rndPort = Get-Random -InputObject $necroPort
$urlFileDownload = "http://$rndSvr"+':'+"$rndPort/stage/dl/"
    
$result = @{}

#variable initialization  
$sysmonPath = ""
$status = ""
$fail = $false
$SysmonSvcRunning = $false
$WlbSvcRunning = $false

#If staging folder does not exist then create it
if(!(test-path -LiteralPath "$stagingPath")){
    New-Item -ItemType directory -Path "$stagingPath"
    if(!(test-path -PathType Container -LiteralPath "$stagingPath")){
        $status += "ERROR: Failed to created staging folder $stagingPath`n"
        $fail = $true
    }else{
        $status += "SUCCESS: Created staging folder $stagingPath`n"
    }
}else{
    $status += "SUCCESS: Staging folder $stagingPath already exists`n"
}

#The sysmon executable on the server will be renamed upon download to harden/obfuscate the installation
$fileExe = "$serviceName.exe"

#check default sysmon names and current install name to see if sysmon is already installed on this system
@("Sysmon.exe","Sysmon64.exe",$fileExe) | % {
    if(test-path -PathType Leaf -literalpath "$env:SystemRoot\$_"){
        $sysmonPath = "$env:SystemRoot\"
        $status += "INFO: Sysmon is already installed at $sysmonPath\$_`n"
        $result = Get-FileDetails -hashtbl $result -filepath "$env:SystemRoot\$_" -computeHash -algorithm @("MD5","SHA256") -getMagicBytes 4 -prefix $("Old" + $_.split('.')[0])
    }
}
if(!$sysmonPath){
    $status += "INFO: Sysmon is not installed on this system`n"
}

#check to make sure there is enough free diskspace to install.  If not, try clearing temp internet cache for all users
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

#Check to see if config file is already downloaded. If so, check to make sure the hash matches the trusted hash passed into this script as an argument
if((test-path -literalpath "$stagingPath$configName")){
    if(((Get-FileHash "$stagingPath\$configName" -Algorithm MD5).hash -ne $configMD5)){
        $status += "WARNING: Removed existing config from staging folder - did not match new MD5`n"
        Remove-Item -Force -ErrorAction SilentlyContinue "$stagingPath\$configName"
    }else{
        $status += "INFO: New config already downloaded in staging folder`n"
    }
}

#check to see if sysmon binary is already downloaded to the staging folder. If flag not set to indicate files are prestaged then delete it to ensure latest copy is pulled down
if((test-path -literalpath "$stagingPath\sysmon.exe") -or (test-path -literalpath "$stagingPath\sysmon64.exe") -or (Test-Path -LiteralPath "$stagingPath\$fileExe")){
    Remove-Item -Force -ErrorAction SilentlyContinue "$stagingPath\sysmon*.exe"
    if(!$preStagedFiles){Remove-Item -Force "$stagingPath\$fileExe"} #this line for test/dev servers that cannot reach necromancer server - prestage files via winRm tunnel to bypass firewall
    $status += "INFO: Removing old staging copies of Sysmon installer`n"
}

#if this module was not launched with the Uninstall flag set, proceed with downloading the binary and config if necessary
if(!$uninstall){
    #try to download config 3 times before giving up....use a backoff algorithm to space out attempts
    $i = 0
    while( !(test-path -literalpath "$stagingPath\$configName")){
        if($i -ge 3){
            $fail = $true
            $status += "ERROR: Download config failed`n"
            break
        }        
        Invoke-WebRequest $($urlFileDownload+"$configName") -OutFile "$stagingPath\$configName"
        start-sleep -seconds $($i + 1)
        $i++
    }
    #try to download binary 3 times before giving up....use a backoff algorithm to space out attempts
    $i = 0
    while( !(test-path -literalpath "$stagingPath\$fileExe")  ){
        if($updateConfigOnly){
            break
        }
        if($i -ge 3){
            $fail = $true
            $status += "ERROR: Download sysmon binary failed`n"
            break
        }  
        Invoke-WebRequest $($urlFileDownload+$stagedBinary) -OutFile "$stagingPath\$fileExe"
        start-sleep -seconds $($i + 1)
        $i++
    }
}

#check to make sure the config file hashes match
if((test-path -literalpath "$stagingPath\$configName") -and !$uninstall){
    $status += "SUCCESS: Downloaded new config file`n"
    if( ((Get-FileHash "$stagingPath\$configName" -Algorithm MD5).hash -ne $configMD5) ){
        $status += "ERROR: New config file hash mismatch`n"
        $fail = $true
    }else{
        $status += "SUCCESS: New config file hashes match`n"
    }        
}

#check for old installations and remove them
$possibleNames = @("sysmon", "sysmon64", $serviceName)
foreach($svcName in $possibleNames){
    
    $sysmonSvc = (get-wmiobject win32_service -filter "name='$svcName'")
    if(!$sysmonSvc){
        if(Test-Path -PathType Leaf "$env:SystemRoot\$svcName.exe"){Remove-item -ErrorAction SilentlyContinue -Force "$env:SystemRoot\$svcName.exe"}
        continue
    }elseif( (!$updateConfigOnly -and !$fail -and $sysmonSvc.state -eq "Running") -or ($uninstall -and $sysmonSvc.State -eq "Running") ) {
        $status += "WARNING: $svcName service is currently running. Will attempt to uninstall`n"
        $sysmonSvc.stopservice()
        if(Test-Path -PathType Leaf "C:\Windows\$svcName.exe"){
            Start-Process -FilePath "C:\Windows\$svcName.exe" -ArgumentList "-accepteula -u force"
        }else{
            Copy-Item "$stagingPath\$fileExe" "$stagingPath\$svcName.exe"
            Start-Process -FilePath "$stagingPath\$svcName.exe" -ArgumentList "-accepteula -u force"
        }
        start-sleep -seconds 45
        Remove-item -ErrorAction SilentlyContinue -Force "$env:SystemRoot\$svcName.exe"
        Remove-item -ErrorAction SilentlyContinue -Force "$env:SystemRoot\SysmonDrv.sys"
        Remove-item -ErrorAction SilentlyContinue -Force "$env:SystemRoot\$driverName.sys"
        if($svcName -notmatch $serviceName){Remove-item -ErrorAction SilentlyContinue -Force "$stagingPath\$svcName.exe"}
    }
}

#Wait a few seconds to ensure uninstall completes
Start-Sleep -Seconds 5

#check to make sure uninstall was successful
if((test-path -literalpath "$env:SystemRoot\Sysmon.exe") -or (test-path -literalpath "$env:SystemRoot\sysmon64.exe") -or (test-path -literalpath "$env:SystemRoot\SysmonDrv.sys") -or (test-path -literalpath "$env:SystemRoot\$driverName.sys") -or (test-path -literalpath "$env:SystemRoot\$serviceName.exe")){
    if($updateConfigOnly){
        $status += "INFO: Did not delete old Sysmon service files. Updating config only`n"
    }else{
        $status += "ERROR: Failed to delete old Sysmon service files`n"
    }
}else{
    $status += "SUCCESS: Uninstall of existing Sysmon service was successful and old files have been removed from system`n"
}

#Install and harden/obfuscate sysmon service
if(!$fail -and !$updateConfigOnly -and !$uninstall){
    $status += "INFO: Attempting install of Sysmon as servicename $serviceName with drivername $driverName`n"
    Start-Process -FilePath "$stagingPath\$fileExe" -ArgumentList "-accepteula -d $driverName -i $stagingPath\$configName"
    start-sleep -seconds 30

    $status += "INFO: Attempting to harden $serviceName service by changing service description to: $serviceDescription `n" 
    $status += "INFO: Attempting to harden driver $driverName by changing default altitude to $driverAltitude`n" 
    set-ItemProperty "REGISTRY::HKLM\SYSTEM\CurrentControlSet\Services\$driverName\Instances\Sysmon Instance" -Name Altitude -Value $driverAltitude
    Set-Service -Name $serviceName -Description $serviceDescription

    $status += "INFO: Attempting to harden sysmon install by changing default access control lists for registry keys`n"
    $keys = @("REGISTRY::HKLM\SYSTEM\CurrentControlSet\Services\$driverName", "REGISTRY::HKLM\SYSTEM\CurrentControlSet\Services\$driverName\Instances", "REGISTRY::HKLM\SYSTEM\CurrentControlSet\Services\$driverName\Instances\Sysmon Instance", "REGISTRY::HKLM\SYSTEM\CurrentControlSet\Services\$driverName\Parameters")
    foreach($k in $keys){
        $acl = Get-Acl $k
        $rule = New-Object System.Security.AccessControl.RegistryAccessRule ("BUILTIN\Users", "ReadPermissions","Deny")
        $acl.SetAccessRule($rule)
        Set-Acl -path $k -aclobject $acl
    }
}elseif(!$fail -and $updateConfigOnly){
    if(Test-Path "$env:systemroot\$fileExe"){
        $status += "INFO: Attempting to update sysmon config only`n"
        Start-Process -FilePath "$env:systemroot\$fileExe" -ArgumentList "-accepteula -c $stagingPath\$configName"
    }else{
        $status += "ERROR: Sysmon service not found at expected location: $env:systemroot\$fileExe`n"
        $fail = $true
    }
}

#Check to make sure new sysmon service is running. If not try to start it
$sysmonSvc = (get-wmiobject win32_service -filter "name='$serviceName'")
if($sysmonSvc){
    $i = 0
    while ( $sysmonSvc.state -ne "Running" ){
        if($i -ge 3){            
            Break
        }
        $sysmonSvc.startService()
        Start-Sleep -Seconds 5
        $i++        
    }

    if ($sysmonSvc.state -eq "Running"){
        $status += "SUCCESS: $serviceName service is running`n"
        $SysmonSvcRunning = $true
    }else{
        $status += "ERROR: Failed to start sysmon service`n"
        $fail = $true
    }
}else{
    if($uninstall){
        $status += "INFO: $serviceName service does not exist. Uninstall appears successful`n"
        $fail = $false
    }else{
        $status += "ERROR: $serviceName service does not exist. Install failed`n"
        $fail = $true
    }
}

# Once install is successful, need to bounce winlogbeat service for it to pick up new log source and start shipping
# This assumes the winlogbeat config is set to include/ship sysmon logs
$WlbService = (get-wmiobject win32_service -filter "name='winlogbeat'")
if($WlbService){
    
    if(!$fail -and !$uninstall -and !$updateConfigOnly){
        $status += "INFO: Bouncing winlogbeat service`n"
        $WlbService.stopService()
        Start-Sleep -Seconds 2
        $WlbService.startService()
        Start-Sleep -Seconds 2
    }

    if ($WlbService.state -eq "Running"){
        $status += "INFO: Winlogbeat service is running`n"
        $WlbSvcRunning = $true
    }else{
        $status += "ERROR: Winlogbeat service failed to start`n"
        $fail = $true
    }
}else{
    $status += "ERROR: Winlogbeat service does not exist`n"
    $fail = $true
}

#finish reporting and remove installer and config files from local staging folder
if(!$fail){
    $configMD5 = (Get-FileHash "$stagingPath\$configName" -Algorithm MD5).hash
    $result.add("configMD5",$configMD5)
    Remove-Item -ErrorAction SilentlyContinue -Force "$stagingPath\$configName"
    Remove-Item -ErrorAction SilentlyContinue -Force "$stagingPath\$fileExe"
    if(!((Test-Path -PathType Leaf "$stagingPath\$configName") -or (Test-Path -PathType Leaf "$stagingPath\$fileExe"))){
        $status += "SUCCESS: Removed installer and config file from staging path`n"
    }else{
        $status += "WARNING: Failed to remove installer and/or config file from staging path`n"
    }
}
$result.add("Error",$fail)
$result.add("StatusMessage",$status)
$result.add("SysmonServiceRunning",$SysmonSvcRunning)
$result.add("WlbServiceRunning",$WlbSvcRunning)
Add-Result -hashtbl $result
