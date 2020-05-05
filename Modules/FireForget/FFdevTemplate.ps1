# This module is a Development Template to be used when testing/developing new Fire&Forget Kansa modules
# It contains the same helper-functions found in the full Fire&Forget wrapper, but the functions here 
# are stub/placeholders intended to aid in troubleshooting and testing. Once you are satisfied with the
# results you are getting it is recommended that you remove all the template code and leave only the
# module-specific code. You can leave your code in the template, since the kansa framework will strip
# the template functions and replace them with the full-featured wrapper version at runtime. But if you
# make any changes to the wrapper or this template those changes will not be reflected in other modules
# that you left wrapped in the template, leading to version disparity and the destruction of middle-earth

#<DummyFunctionStubs> #DO NOT REMOVE THIS LINE
###   THE FOLLOWING FUNCTIONS AND VARIABLES ARE DUMMY/STUB FUNCTIONS    ###
###   FOR DEVELOPMENT/TESTING PURPOSES ONLY. THESE FUNCTIONS MUST BE    ###
###   REMOVED OR LEFT UNTOUCHED SO THEY CAN BE DYNAMICALLY REMOVED      ###
###   AT LAUNCH/EXECUTION TO AVOID CONFLICTING FUNCTION DEFINITIONS     ###
$TOTAL_RESULTS = 0
function Add-Result{ param([object]$hashtbl); $TOTAL_RESULTS++; $hashtbl }
function Get-FileDetails{ param([hashtable]$hashtbl=@{},[string]$filepath = "",[switch]$computeHash,[string[]]$algorithm="MD5",[int]$maxHashSize=-1,[switch]$getContent,[int]$getMagicBytes=0,[string]$prefix = "");$file = gi -Force -LiteralPath $filepath -ErrorAction SilentlyContinue; $file.psobject.Properties | %{$hashtbl.add($_.Name, $_.Value.ToString())}; return $hashtbl}
function Get-MagicBytes{ Param([string[]]$Path,[int]$ByteLimit = 2,[int]$ByteOffset = 0); return [pscustomobject] @{Hex = "DummyHEXData"; ASCII = "DummyHEXData"}}
function enhancedGCI{ Param([String]$startPath="$env:systemdrive\",[String]$regex=".*",[String[]]$extensions="*",[switch]$folder); $extensions | % { gci -Path "$startPath\$_" -Recurse -Force -Directory:$folder -file:!$folder | where Name -Match $regex | select -Property FullName -ExpandProperty FullName }}
function Get-File{ param( [string]$server="",[int]$port=80,[string[]]$filename="",[string]$targetPath="$PSScriptRoot",[switch]$overwrite ); $urlFileDownload = "http://$server"+':'+"$port/stage/dl/"; Invoke-WebRequest $($urlFileDownload+$f) -OutFile $("$targetPath\$f")}
function Send-File{ Param([String]$localFilePath,[String]$remoteFilename,[String]$url);Add-Type -AssemblyName 'System.Net.Http'; $clnt = New-Object System.Net.Http.HttpClient; $cntnt = New-Object System.Net.Http.MultipartFormDataContent; $fStrm = [System.IO.File]::OpenRead($localFilePath); $fCntnt = New-Object System.Net.Http.StreamContent($fStrm); $cntnt.Add($fCntnt, 'file', $remoteFilename); $result = $clnt.PostAsync($url, $cntnt).Result; $result.EnsureSuccessStatusCode(); return $result; }
function Get-StringHash([String]$stringData, [ValidateSet("MD5","SHA1","SHA256")][String]$Algorithm="SHA256"){$s = New-Object System.Text.StringBuilder;[System.Security.Cryptography.HashAlgorithm]::Create($Algorithm).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringData)) | %{[Void]$s.Append($_.toString("x2"))}; return $s.ToString();}
$startTime = Get-Date
$moduleName = $MyInvocation.MyCommand.Name
$tzdiff = ((Get-WmiObject -class Win32_OperatingSystem).CurrentTimeZone / 60)
$ModuleAccount = $env:USERNAME
$hostname = ($env:COMPUTERNAME).ToLower()
$procBitness = [System.IntPtr]::Size * 8
#</DummyFunctionStubs> #DO NOT REMOVE THIS LINE

##############PUT YOUR MODULE CODE HERE#################
#Use the following variable-checks to see if your custom Fire&Forget module variables were passed in
#If not, set a default/safe value for them to use
#if(!(Get-Variable -Name customModuleVar -ErrorAction SilentlyContinue)){$customModuleVar = "default"}
#if(!(Get-Variable -Name customModuleVar2 -ErrorAction SilentlyContinue)){$customModuleVar2 = 0}
#
#All outputs/results whould be in the form of a hashtable with unique key/value pairs
#This facilitates sending valid JSON into ELK or other logging infrastructure
#The Fire&Forget Wrapper helper functions will handle formatting and sending the data
#As long as you call the Add-Result function with each "record" it will get sent
#Be sure to maintain consistent type-mappings for your Key/value pairs to help ELK with index mappings
#example
#$result = @{}
#$result.add("Unique Fieldname per hashtable-record","Value")
#$result.add("Different Fieldname per hashtable-record",[int]31337)
#Add-Result -hashtbl $result
#etc...
#
#
##############END OF MODULE SPECIFIC CODE###############

#<DummyFunctionStubs> #DO NOT REMOVE THIS LINE
#The following lines will give you some BASIC run-statistics for your module during testing
#these lines will be stripped out and replaced with more comprehensive metrics when you launch using the Fire&Forget Framwork
$endTime = Get-Date
$totalDuration = $endTime - $startTime
$runTime = $endTime - $startTime.AddSeconds($rnd)
$thisProc = get-process | where Id -eq $pid | Select PM,CPU,WS
$thisCounterPath = ((Get-Counter "\Process(powershell*)\ID Process").CounterSamples | ? {$_.RawValue -eq $pid}).Path
$pws = ((get-counter ($thisCounterPath -replace "\\id process$","\Working Set - Private")).CounterSamples | select CookedValue).CookedValue / 1MB

$result = @{}
$result.Add("ModuleName",$($PSCommandPath.Split('\')[-1] -replace "\.ps1",""))
$result.add("ModuleAccount",$ModuleAccount)
$result.add("ModuleStatus","Complete")
$result.add("ModulePID",$PID)
$result.add("ModuleProcessBitness", $procBitness)
$result.add("ModuleStart",$startTime.ToString())
$result.add("ModuleComplete",$endTime.ToString())
$result.add("MinutesRuntime",$runTime.TotalMinutes)
$result.add("ItemsAnalyzed",$TOTAL_RESULTS)
Add-Result -hashtbl $result
#</DummyFunctionStubs> #DO NOT REMOVE THIS LINE
