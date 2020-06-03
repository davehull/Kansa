# This module is designed for unstructured hunting to collect the running processes across all systems
# and aggregate results to look for outliers. Each running process will also have its loaded libraries
# or modules enumerated and will be enriched with details about its parent-process, commandline etc...
# Since this can generate a large amount of data, you can limit the scope of the hunt/collection by
# specifying a regex pattern for specific process names to focus on, such as only looking at the 
# explorer.exe process and it's loaded dlls etc... Leaving the $processName variable blank will match
# all processes. For best results this module should be run with administrator privileges including
# seDebug so that it can see the process owner and commandline info for all running processes

if(!(Get-Variable -Name enableHashing -ErrorAction SilentlyContinue)){$enableHashing = $true}
if(!(Get-Variable -Name HashType -ErrorAction SilentlyContinue)){$HashType = "MD5"}
if(!(Get-Variable -Name processName -ErrorAction SilentlyContinue)){$processName = ""}

if ($enableHashing) { $hashtable = @{} }

$WMIProcess = Get-WmiObject -query 'Select * from win32_process' | Where Name -Match $processName | Select Name,ProcessId,ParentProcessId,CommandLine,CreationDate,Description,Path
$convert = Get-WmiObject -class Win32_Process

$procs = Get-Process -IncludeUserName
ForEach ($proc in $procs) { 
    $thisProcess = $proc
    $thisProcessName = $proc.Name
    $thisProcessPath = $proc.Path
    $thisProcessUser = $proc.UserName
    $thisProcessID = $proc.Id
    $thisWMIProcess = $WMIProcess | where ProcessId -eq $thisProcessID
    $thisPPID = $thisWMIProcess.ParentProcessId
    if ($thisPPID -ne $null) {
        $parentProcess = $WMIProcess | where ProcessId -eq $thisPPID | Select Name,Path
        if ($parentProcess -ne $null){
            $parentProcessName = $parentProcess.Name
            $parentProcessPath = $parentProcess.Path
        }
    }

    $thisProcessCmdline = $thisWMIProcess.CommandLine
    $thisProcessDesc = $thisWMIProcess.Description
    $thisProcessCreation = ([String]$convert[0].ConvertToDateTime($thisWMIProcess.CreationDate)).Trim()

    $thisModuleHash = ''
    $thisProcessHash = ''
    if (($enableHashing) -and ($thisProcessPath -ne $null) -and (Test-Path -LiteralPath $thisProcessPath -PathType Leaf)) {
        if ($hashtable.ContainsKey($thisProcessPath)){
            $thisProcessHash = $hashtable.$thisProcessPath
        } else {                
            $thisProcessHash = Get-FileHash -LiteralPath $thisProcessPath -Algorithm $HashType
            $hashtable.Add($thisProcessPath, $thisProcessHash)
        }
    }

    $mods = $thisProcess.Modules 
    ForEach ($mod in $mods) {
        $thisModule = $mod.ModuleName 
        $thisModulePath = $mod.FileName
        $thisModuleCo = $mod.Company
        $thisModuleDesc = $mod.Description

        if (($enableHashing) -and ($thisModulePath -ne $null) -and (Test-Path -LiteralPath $thisModulePath -PathType Leaf)) {
            if ($hashtable.ContainsKey($thisModulePath)){
                $thisModuleHash = $hashtable.$thisModulePath
            } else {
                $thisModuleHash = Get-FileHash -LiteralPath $thisModulePath -Algorithm $HashType
                $hashtable.Add($thisModulePath, $thisModuleHash)
            }
        }

        $result = @{}
        $result.add("ProcessID",$thisProcessID)
        $result.add("ProcessName",$thisProcessName)
        $result.add("ProcessPath",$thisProcessPath)
        if (($enableHashing) -and ($thisProcessPath -ne $null)) { $result.add("ProcessMD5Hash",$thisProcessHash.Hash) }
        $result.add("ProcessUser",$thisProcessUser)
        $result.add("ProcessCommand",$thisProcessCmdline)
        $result.add("ProcessDescription",$thisProcessDesc)
        $result.add("ProcessCreationDate",$thisProcessCreation)
        if ($thisPPID -ne $null) { 
            $result.add("ParentProcessID",$thisPPID)
            $result.add("ParentProcessName",$parentProcessName)
            $result.add("ParentProcessPath",$parentProcessPath)
        }
        $result.add("ModuleName",$thisModule)
        $result.add("ModulePath",$thisModulePath)
        if (($enableHashing) -and ($thisModulePath -ne $null)) { $result.add("ModuleMD5Hash",$thisModuleHash.Hash) }
        $result.add("ModuleCompany",$thisModuleCo)
        $result.add("ModuleDescription",$thisModuleDesc)
        Add-Result -hashtbl $result
    } 
}
