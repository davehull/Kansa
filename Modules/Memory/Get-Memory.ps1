<#
.SYNOPSIS
Get-Memoryze.ps1

This module will allow you to dump the live memory on systems you may have 
identified as needing more analysis. You can use the dump in other tools, 
such as Redline or Volatility.

Requires the x64 folder in the Memoryze directory (where you installed 
it on the source machine) be zipped in the in Modules\Bin\ as memoryze.zip. The 
files in Memoryze directory should be Memoryze.exe and all dependancies required
to run memoryze on the target machine(s).

When used with -PushBin argument, copies memoryze.zip from the Modules\bin\ 
path to each remote host and dumps live memory in the $env:temp\Memoryze\x64\
workstation\time\Audits folder. You may want to tweak this to target specific 
needs if you are after specific areas i.e. processes, drivers, hooks, etc. 
As it is currently, it creates an entire memory dump of the target system and
stores it in <the current workingdirectory>/Audits/<machine>/<date>. You will need
to manually (or automatically) copy the .img file back to an analysis machine. It
is highly recommended to check if there is adequate disk space on the target for
a full dump. 

!! The dump is quickish; however, transferring it accross the network is slow !!

.NOTES
Next line is required by Kansa for proper handling of third-party binary.
The BINDEP directive below tells Kansa where to find the third-party code.
BINDEP .\Modules\bin\memoryze.zip
#>

#expand the .zip of memoryze.zip
Function Expand-Zip ($zipfile, $destination) {
	[int32]$copyOption = 16 # Yes to all
    $shell = New-Object -ComObject shell.application
    $zip = $shell.Namespace($zipfile)
    foreach($item in $zip.items()) {
        $shell.Namespace($destination).copyhere($item, $copyOption)
    }
} 

#Check OS Versiona and bail if Version 10 or later
if ([environment]::OSVersion.Version.Major -ge 10) {
	"Not supported on Windows OS Major Version 10 or greater"
	exit
}

#set the memoryze path
$memoryzepath = ($env:SystemRoot + "\memoryze.zip")

#test that the files exist and then run memorydd.bat to dump live memory
if (Test-Path ($memoryzepath)) {
    $suppress = New-Item -Name Memoryze -ItemType Directory -Path $env:Temp -Force
    $memoryzedest = ($env:Temp + "\Memoryze")
    $memoryze = ($memoryzedest + "\x64\memorydd.bat")
    $cmdlocation = ($env:SystemRoot + "\System32\cmd.exe")
    Expand-Zip $memoryzepath $memoryzedest
    if (Test-Path($memoryze)) {
        & $cmdlocation  /c $memoryze |
                ForEach-Object { $_ }               
    } else {
        "memoryze.zip found, but not unzipped."
    }
} else {
    "memoryze.zip not found on $env:COMPUTERNAME"
}

#optional: add feature to copy image file to a centeral repo for further analysis
#might want to hash the image dump if using for forensics

