# This module can be used to terminate another Kansa Fire&Forget module running on a target 
# with a series of tactical taskkill commands that focus on process names, process owners and 
# windowtitles to avoid killing legitimate user processes or THIS kansa module in cyber fratricide.

if(!(Get-Variable -Name DLaunchModule -ErrorAction SilentlyContinue)){$DLaunchModule = "Get-KansaDLauncher"}
if(!(Get-Variable -Name ModuleAccount -ErrorAction SilentlyContinue)){$ModuleAccount = "$($Credential.UserName)"}

if($DLaunchModule){$global:moduleName = $DLaunchModule}
$mykillswxpid = 0
$mypingpid = 0
# If the killswitch feature is enabled for this Fire&Forget module, get the PIDs so we don't inadvertently kill our 
# own killswitch
if($killswx){
    $mykillswxpid = $killswx.ProcessId
    $mypingpid = $WMIProcess | where ParentProcessId -EQ $killswxpid | select ProcessId
}

# DO NOT kill kansa processes on Hunt/Kansa servers since they are used to rapidly deploy this module to all endpoints
# if they were included in the targetlist gracerfully abort
if($env:COMPUTERNAME -match "(hunt|kansa)"){
    $result = @{}
    $abortmsg = "Cannot abort on Kansa Server"
    $result.add("ModuleAccount","$ModuleAccount")
    $result.add("ModuleStatus","Abort Failed")
    Add-Result -hashtbl $result
}else{
    # Try killing any other running kansa modules running under the specified user context
    # as well as any associated killswitches and collect result messages to determine applicability
    # and success/failure
    $res = taskkill /F /FI "IMAGENAME eq powershell.exe" /FI "USERNAME eq $ModuleAccount" /FI "PID ne $PID"
    $res2 = taskkill /F /FI "IMAGENAME eq cmd.exe" /FI "USERNAME eq $ModuleAccount" /FI "PID ne $mykillswxpid" /FI "WINDOWTITLE eq $HuntID"
    $res3 = taskkill /FI "IMAGENAME eq PING.exe" /FI "USERNAME eq $ModuleAccount" /FI "PID ne $mypingpid"
    $result = @{}
    $abortmsg = "Kansa not present"
    if($res -match "SUCCESS"){$abortmsg = "Kansa Terminated"}
    if(($res2 -match "SUCCESS") -or ($res3 -match "SUCCESS")){
        if($abortmsg -notmatch "not present"){
            $abortmsg += " and Killswitch Terminated"
        }else{
            $abortmsg = "Killswitch Terminated"
        }
    }
    $result.add("ModuleAccount","$ModuleAccount")
    $result.add("Kill-powershell","$($res.Trim())")
    $result.add("Kill-cmd","$($res2.Trim())")
    $result.add("Kill-ping","$($res3.Trim())")
    if($abortmsg -match "Terminated"){
        $result.add("ModuleStatus","Aborted")
    }else{
        $result.add("ModuleStatus","No Abort Necessary")
    }
    $result.add("AbortReason","Kansa DeLaunch Triggered")
    $result.add("AbortResult",$abortmsg)
    Add-Result -hashtbl $result
}
